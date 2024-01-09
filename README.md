# Warp on NixOS

This Nix flake defines a NixOS module for running [AppImages](https://appimage.org/) on NixOS without patching or wrapping in [`appimage-run`](https://nixos.wiki/wiki/Appimage).

It configures [`nix-ld`](https://github.com/Mic92/nix-ld) to run AppImages as-is, and can optionally configure [appimaged](https://github.com/probonopd/go-appimage) for system integration.

## Installation

First, add this to your `flake.nix`:

```nix
{
    inputs.warp-nix = {
        url = "github:bnavetta/warp-nix";
        # This assumes you also have nixpkgs as an input.
        inputs.nixpkgs.follows = "nixpkgs";
    };
}
```

Then, import and configure the module in your NixOS configuration:

```nix
modules = [
    warp-nix.nixosModules.default
];

programs.warp = {
    # Support running AppImages
    enable = true;
    # Install Appimaged (x86-64 only)
    enableAppimaged = true;
};

```
