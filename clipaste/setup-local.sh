#!/usr/bin/env bash
# clipaste local setup - RUN THIS ON YOUR LOCAL MACHINE (the mac with the clipboard
# and screenshots), NOT on the remote where claude code runs.
#
# it installs the clipaste daemon, starts it, and runs `clipaste ssh-setup` which
# configures the ssh reverse tunnel and installs the remote helper. after this you
# can paste images into claude code running on a remote host over ssh.
#
# usage:
#   ./setup-local.sh user@remote-host
#   ./setup-local.sh user@remote-host -p 2222     # custom ssh port
#
# example for a mac mini remote reached as tom@toms-mini.local:
#   ./setup-local.sh tom@toms-mini.local

set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "usage: ./setup-local.sh user@remote-host [-p ssh_port]"
    echo "  run this on your LOCAL machine (the one with the clipboard / screenshots)."
    exit 1
fi

REMOTE="$1"
shift

# this must run on the local macos machine where your clipboard lives.
# the remote side is configured automatically by `clipaste ssh-setup`.
if [ "$(uname -s)" != "Darwin" ]; then
    echo "error: run this on your local macOS machine (where you take screenshots)."
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "error: homebrew is required. install it from https://brew.sh"
    exit 1
fi

# 1. install the clipaste daemon (idempotent)
if ! command -v clipaste >/dev/null 2>&1; then
    echo "installing clipaste..."
    brew install hqhq1025/clipaste/clipaste
else
    echo "clipaste already installed: $(command -v clipaste)"
fi

# 2. start the background daemon (watches the local clipboard)
echo "starting clipaste service..."
brew services start clipaste

# 3. configure the remote: adds a RemoteForward tunnel to ~/.ssh/config and installs
#    the remote helper. `"$@"` passes through any extra flags like `-p PORT`.
echo "configuring remote $REMOTE..."
clipaste ssh-setup "$REMOTE" "$@"

cat <<EOF

done. open a NEW ssh session to $REMOTE for the tunnel to take effect.

to paste an image into claude code on the remote:
  1. copy or screenshot on this mac (cmd+ctrl+shift+4 copies a region to the clipboard)
  2. in the remote claude code session run:  clipaste-paste
  3. it prints an image path like /tmp/clipaste-<ts>.png - reference that path in claude code

note: on a macOS remote the transparent Ctrl+V paste does not apply; use clipaste-paste.
verify the local daemon with: brew services info clipaste
EOF
