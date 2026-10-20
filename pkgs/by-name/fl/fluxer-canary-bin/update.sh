#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix
set -euo pipefail

# Upstream serves one desktop channel. See the comment in package.nix for why
# this reads the canary route rather than stable.
#
# The hashes live in a `let`-bound per-architecture attrset rather than in the
# derivation's own attributes, so update-source-version cannot reach them and
# this edits package.nix directly. Run from the root of a nixpkgs checkout.

package=pkgs/by-name/fl/fluxer-canary-bin/package.nix
[[ -f $package ]] || {
  echo "must be run from the root of a nixpkgs checkout" >&2
  exit 1
}

declare -A arch_to_system=([x64]=x86_64-linux [arm64]=aarch64-linux)
declare -A system_to_hash
version=

# Both architectures are cut from the same build and share a version; bail out
# rather than writing a half-updated file if upstream ever breaks that.
for arch in x64 arm64; do
  # api.fluxer.app/dl/... 302s here; -L is kept as a safety net in case the
  # final location moves again.
  latest=$(curl -sSfL "https://pkgs.fluxer.com/desktop/canary/linux/$arch/latest.json")

  arch_version=$(jq -er '.version' <<<"$latest")
  system_to_hash[${arch_to_system[$arch]}]=$(
    nix hash convert --hash-algo sha256 --to sri \
      "$(jq -er '.files.appimage.sha256' <<<"$latest")"
  )

  if [[ -z $version ]]; then
    version=$arch_version
  elif [[ $arch_version != "$version" ]]; then
    echo "version mismatch: x64 is $version, $arch is $arch_version" >&2
    exit 1
  fi
done

current=$(sed -n 's/^  version = "\(.*\)";$/\1/p' "$package")
if [[ $current == "$version" ]]; then
  echo "fluxer-canary-bin is already at $version"
  exit 0
fi

sed -i "s|^  version = \".*\";$|  version = \"$version\";|" "$package"

# Rewrite the hash on the line following each system's attribute name, so the
# two architectures cannot be transposed.
for system in "${!system_to_hash[@]}"; do
  sed -i "/^    $system = {$/,/^    };$/ s|hash = \".*\";|hash = \"${system_to_hash[$system]}\";|" \
    "$package"
done

echo "fluxer-canary-bin: $current -> $version"
