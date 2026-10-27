{
  callPackage,
  signal-desktop,
}:
callPackage ./asar-inject.nix { } {
  pkg = signal-desktop;
  asarPath = "share/signal-desktop/app.asar";
  entry = "bundles/main.js";
  loader = ./signal-loader.js;
  description = "pwnbox: pywal theme + font injection";
}
