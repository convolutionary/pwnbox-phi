# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: default.nix
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
# the phi-* tools. the scripts live in phi/bin so you can run them from a
# checkout too. this just installs them and wraps them with their deps.
{
  lib,
  stdenvNoCC,
  makeWrapper,
  bc,
  btrfs-progs,
  coreutils,
  cryptsetup,
  curl,
  dosfstools,
  e2fsprogs,
  findutils,
  gawk,
  gnugrep,
  gnused,
  gptfdisk,
  iproute2,
  jq,
  libnotify,
  ncurses,
  parted,
  util-linux,
}:
let
  # mullvad, nmcli, rfkill and hyprlock come from the system PATH on purpose.
  # their own modules install them, and the mullvad cli has to match the daemon.
  # same for nixos-install / nixos-enter / udevadm on the iso.
  runtimeDeps = [
    bc
    coreutils
    curl
    findutils
    gawk
    gnugrep
    gnused
    iproute2
    jq
    libnotify
    ncurses
    util-linux
  ];

  # only phi-install needs these
  diskDeps = [
    btrfs-progs
    cryptsetup
    dosfstools
    e2fsprogs
    gptfdisk
    parted
  ];
in
stdenvNoCC.mkDerivation {
  pname = "phi-tools";
  version = "1.618";

  src = ../../phi/bin;

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 phi-mark $out/share/phi/phi-mark
    install -Dm644 phi-golden.awk $out/share/phi/phi-golden.awk
    install -Dm644 phi-tui $out/share/phi/phi-tui
    install -Dm644 phi-install-ops $out/share/phi/phi-install-ops
    install -Dm644 phi-install-dualboot $out/share/phi/phi-install-dualboot
    for tool in phi phi-vpn phi-audit phi-panic; do
      install -Dm755 "$tool" "$out/bin/$tool"
      wrapProgram "$out/bin/$tool" \
        --set PHI_MARK "$out/share/phi/phi-mark" \
        --prefix PATH : ${lib.makeBinPath runtimeDeps}
    done
    install -Dm755 phi-install $out/bin/phi-install
    wrapProgram $out/bin/phi-install \
      --set PHI_MARK "$out/share/phi/phi-mark" \
      --prefix PATH : ${lib.makeBinPath (runtimeDeps ++ diskDeps)}

    runHook postInstall
  '';

  meta = {
    description = "pwnbox·phi toolkit: branding, mullvad wrapper, hardening audit, panic button, installer";
    license = lib.licenses.unlicense;
    mainProgram = "phi";
    platforms = lib.platforms.linux;
  };
}
