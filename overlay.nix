final: prev: {
  # Ensure we have a version of apk-tools that support `apk mkpkg`.
  apk-tools =
    if prev.lib.versionOlder prev.apk-tools.version "3.0.3" then
      prev.apk-tools.overrideAttrs (old: {
        version = "3.0.3";
        src = prev.fetchFromGitLab {
          domain = "gitlab.alpinelinux.org";
          owner = "alpine";
          repo = "apk-tools";
          rev = "v3.0.3";
          sha256 = "sha256-ydqJiLkz80TQGyf9m/l8HSXfoTAvi0av7LHETk1c0GI=";
        };
        buildInputs = (old.buildInputs or [ ]) ++ [
          prev.zstd
        ];
      })
    else
      prev.apk-tools;
}
