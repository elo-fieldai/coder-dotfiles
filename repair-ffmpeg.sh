#!/usr/bin/env bash
## @file repair-ffmpeg.sh
## @brief Make the ffmpeg package installable when the workspace image ships Ubuntu Pro (ESM)
##        builds of FFmpeg's libraries without the ESM repository that has the matching packages.
##
## The image installs ESM security builds (for example 7:6.1.1-3ubuntu5+esm15) and then removes
## its Ubuntu Pro access, so apt can no longer install `ffmpeg`, which needs every FFmpeg library
## at one exact version. This script moves those orphaned libraries to the version the configured
## repositories offer. That drops their ESM security fixes; it is a stopgap until the image itself
## ships a consistent FFmpeg.
##
## Does nothing when `ffmpeg` is already installable. Fails, changing nothing, when sudo is not
## passwordless, when the repositories lack a version for any affected package, or when apt would
## remove any package.
set -euo pipefail

## Print an error and stop.
## @param $* Message.
## @return Does not return.
fail() { printf 'repair-ffmpeg.sh: %s\n' "$*" >&2; exit 1; }

## Report whether apt can install ffmpeg without changing installed packages' versions.
## @return Zero when the simulated install succeeds.
ffmpeg_installable() { apt-get -s --no-remove install ffmpeg >/dev/null 2>&1; }

## Report whether any configured repository offers a package at a version.
## @param $1 Package name.
## @param $2 Version.
## @return Zero when `apt-cache madison` lists that exact version.
offered() {
  apt-cache madison "$1" | awk -F'|' -v want="$2" '{ gsub(/ /, "", $2) } $2 == want { found = 1 } END { exit !found }'
}

sudo -n true 2>/dev/null || fail 'passwordless sudo is required'
sudo -n env DEBIAN_FRONTEND=noninteractive apt-get update -qq

if ffmpeg_installable; then
  echo 'repair-ffmpeg.sh: ffmpeg is installable; nothing to do'
  exit 0
fi

target=$(apt-cache policy ffmpeg | awk '$1 == "Candidate:" { print $2 }')
[[ -n $target && $target != '(none)' ]] || fail 'no repository offers ffmpeg'

# Every installed package built from the ffmpeg source at a version no repository offers.
args=()
while IFS=$'\t' read -r source package version; do
  [[ $source == ffmpeg ]] || continue
  offered "${package%%:*}" "$version" && continue
  offered "${package%%:*}" "$target" || fail "no repository offers $package at $target"
  args+=("$package=$target")
done < <(dpkg-query -W -f='${source:Package}\t${binary:Package}\t${Version}\n')

[[ ${#args[@]} -gt 0 ]] ||
  fail 'ffmpeg is not installable, but no FFmpeg library is at an unavailable version; inspect: apt-get -s install ffmpeg'

echo "repair-ffmpeg.sh: moving FFmpeg libraries to $target: ${args[*]}"
apt-get -s --no-remove --allow-downgrades --no-install-recommends install ffmpeg "${args[@]}" >/dev/null ||
  fail "apt cannot apply the repair without removals; inspect: apt-get -s --allow-downgrades install ffmpeg ${args[*]}"
sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-remove --allow-downgrades \
  --no-install-recommends ffmpeg "${args[@]}"
ffmpeg_installable || fail 'ffmpeg is still not installable after the repair'
echo 'repair-ffmpeg.sh: ffmpeg installed'
