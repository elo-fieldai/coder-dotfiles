# coder-dotfiles

Dotfiles for my Coder workspaces on the `ros-machine` template. `install.sh` starts Tern's
remote service so the Tern app on my Mac can reconnect after a workspace restart, then
restores the agent environment's system packages with `make install`.

## Why

Restarting or rebuilding a workspace restarts its pod. That stops `tern remote serve`,
and the template doesn't start it again. The `ros-machine` template runs
`coder dotfiles "$DOTFILES_URI" -y` on every start, which clones this repo to
`~/.config/coderv2/dotfiles` and runs `install.sh`.

## What `install.sh` does

- Fails with a message if `~/.local/bin/tern` is missing.
- Starts `tern remote serve --user` in the background unless it is already running, and logs to
  `~/.local/state/tern-serve.log`.
- Runs `repair-ffmpeg.sh`, then `make install` in `~/repos/agents`. A rebuild drops every system
  package outside the home volume, so this runs on every boot.

### Why `repair-ffmpeg.sh`

The workspace image ships Ubuntu Pro (ESM) security builds of FFmpeg's libraries but removes the
Ubuntu Pro access that has the matching packages, so `apt-get install ffmpeg` (and with it
`make install`) fails with `libavdevice60 : Depends: libavformat60 (= 7:6.1.1-3ubuntu5)`.
The script moves those libraries to the version Ubuntu's public repositories offer, then
installs `ffmpeg`. That drops their ESM security fixes. It does nothing once `ffmpeg` is
installable, so it goes inert when the image is fixed; the image belongs to
`@field-ai/devprod` (`docker/robotics/` in the monorepo).

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

A running Tern app keeps a connected host on the address it was opened with. After you
edit `hosts`, run `tern restart` (windows reopen; programs keep running), then stop any old
`coder port-forward` tunnel to that workspace. Tern stays on a direct address for as long as
one answers, and switches to the relay within about 20 seconds once none does.

The host key lives in `~/.config/tern` on the workspace's persistent home volume, so the
endpoint ID and fingerprint stay the same across restarts.

If `tern remote doctor` reports that the host is not linked to the relay, check whether
the workspace runs an older Tern than the Mac (`tern --version` on each side). Older
builds can use a different relay. Update the workspace over any route that still works,
for example a temporary `coder port-forward <workspace> --udp <port>:8376` tunnel:

```sh
tern remote update eugene@127.0.0.1:<port>
```
