#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq common-updater-scripts nix
set -euo pipefail

# Upstream serves one desktop channel. See the comment in package.nix for why
# this reads the canary route rather than stable.
latest=$(curl -sSf "https://api.fluxer.app/dl/desktop/canary/linux/x64/latest")

version=$(jq -er '.version' <<<"$latest")
hash=$(nix hash convert --hash-algo sha256 --to sri "$(jq -er '.files.appimage.sha256' <<<"$latest")")

update-source-version fluxer-bin "$version" "$hash" --ignore-same-version
