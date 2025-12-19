{
  pkgs,
  lib,
  config,
  ...
}:

let
  package_name = "dewclaw-deps";
  # apk rejects hash as version number.
  version = let
    hash = builtins.hashString "sha256" (toString config.packages);
    digitsOnly =
      lib.stringAsChars
        (x:
          if x == "a" then "10"
          else if x == "b" then "11"
          else if x == "c" then "12"
          else if x == "d" then "13"
          else if x == "e" then "14"
          else if x == "f" then "15"
          else x
        )
        hash;
    in
      digitsOnly;
  depsApk = config.build.depsPackageApk;
  depsIpk = config.build.depsPackageIpk;
in

{
  options.packages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Extra packages to install. These are merely names of packages available
      to apk through the package source lists configured on the device, it is
      not currently possible to provide packages for installation without
      configuring an apk source first.

      For backward compatibility with OpenWRT <= 23.05, opkg will be used if apk
      is unavailable.
    '';
  };

  config = {
    deploySteps.packages = {
      priority = 80;
      copy = ''
        scp ${depsApk} device:/tmp/deps-${version}.apk
        scp ${depsIpk} device:/tmp/deps-${version}.ipk
      '';
      apply = ''
        if command -v apk >/dev/null; then
          if [ "${version}" != "$(apk list --installed --manifest "${package_name}" | cut -d' ' -f2)" ]; then
            apk update
            # TODO: sign packages?
            apk add --allow-untrusted /tmp/deps-${version}.apk
          fi
        elif command -v opkg >/dev/null; then
          if [ "${version}" != "$(opkg info ${package_name} | grep Version | cut -d' ' -f2)" ]; then
            opkg update
            opkg install --autoremove --force-downgrade /tmp/deps-${version}.ipk
          fi
        else
          echo "error: missing package manager (tried 'apk' and 'opkg')"
        fi
      '';
    };

    build.depsPackageApk =
      pkgs.runCommand "deps.apk"
        {
          nativeBuildInputs = [
            pkgs.apk-tools
          ];
        }
        ''
          apk mkpkg \
            --info="name:${package_name}" \
            --info="version:${version}" \
            --info="arch:noarch" \
            ${lib.concatMapStringsSep " " (x: "--info=depends:${x}") config.packages} \
            --output "$out"
        '';

    build.depsPackageIpk =
      pkgs.runCommand "deps.ipk"
        {
          control = ''
            Package: ${package_name}
            Version: ${version}
            Architecture: all
            Description: extra system dependencies
            ${lib.optionalString (
              config.packages != [ ]
            ) "Depends: ${lib.concatStringsSep ", " config.packages}"}
          '';
          passAsFile = [ "control" ];
        }
        ''
          mkdir -p deps/control deps/data
          cp $controlPath deps/control/control
          echo 2.0 > deps/debian-binary

          alias tar='command tar --numeric-owner --group=0 --owner=0'
          (cd deps/control && tar -czf ../control.tar.gz ./*)
          (cd deps/data && tar -czf ../data.tar.gz .)
          (cd deps && tar -zcf $out ./debian-binary ./data.tar.gz ./control.tar.gz)
        '';
  };
}
