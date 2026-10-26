# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: default.nix
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
# the installer iso: stock minimal nixos underneath, phi on top.
# boots into kmscon (real fonts, so the braille art works), logs in as
# nixos and starts phi-install on the first shell.
{
  inputs,
  lib,
  self,
  pkgs,
  ...
}:
let
  phiTools = pkgs.callPackage ../../pkgs/phi { };
in
{
  imports = [
    (inputs.nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  # the flake rides along on the iso, linked at /pwnbox for phi-install.
  # isoImage.storeContents used to take { object; symlink; } pairs; it only
  # takes plain paths now, and an old-style entry breaks the iso build.
  # referencing the flake from tmpfiles pulls it into the image by itself
  systemd.tmpfiles.rules = [ "L+ /pwnbox - - - - ${self.outPath}" ];

  isoImage = {
    volumeID = "PHIBOX_INST";
    # renders from phi/art/make-art.py. grubTheme off, or the stock nixos
    # theme draws over the splash
    splashImage = ../../phi/art/splash-bios.png;
    efiSplashImage = ../../phi/art/splash-efi.png;
    grubTheme = null;
    # mkForce: the installer profiles set their own labels
    prependToMenuLabel = lib.mkForce "pwnbox-phi ";
    appendToMenuLabel = lib.mkForce " installer";
  };

  image.baseName = lib.mkForce "pwnbox-phi-installer";

  boot.zfs.forceImportRoot = false;

  # networkmanager so phi-install can hand you nmtui for wifi. the minimal
  # iso uses plain wpa_supplicant, and the two fight over the card
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;
  users.users.nixos.extraGroups = [ "networkmanager" ];

  # the kernel console can't draw braille. kmscon renders with a real font
  # (dejavu has the braille block) and does 256 colours
  services.kmscon = {
    enable = true;
    hwRender = true;
    # autologin comes from services.getty.autologinUser, which the
    # installer profile already sets to nixos. kmscon's own option is gone
    fonts = [
      {
        name = "DejaVu Sans Mono";
        package = pkgs.dejavu_fonts;
      }
    ];
    extraConfig = ''
      font-size=15
      palette=custom
      palette-black=12,11,9
      palette-red=230,92,80
      palette-green=134,204,120
      palette-yellow=212,175,55
      palette-blue=125,143,168
      palette-magenta=180,142,173
      palette-cyan=136,181,168
      palette-light-grey=214,210,200
      palette-dark-grey=104,86,46
      palette-light-red=255,122,107
      palette-light-green=166,225,154
      palette-light-yellow=255,196,64
      palette-light-blue=157,180,207
      palette-light-magenta=207,169,204
      palette-light-cyan=168,213,200
      palette-white=255,246,224
      palette-foreground=214,210,200
      palette-background=12,11,9
    '';
  };

  # same palette for the plain console, in case kmscon can't start
  console.colors = [
    "0c0b09"
    "e65c50"
    "86cc78"
    "d4af37"
    "7d8fa8"
    "b48ead"
    "88b5a8"
    "d6d2c8"
    "68562e"
    "ff7a6b"
    "a6e19a"
    "ffc440"
    "9db4cf"
    "cfa9cc"
    "a8d5c8"
    "fff6e0"
  ];

  services.getty.helpLine = lib.mkForce ''

    φ  pwnbox-phi installer
       sudo phi-install          the installer
       phi-install --dry-run     look around without touching a disk
       nmtui                     wifi
  '';

  # first interactive shell on the box starts the installer. quitting it
  # drops you at a normal prompt, and it won't start again by itself
  programs.bash.interactiveShellInit = ''
    if [ -z "''${SSH_TTY:-}" ] && [ "$(id -un)" = nixos ] && [ ! -e /run/phi-install-started ]; then
      sudo touch /run/phi-install-started
      sudo phi-install
      echo
      echo "  phi-install again whenever you want: sudo phi-install"
    fi
  '';

  environment.systemPackages = with pkgs; [
    phiTools
    tmux
    unzip
    git
  ];
}
