{
  inputs = {
    nixpkgs.url = "nixpkgs";
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, utils }: {
    nixosModules.default = import ./module.nix;
  } // (utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      formatter = pkgs.alejandra;
      devShells.default = pkgs.mkShell {
        buildInputs = [
          pkgs.alejandra
          pkgs.nvfetcher
        ];
      };
    }
  ));
}
