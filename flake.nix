{
  description = "Fluxer Canary desktop client, packaged for Nix (nixpkgs-ready)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      overlays.default = final: _prev: {
        fluxer-canary = final.callPackage ./pkgs/by-name/fl/fluxer-canary/package.nix { };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          fluxer-canary = pkgs.callPackage ./pkgs/by-name/fl/fluxer-canary/package.nix { };
        in
        {
          inherit fluxer-canary;
          default = fluxer-canary;
        }
      );
    };
}
