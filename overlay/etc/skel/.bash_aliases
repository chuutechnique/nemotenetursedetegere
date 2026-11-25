PS1='\u@\h \$ '
if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    export PATH="$XDG_RUNTIME_DIR/sonic-apps/bin:$PATH"
fi

apt() {
    printf '%s\n' 'did you mean: sonic install <package> ?' >&2
    return 127
}

alias apt-get=apt
