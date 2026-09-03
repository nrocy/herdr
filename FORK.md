# Actionable notification fork

This downstream patch makes remote agent notifications clickable. It targets
Linux + Sway + WezTerm and uses Herdr's semantic notification target and
existing `pane.focus` endpoint to focus the originating pane, then the client
WezTerm/Sway window.

## Refresh and build

Requirements: Docker, `just`, `notify-send`, `swaymsg`, and `wezterm`.

```bash
just fork-refresh
```

This rebases a clean branch onto canonical `master`, runs the focused fork tests,
and writes a static x86_64 binary to `target/fork/herdr-linux-x86_64`. The build
container pins the upstream release toolchain and smoke-tests the binary on
Ubuntu 22.04 and Arch.

Deploy the same binary to client and server:

```bash
install -m 0755 target/fork/herdr-linux-x86_64 ~/.local/bin/herdr.new
mv ~/.local/bin/herdr.new ~/.local/bin/herdr
scp target/fork/herdr-linux-x86_64 c2:/tmp/herdr
HERDR_REMOTE_BINARY=/tmp/herdr herdr --remote c2 --handoff
```

The remote config must contain:

```toml
[ui.toast]
delivery = "system"
```

For later attaches, use `herdr --remote c2`. `herdr update` may overwrite a
daily fork binary.

The fork does not change the wire schema. Its client uses the endpoint methods
advertised by the server, so normal upstream client/server compatibility rules
apply.
