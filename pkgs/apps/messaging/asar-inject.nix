# appends a loader script to an electron app's main.js without rebuilding
# the app. overrideAttrs on signal/element/wire changes their hash, so the
# binary cache has nothing and the whole app compiles from source on every
# install (signal is a pnpm + rust build that runs a live usb out of ram).
# this takes the cached build as is: symlinks to every file, then a new
# app.asar and a launcher that points at it instead of the original
{
  lib,
  runCommand,
  asar,
}:
{
  pkg,
  asarPath, # relative to $out, e.g. share/signal-desktop/app.asar
  entry, # file inside the asar the loader is appended to
  loader,
  postBuild ? "",
  description,
}:
runCommand pkg.name
  {
    nativeBuildInputs = [ asar ];
    passthru = pkg.passthru or { };
    meta = (pkg.meta or { }) // {
      description = "${pkg.meta.description or pkg.pname} (${description})";
    };
  }
  ''
    cp -rs --no-preserve=mode ${pkg} $out
    find $out -type d -exec chmod u+w {} +

    # the launchers exec electron with the original's app.asar
    for f in $out/bin/*; do
      rm "$f"
      sed "s|${pkg}|$out|g" ${pkg}/bin/$(basename "$f") > "$f"
      chmod +x "$f"
    done

    tmp=$(mktemp -d)
    asar extract ${pkg}/${asarPath} "$tmp"
    chmod -R u+w "$tmp"
    printf '\n' >> "$tmp/${entry}"
    cat ${loader} >> "$tmp/${entry}"
    rm $out/${asarPath}
    asar pack "$tmp" $out/${asarPath}
    rm -rf "$tmp"
    ${postBuild}
  ''
