# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: grub-theme.nix
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
# the grub theme for the installer iso. same recipe as upstream's
# pwnbox-grub-theme: fonts from the repo's manrope, console box drawn
# with imagemagick. the background comes from phi/art/make-art.py
{
  lib,
  stdenvNoCC,
  grub2,
  imagemagick,
}:
stdenvNoCC.mkDerivation {
  pname = "phi-grub-theme";
  version = "1.618";

  # just the four files it needs, not the whole repo
  src = lib.fileset.toSource {
    root = ../../.;
    fileset = lib.fileset.unions [
      ../../dotfiles/gnome/fonts/Manrope-Regular.ttf
      ../../dotfiles/gnome/fonts/Manrope-Bold.ttf
      ../../phi/grub/theme.txt
      ../../phi/art/grub-efi.png
    ];
  };

  nativeBuildInputs = [
    grub2
    imagemagick
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    fonts=dotfiles/gnome/fonts
    grub-mkfont -s 16 -o manrope-16.pf2 $fonts/Manrope-Regular.ttf
    grub-mkfont -s 18 -o manrope-18.pf2 $fonts/Manrope-Regular.ttf
    grub-mkfont -s 18 -o manrope-bold-18.pf2 $fonts/Manrope-Bold.ttf
    grub-mkfont -s 40 -o manrope-bold-40.pf2 $fonts/Manrope-Bold.ttf

    # the console box behind `e` / `c`. square on purpose: grub stretches
    # each of the nine pieces, and rounded corners stretched over a whole
    # edge come out as blobs. the selected entry has no box at all
    magick -size 8x8 xc:'rgba(12,11,9,0.94)' \
      -define png:color-type=6 -strip terminal_box.png
    for piece in nw n ne e se s sw w c; do
      cp terminal_box.png "terminal_box_$piece.png"
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp phi/grub/theme.txt "$out/theme.txt"
    cp phi/art/grub-efi.png "$out/background.png"
    cp ./*.pf2 terminal_box_*.png "$out/"
    runHook postInstall
  '';

  meta = {
    description = "pwnbox·phi grub theme: gold on near-black, menu on the golden cut";
    license = lib.licenses.unlicense;
    platforms = lib.platforms.all;
  };
}
