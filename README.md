# fluxer-bin

Nix package for the [Fluxer](https://fluxer.app) desktop client, wrapping the
upstream Electron AppImage with `appimageTools.wrapType2`. The `-bin` suffix is
the nixpkgs convention for a repack of an upstream binary.

Platform: `x86_64-linux`. Upstream also publishes `arm64` builds, but a previous
contributor reported the arm64 AppImage failing to run and it has not been
tested here, so it is not claimed.

## Channels

Upstream ships exactly one desktop channel today. `stable` on the download API
302s to `canary` and has no per-version route at all, so `canary` is both what
fluxer.app hands every visitor and the only artifact that can be pinned. The
package is therefore named for the client, not for a channel.

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
  environment.systemPackages = [ pkgs.fluxer-bin ];
}
```

## Updating

`pkgs/by-name/fl/fluxer-bin/update.sh` is wired up as `passthru.updateScript` and
reads the version and sha256 from upstream's release metadata. It needs a nixpkgs
checkout to run:

```console
$ nix-shell maintainers/scripts/update.nix --argstr package fluxer-bin
```

In this repository `.github/workflows/update-fluxer-bin.yml` does the same thing
daily and opens a PR. Upstream cuts builds several times a day, so the pinned
version goes stale fast.

## Layout

`pkgs/by-name/fl/fluxer-bin/` mirrors nixpkgs, so it can be copied into a nixpkgs
checkout unchanged.
