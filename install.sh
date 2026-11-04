#!/bin/sh
## @file install.sh
## @brief Coder dotfiles hook: start Tern's remote service on each workspace boot.
##
## The ros-machine template runs `coder dotfiles <this repo> -y` on every start, and a
## workspace rebuild restarts the pod, killing `tern remote serve`. The Mac's Tern reaches
## the workspace over a UDP forward to port 8376, which never starts a shell, so without
## this hook Tern hangs reconnecting until the service is started by hand.
##
## Exits 0 when the service is already running or was started; exits 1 when Tern is not
## installed, so the failure shows in ~/.dotfiles.log instead of passing silently.
set -eu

TERN="$HOME/.local/bin/tern"
LOG="$HOME/.local/state/tern-serve.log"

[ -x "$TERN" ] || { echo "install.sh: tern not installed at $TERN" >&2; exit 1; }
pgrep -u "$(id -u)" -f 'tern remote serve' >/dev/null && exit 0

mkdir -p "$(dirname "$LOG")"
setsid nohup "$TERN" remote serve --user >>"$LOG" 2>&1 </dev/null &
echo "install.sh: started tern remote serve (log: $LOG)"
