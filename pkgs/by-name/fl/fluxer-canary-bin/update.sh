#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq common-updater-scripts nix
set -euo pipefail

while read -r system arch; do
  # api.fluxer.app/dl/... 302s here; see the comment in package.nix. -L is kept
  # as a safety net in case the final location moves again.
  latest=$(curl -sSfL "https://pkgs.fluxer.com/desktop/canary/linux/$arch/latest.json")

  version=$(jq -r '.version' <<<"$latest")
  hash=$(nix hash convert --hash-algo sha256 --to sri "$(jq -r '.files.appimage.sha256' <<<"$latest")")

  update-source-version fluxer-canary-bin "$version" "$hash" \
    --system="$system" --ignore-same-version
done <<'SYSTEMS'
x86_64-linux x64
aarch64-linux arm64
SYSTEMS
