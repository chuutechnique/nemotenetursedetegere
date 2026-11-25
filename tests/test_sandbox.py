"""Linux integration tests. Run as an ordinary user with the sandbox dependencies."""
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import socket
import tempfile
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "overlay/usr/local/bin/sonic-sandbox"
loader = importlib.machinery.SourceFileLoader("sonic_sandbox_test_target", str(SOURCE))
spec = importlib.util.spec_from_loader(loader.name, loader)
sandbox = importlib.util.module_from_spec(spec)
loader.exec_module(sandbox)


class IsolationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="nemo-isolation-")
        self.root = Path(self.directory.name)
        self.home = self.root / "desktop-home"
        self.home.mkdir(mode=0o700)
        self.runtime = self.root / "runtime"
        self.runtime.mkdir(mode=0o700)
        self.environment = patch.dict(os.environ, {
            "HOME": str(self.home), "XDG_RUNTIME_DIR": str(self.runtime),
            "DISPLAY": ":999", "DBUS_SESSION_BUS_ADDRESS": "unix:path=/secret-host-bus",
        })
        self.environment.start()

    def tearDown(self):
        self.environment.stop()
        self.directory.cleanup()

    def execute(self, code, app="curl"):
        with patch.object(sandbox, "command", lambda *_: ["/usr/bin/python3", "-c", code]):
            self.assertEqual(sandbox.run(app, []), 0)

    def test_files_processes_environment_and_shared_directory(self):
        (self.home / "private-secret").write_text("host private data")
        other = self.runtime / "sonic-sandboxes/discord/home"
        other.mkdir(parents=True)
        (other / "private-secret").write_text("another application's data")
        shared = self.home / "Shared"
        shared.mkdir()
        (shared / "exchange.txt").write_text("explicitly shared")
        host_pid_namespace = os.readlink("/proc/self/ns/pid")
        host_network_namespace = os.readlink("/proc/self/ns/net")
        code = f'''import os
from pathlib import Path
assert not Path({str(self.home / "private-secret")!r}).exists()
assert not Path({str(other / "private-secret")!r}).exists()
assert not Path('/home/nemo/private-secret').exists()
assert not Path('/opt/tor-browser').exists()
assert 'DBUS_SESSION_BUS_ADDRESS' not in os.environ
assert 'DISPLAY' not in os.environ
assert os.readlink('/proc/self/ns/pid') != {host_pid_namespace!r}
assert os.readlink('/proc/self/ns/net') != {host_network_namespace!r}
assert len([x for x in Path('/proc').iterdir() if x.name.isdigit()]) < 10
assert Path('/home/nemo/Shared/exchange.txt').read_text() == 'explicitly shared'
Path('/home/nemo/Shared/returned.txt').write_text('returned')
Path('/home/nemo/own.txt').write_text('own session')
'''
        self.execute(code)
        self.assertEqual((shared / "returned.txt").read_text(), "returned")
        self.execute("from pathlib import Path; assert Path('/home/nemo/own.txt').read_text()=='own session'")
        self.execute("from pathlib import Path; assert not Path('/home/nemo/own.txt').exists()", app="whois")

    def test_host_loopback_and_abstract_socket_are_inaccessible(self):
        with socket.socket() as listener, socket.socket(socket.AF_UNIX) as abstract:
            listener.bind(("127.0.0.1", 0))
            listener.listen(2)
            port = listener.getsockname()[1]
            name = "\0nemo-private-test-" + str(os.getpid())
            abstract.bind(name)
            abstract.listen(2)
            code = f'''import socket
for address in [('10.0.2.2', {port}), ('10.0.2.3', {port}), ('127.0.0.1', {port})]:
 try:
  connection=socket.create_connection(address, timeout=2)
 except OSError:
  pass
 else:
  connection.close(); raise AssertionError('host service accessible: '+str(address))
with socket.socket(socket.AF_UNIX) as connection:
 connection.settimeout(2)
 try:
  connection.connect({name!r})
 except OSError:
  pass
 else:
  raise AssertionError('host abstract socket accessible')
'''
            self.execute(code)

    def test_setup_failure_never_starts_application(self):
        code = "from pathlib import Path; Path('/home/nemo/Shared/should-not-run').write_text('bad')"
        with patch.object(sandbox, "network", side_effect=RuntimeError("test setup failure")), \
             patch.object(sandbox, "command", lambda *_: ["/usr/bin/python3", "-c", code]):
            with self.assertRaisesRegex(RuntimeError, "test setup failure"):
                sandbox.run("curl", [])
        self.assertFalse((self.home / "Shared/should-not-run").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
