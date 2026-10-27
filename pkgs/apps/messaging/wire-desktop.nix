{
  callPackage,
  wire-desktop,
}:
callPackage ./asar-inject.nix { } {
  pkg = wire-desktop;
  asarPath = "share/wire-desktop/resources/app.asar";
  entry = "electron/dist/main.js";
  loader = ./wire-loader.js;
  description = "pwnbox: pywal theme + font injection";
}
