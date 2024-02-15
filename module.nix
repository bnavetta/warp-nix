{ config, pkgs, lib, ... }:
let
  cfg = config.programs.warp;
  sources = pkgs.callPackage ./_sources/generated.nix { };

  appimaged = pkgs.stdenv.mkDerivation {
    name = "appimaged";
    inherit (sources.appimaged) src;
    buildInputs = [ pkgs.makeWrapper ];
    dontStrip = true;
    phases = [ "installPhase" "fixupPhase" ];
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/appimaged
      chmod +x $out/bin/appimaged
    '';
    postFixup = ''
      wrapProgram $out/bin/appimaged \
        --prefix PATH : /run/wrappers/bin:${lib.makeBinPath [ pkgs.desktop-file-utils pkgs.libarchive pkgs.squashfsTools ]}
    '';
    meta.mainProgram = "appimaged";
  };

  warp = pkgs.fetchurl {
    url = "https://releases.warp.dev/stable/v0.2024.02.14.15.46.stable_00/Warp-x86_64.AppImage";
    sha256 = "sha256-olHiGdd09x5qnHpEp1RPbai2nnH1eFZfQs59+A3UC6Y=";
  };
in
{
  options = {
    programs.warp = {
      enable = lib.mkEnableOption "Warp";
      enableAppimaged = lib.mkEnableOption "Appimaged integration daemon";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      { assertion = cfg.enableAppimaged -> pkgs.stdenv.isx86_64; message = "Appimaged is currently only supported on x86-64"; }
    ];

    # Copy Warp into ~/Applications. Making it writable lets Warp auto-update.
    system.userActivationScripts.warpSetup = ''
      mkdir -p $HOME/Applications
      if [ ! -e $HOME/Applications/Warp.AppImage ]; then
        cp ${warp} $HOME/Applications/Warp.AppImage
        chmod +x $HOME/Applications/Warp.AppImage
      fi
    '';

    # Set up nix-ld to run AppImages.
    programs.nix-ld = {
      enable = true;
      # This is based on https://github.com/NixOS/nixpkgs/blob/9d12c7a8167e6380add23a8060282cc2b72bd693/pkgs/build-support/appimage/default.nix#L93,
      # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/programs/nix-ld.nix,
      # and trial and error.
      libraries = [
        pkgs.acl
        pkgs.attr
        pkgs.bzip2
        pkgs.curl
        pkgs.desktop-file-utils
        pkgs.fontconfig.lib
        pkgs.fuse
        pkgs.glib
        pkgs.glibcLocales
        pkgs.libdrm
        pkgs.libGL
        pkgs.libsodium
        pkgs.libssh
        pkgs.libxkbcommon
        pkgs.libxml2
        pkgs.mesa
        pkgs.openssl
        pkgs.stdenv.cc.cc
        pkgs.systemd
        pkgs.util-linux
        pkgs.xorg.libICE
        pkgs.xorg.libSM
        pkgs.xorg.libX11
        pkgs.xorg.libxcb
        pkgs.xorg.libXcomposite
        pkgs.xorg.libXcursor
        pkgs.xorg.libXdamage
        pkgs.xorg.libXext
        pkgs.xorg.libXfixes
        pkgs.xorg.libXi
        pkgs.xorg.libXinerama
        pkgs.xorg.libXrandr
        pkgs.xorg.libXrender
        pkgs.xorg.libXt
        pkgs.xorg.libXtst
        pkgs.xz
        pkgs.zlib
        pkgs.zstd
      ];
    };

    systemd.user.services.appimaged = lib.mkIf cfg.enableAppimaged {
      description = "AppImage system integration daemon";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];

      # Try at most 5 times within a 1-minute interval.
      startLimitIntervalSec = 60;
      startLimitBurst = 5;

      serviceConfig = {
        ExecStart = "${appimaged}/bin/appimaged";
        LimitNOFILE = 65536;
        Restart = "on-failure";
      };

      environment = {
        LAUNCHED_BY_SYSTEMD = "1";
        NIX_LD = config.environment.variables.NIX_LD;
        NIX_LD_LIBRARY_PATH = config.environment.variables.NIX_LD_LIBRARY_PATH;
      };
    };
  };
}
