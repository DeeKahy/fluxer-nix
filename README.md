# fluxer-canary-bin

Nix package for the [Fluxer](https://fluxer.app) desktop client, wrapping the
upstream Electron AppImage with `appimageTools.wrapType2`. The `-bin` suffix is
the nixpkgs convention for a repack of an upstream binary.

Platforms: `x86_64-linux` and `aarch64-linux`. Both are cut from the same
upstream build and share a version; the arm64 AppImage was confirmed working by
a contributor on [nixpkgs#552820](https://github.com/NixOS/nixpkgs/pull/552820).

## Channels

Upstream ships exactly one desktop channel today. `stable` on the download API
302s to `canary` and has no per-version route at all, so `canary` is both what
fluxer.app hands every visitor and the only artifact that can be pinned.

Upstream's stated plan is to promote canary to stable and then deliberately
break the canary route for automated downloaders. When a per-version stable
path appears, `src.url` and `update.sh` move onto it.

## Install

```console
$ nix run github:DeeKahy/fluxer-nix
```

Or through the overlay:

```nix
{
  inputs.fluxer.url = "github:DeeKahy/fluxer-nix";

  nixpkgs.overlays = [ inputs.fluxer.overlays.default ];
  environment.systemPackages = [ pkgs.fluxer-canary-bin ];
}
```

## Updating

`pkgs/by-name/fl/fluxer-canary-bin/update.sh` is wired up as
`passthru.updateScript`. It reads the version and each architecture's sha256
from upstream's release metadata and hands them to `update-source-version`,
once per system.

It drives nixpkgs' own updater, so it only runs inside a nixpkgs checkout:

```console
$ nix-shell maintainers/scripts/update.nix --argstr package fluxer-canary-bin
```

`.github/workflows/update-fluxer-canary-bin.yml` covers this repository
instead, where that updater is unavailable. It carries its own equivalent
bump, rehashing each architecture separately, then builds the result and opens
a PR. Upstream cuts builds several times a day, so the pinned version goes
stale fast.

## Layout

`pkgs/by-name/fl/fluxer-canary-bin/` mirrors nixpkgs, so it can be copied into a
nixpkgs checkout unchanged.
