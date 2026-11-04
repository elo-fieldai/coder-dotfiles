# coder-dotfiles

Dotfiles for my Coder workspaces on the `ros-machine` template. The only thing in here
is `install.sh`, which starts Tern's remote service so the Tern app on
my Mac can reconnect after a workspace restart.

## Why

Restarting or rebuilding a workspace restarts its pod. That stops `tern remote serve`,
and the template doesn't start it again. The `ros-machine` template runs
`coder dotfiles "$DOTFILES_URI" -y` on every start, which clones this repo to
`~/.config/coderv2/dotfiles` and runs `install.sh`.

## What `install.sh` does

- Fails with a message if `~/.local/bin/tern` is missing.
- Does nothing if `tern remote serve` is already running.
- Otherwise starts `tern remote serve --user` in the background and logs to
  `~/.local/state/tern-serve.log`.

The output of each run is in `~/.dotfiles.log` on the workspace.

## Enabling it on a workspace

Set the workspace's `dotfiles_uri` parameter to `https://github.com/elo-fieldai/coder-dotfiles`
and start a new build. With Coder v2.36.6, `coder restart --parameter` didn't save the
value, and `coder update --parameter` skips the build when the workspace is on the latest
template version. Creating the start build through the API applies it:

```sh
T=$(coder login token)
U=$(cat "$HOME/Library/Application Support/coderv2/url")  # Coder deployment URL (macOS CLI config)
WID=$(curl -s -H "Coder-Session-Token: $T" "$U/api/v2/users/me/workspace/<workspace>" | jq -r .id)
curl -s -X POST -H "Coder-Session-Token: $T" -H 'Content-Type: application/json' \
  "$U/api/v2/workspaces/$WID/builds" \
  -d '{"transition":"start","rich_parameter_values":[{"name":"dotfiles_uri","value":"https://github.com/elo-fieldai/coder-dotfiles"}]}'
```

## Connecting Tern

Connect Tern through the relay using the workspace's endpoint ID, not a
`coder port-forward --udp` tunnel. After a pod restart the tunnel stops passing traffic
even though its process keeps running. The relay doesn't have that problem.

```sh
# On the workspace: print the endpoint ID and host-key fingerprint.
tern remote host-key --user

# On the Mac: pin the fingerprint, then check the connection.
tern remote trust <endpoint-id> <fingerprint>
tern remote doctor eugene@<endpoint-id>
```

Then add `eugene@<endpoint-id>`, a tab, and a display name as one line in
`~/Library/Application Support/Tern/hosts`.

The host key lives in `~/.config/tern` on the workspace's persistent home volume, so the
endpoint ID and fingerprint stay the same across restarts.
