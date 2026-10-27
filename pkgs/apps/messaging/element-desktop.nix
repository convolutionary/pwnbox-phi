{
  callPackage,
  jq,
  stdenvNoCC,
  element-desktop,
  element-web-unwrapped,
}:
let
  element-web-labs = stdenvNoCC.mkDerivation {
    pname = "element-web-pwnbox";
    inherit (element-web-unwrapped) version;
    dontUnpack = true;
    nativeBuildInputs = [ jq ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r ${element-web-unwrapped}/. "$out"/
      jq '.show_labs_settings = true' "$out/config.json" > "$out/config.json.new"
      mv "$out/config.json.new" "$out/config.json"
      runHook postInstall
    '';
  };
in
callPackage ./asar-inject.nix { } {
  pkg = element-desktop;
  asarPath = "share/element/app.asar";
  entry = "lib/electron-main.js";
  loader = ./element-loader.js;
  # the webapp is a symlink in the cached build. swapping it here instead of
  # element-desktop.override { element-web } keeps the cached build usable
  postBuild = ''
    rm $out/share/element/webapp
    ln -s ${element-web-labs} $out/share/element/webapp
  '';
  description = "pwnbox: pywal theme + font injection";
}
