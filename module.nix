{ config, pkgs, lib, ... }:
let
  cfg = config.programs.warp;
  sources = pkgs.callPackage ./_sources/generated.nix { };

  appimaged = pkgs.stdenv.mkDerivation {
    inherit (sources.appimaged) pname src;
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

    # Set up nix-ld to run AppImages.
    programs.nix-ld = {
      enable = true;
      # This is based on https://github.com/NixOS/nixpkgs/blob/9d12c7a8167e6380add23a8060282cc2b72bd693/pkgs/build-support/appimage/default.nix#L93
      # and trial and error.
      libraries = lib.attrValues {
        # TODO: desktop-file-utils is needed on $PATH, not $LD_LIBRARY_PATH
        inherit (pkgs) desktop-file-utils fuse zlib;

        # Graphics
        inherit (pkgs) libGL libdrm mesa;
        # X11
        inherit (pkgs) libxkbcommon;
        inherit (pkgs.xorg) libxcb libXcomposite libXtst libXrandr libXext libX11 libXfixes libXinerama libXdamage libXcursor libXrender libXt libXi libSM libICE;
      };
    };

    systemd.user.services.appimaged = lib.mkIf cfg.enableAppimaged {
      description = "AppImage system integration daemon";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];

      # Try at most 5 times within a 1-minute interval.
      startLimitIntervalSec = 60;
      startLimitBurst = 5;

      serviceConfig = {
        ExecStart = "${lib.getExe appimaged}";
        LimitNOFILE = 65536;
        Restart = "on-failure";
      };

      environment = {
        LAUNCHED_BY_SYSTEMD = 1;
        NIX_LD = config.environment.variables.NIX_LD;
        NIX_LD_LIBRARY_PATH = config.environment.variables.NIX_LD_LIBRARY_PATH;
      };
    };
  };
}
