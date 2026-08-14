# fluxer-canary

Nix package for the [Fluxer](https://fluxer.app) canary desktop client, wrapping the
upstream AppImage with `appimageTools.wrapType2`.

Platforms: `x86_64-linux`, `aarch64-linux`.

## Install

```console
$ nix run github:DeeKahy/fluxer-nix
```

Or through the overlay:

```nix
{
  inputs.fluxer.url = "github:DeeKahy/fluxer-nix";

  nixpkgs.overlays = [ inputs.fluxer.overlays.default ];
  environment.systemPackages = [ pkgs.fluxer-canary ];
}
```

## Updating

`pkgs/by-name/fl/fluxer-canary/update.sh` is wired up as `passthru.updateScript` and
reads the version and per-architecture sha256 from upstream's release metadata. It
needs a nixpkgs checkout to run:

```console
$ nix-shell maintainers/scripts/update.nix --argstr package fluxer-canary
```

Upstream cuts canary builds several times a day, so the pinned version goes stale fast.

## Layout

`pkgs/by-name/fl/fluxer-canary/` mirrors nixpkgs, so it can be copied into a nixpkgs
checkout unchanged.
