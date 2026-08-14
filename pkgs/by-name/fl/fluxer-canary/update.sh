#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq common-updater-scripts nix
set -euo pipefail

api="https://api.canary.fluxer.app/dl/desktop/canary/linux"

x64=$(curl -sSf "$api/x64/latest")
arm64=$(curl -sSf "$api/arm64/latest")

version=$(jq -r '.version' <<<"$x64")
arm64_version=$(jq -r '.version' <<<"$arm64")

if [[ "$version" != "$arm64_version" ]]; then
  echo "x64 ($version) and arm64 ($arm64_version) are on different versions; skipping" >&2
  exit 0
fi

to_sri() {
  nix hash convert --hash-algo sha256 --to sri "$1"
}

x64_hash=$(to_sri "$(jq -r '.files.appimage.sha256' <<<"$x64")")
arm64_hash=$(to_sri "$(jq -r '.files.appimage.sha256' <<<"$arm64")")

update-source-version fluxer-canary "$version" "$x64_hash" \
  --system=x86_64-linux --ignore-same-version
update-source-version fluxer-canary "$version" "$arm64_hash" \
  --system=aarch64-linux --ignore-same-version
