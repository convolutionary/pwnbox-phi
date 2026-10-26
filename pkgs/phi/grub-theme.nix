# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: grub-theme.nix
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
# the grub theme for the installer iso. same recipe as upstream's
# pwnbox-grub-theme: fonts from the repo's manrope, highlight pieces drawn
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

    # the selected entry: a solid gold bar, rounded
    magick -size 16x16 canvas:none \
      -fill 'rgba(212,175,55,0.95)' -draw 'roundrectangle 0,0,15,15,5,5' \
      -define png:color-type=6 -strip select_box.png

    magick -size 16x16 canvas:none \
      -fill 'rgba(12,11,9,0.94)' -draw 'roundrectangle 0,0,15,15,7,7' \
      -define png:color-type=6 -strip terminal_box.png

    for piece in nw n ne e se s sw w c; do
      cp select_box.png "select_$piece.png"
      cp terminal_box.png "terminal_box_$piece.png"
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp phi/grub/theme.txt "$out/theme.txt"
    cp phi/art/grub-efi.png "$out/background.png"
    cp ./*.pf2 select_*.png terminal_box_*.png "$out/"
    runHook postInstall
  '';

  meta = {
    description = "pwnbox·phi grub theme: gold on near-black, menu on the golden cut";
    license = lib.licenses.unlicense;
    platforms = lib.platforms.all;
  };
}
