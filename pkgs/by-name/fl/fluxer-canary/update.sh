#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq common-updater-scripts nix
set -euo pipefail

latest=$(curl -sSf "https://api.canary.fluxer.app/dl/desktop/canary/linux/x64/latest")

version=$(jq -r '.version' <<<"$latest")
hash=$(nix hash convert --hash-algo sha256 --to sri "$(jq -r '.files.appimage.sha256' <<<"$latest")")

update-source-version fluxer-canary "$version" "$hash" --ignore-same-version
