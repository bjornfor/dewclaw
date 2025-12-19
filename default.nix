{
  pkgs ? import <nixpkgs> {
    config = { };
    overlays = [
      (final: prev: {
        # Upgrade apk-tools if needed.
        apk-tools =
          if prev.lib.versionOlder prev.apk-tools.version "3.0" then
            prev.apk-tools.overrideAttrs (old: {
              version = "3.0.3";
              src = prev.fetchFromGitLab {
                domain = "gitlab.alpinelinux.org";
                owner = "alpine";
                repo = "apk-tools";
                rev = "v3.0.3";
                sha256 = "sha256-ydqJiLkz80TQGyf9m/l8HSXfoTAvi0av7LHETk1c0GI=";
              };
              buildInputs = (old.buildInputs or []) ++ [
                prev.zstd
              ];
            })
          else
            prev.apk-tools;
      })
    ];
  },
  configuration,
}:

let
  inherit (pkgs) lib;

  evaluated = lib.evalModules {
    modules = [
      ./openwrt
      configuration
    ];
    specialArgs = {
      inherit pkgs;
    };
  };

  targets = lib.mapAttrs (_: dev: dev.build.deploy) evaluated.config.openwrt;
in

lib.asserts.checkAssertWarn evaluated.config.assertions evaluated.config.warnings (
  pkgs.buildEnv {
    name = "dewclaw-env";

    paths = lib.attrValues targets;

    passthru = { inherit targets; };
  }
)
