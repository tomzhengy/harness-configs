# clipaste - paste images into claude code over ssh

when claude code runs on a remote machine over ssh, clipboard image paste does not
work: your clipboard lives on the local mac, but claude code reads the remote
machine's clipboard, and ssh does not forward the clipboard (the pty only carries
text). [clipaste](https://github.com/hqhq1025/clipaste) bridges the local clipboard
to the remote so you can paste screenshots into a remote claude code session.

## roles

- **local machine** (where your clipboard / screenshots live, e.g. a macbook): runs
  the clipaste daemon. all setup commands below run here.
- **remote machine** (where claude code runs, e.g. a mac mini): receives the image
  through an ssh reverse tunnel. nothing to install by hand - `ssh-setup` does it.

## setup

run on the **local** machine:

```bash
./setup-local.sh user@remote-host
# custom ssh port:
./setup-local.sh user@remote-host -p 2222
```

the script installs clipaste via homebrew, starts the daemon, and runs
`clipaste ssh-setup`, which adds a `RemoteForward` tunnel to your `~/.ssh/config`
and installs the remote helper.

equivalent manual steps:

```bash
brew install hqhq1025/clipaste/clipaste
brew services start clipaste
clipaste ssh-setup user@remote-host        # add -p PORT for a non-default ssh port
```

after setup, open a **new** ssh session for the tunnel to take effect.

## usage on a macos remote

the seamless `Ctrl+V` interception only works on a linux remote (it shims xclip). on
a **macos remote** you use the helper command instead. in the remote claude code
session:

```bash
clipaste-paste
```

it prints an image path like `/tmp/clipaste-<ts>.png`. reference that path in claude
code (it accepts image file paths). on the local mac, `cmd+ctrl+shift+4` copies a
screenshot region to the clipboard.

> note: never use `Cmd+V` in the remote session - it pastes the local mac path as
> plain text, which the remote agent cannot read.

## verify

```bash
brew services info clipaste    # on the local machine
```

## requirements

- local: macos with homebrew
- remote: `curl` (nothing else; the helper is installed by `ssh-setup`)

## security note

the daemon binds to localhost only and image data travels inside the existing ssh
tunnel (no new open ports on the remote). while a session is connected, any process
on the remote that can reach the forwarded port can read the current local clipboard
image. fine for a personal machine you control; be more cautious on a shared host.

## fallback (no daemon)

if you only paste occasionally, skip clipaste entirely: copy the image to the remote
and reference its path.

```bash
scp screenshot.png user@remote-host:/tmp/
# then in claude code:  @/tmp/screenshot.png
```
