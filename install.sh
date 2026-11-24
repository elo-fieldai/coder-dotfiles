#!/bin/sh
## @file install.sh
## @brief Coder dotfiles hook: on each workspace boot, start Tern's remote service and restore the
##        agent environment's system packages.
##
## The ros-machine template runs `coder dotfiles <this repo> -y` on every start. A workspace rebuild
## replaces everything outside the home volume: it kills `tern remote serve` and drops the system
## packages `make install` in ~/repos/agents added. The Mac's Tern reaches the workspace over a UDP
## forward to port 8376, which never starts a shell, so without this hook Tern hangs reconnecting
## until the service is started by hand.
##
## Starts Tern first, so a later failure never leaves Tern down. Then repairs the image's FFmpeg
## libraries (repair-ffmpeg.sh) and runs `make install` in ~/repos/agents. Exits nonzero when Tern
## is not installed, ~/repos/agents is missing, or either step fails, so the failure shows in
## ~/.dotfiles.log instead of passing silently.
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TERN="$HOME/.local/bin/tern"
LOG="$HOME/.local/state/tern-serve.log"
AGENTS="$HOME/repos/agents"

[ -x "$TERN" ] || { echo "install.sh: tern not installed at $TERN" >&2; exit 1; }
if ! pgrep -u "$(id -u)" -f 'tern remote serve' >/dev/null; then
  mkdir -p "$(dirname "$LOG")"
  setsid nohup "$TERN" remote serve --user >>"$LOG" 2>&1 </dev/null &
  echo "install.sh: started tern remote serve (log: $LOG)"
fi

[ -f "$AGENTS/Makefile" ] || { echo "install.sh: no agents checkout at $AGENTS" >&2; exit 1; }
bash "$DIR/repair-ffmpeg.sh"
make -C "$AGENTS" install </dev/null
