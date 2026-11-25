import hashlib
import json
import re
import shutil
import urllib.request
from pathlib import Path

repository = "https://registry-1.docker.io/v2/library/debian/"
auth_url = "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/debian:pull"
with urllib.request.urlopen(auth_url, timeout=45) as response:
    token = json.load(response)["token"]


def get(path):
    request = urllib.request.Request(repository + path, headers={
        "Authorization": "Bearer " + token,
        "Accept": ", ".join((
            "application/vnd.oci.image.index.v1+json",
            "application/vnd.oci.image.manifest.v1+json",
            "application/vnd.docker.distribution.manifest.list.v2+json",
            "application/vnd.docker.distribution.manifest.v2+json",
        )),
    })
    return urllib.request.urlopen(request, timeout=45)


def verified_manifest(digest):
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise SystemExit("Digest de manifesto Debian inválido.")
    with get("manifests/" + digest) as response:
        data = response.read()
    if "sha256:" + hashlib.sha256(data).hexdigest() != digest:
        raise SystemExit("A soma SHA-256 do manifesto Debian não confere.")
    return json.loads(data)


with get("manifests/trixie-slim") as response:
    index = json.load(response)
digest = next(
    entry["digest"] for entry in index["manifests"]
    if entry["platform"].get("architecture") == "amd64"
    and entry["platform"].get("os") == "linux"
)
layer, = verified_manifest(digest)["layers"]

archive = Path(".build/base.tar.gz.part")
with get("blobs/" + layer["digest"]) as response, archive.open("wb") as output:
    shutil.copyfileobj(response, output)
with archive.open("rb") as source:
    if "sha256:" + hashlib.file_digest(source, "sha256").hexdigest() != layer["digest"]:
        raise SystemExit("A soma SHA-256 da base Debian não confere.")
archive.replace(".build/base.tar.gz")
