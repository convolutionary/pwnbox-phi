# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: phi-nix-progress.awk
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
#
# reads `nix build --log-format internal-json` on stdin and splits it in two:
#   logf=FILE   plain text for humans and for ops_failed_pkgs: what got
#               built or copied, build output, errors
#   state=FILE  rewritten about once a second for tui_progress:
#                 line 1  permille done (0-1000)
#                 line 2  summary, "1.2 / 41.7 GiB · 800 / 4865 paths · ..."
#                 line 3  what nix is doing right now
#               plus the last few build output lines
#
# gawk only (match with an array). nix sends millions of download progress
# events on a big install, so everything here is a regex, no json parser
#
# activity types (nix/src/libutil/logging.hh): 100 copy path, 101 file
# transfer, 103 copy paths, 104 builds, 105 build, 108 substitute.
# result types: 101 build log line, 104 set phase, 105 progress, 106 set expected

function jstr(s) {
    gsub(/\\u001b\[[0-9;]*[A-Za-z]/, "", s) # colours from the builders
    gsub(/\\"/, "\"", s)
    gsub(/\\t/, "  ", s)
    gsub(/\\n|\\r/, " ", s)
    gsub(/\\\\/, "\\", s)
    return s
}
function short(p) {
    sub(/^\/nix\/store\/[a-z0-9]+-/, "", p)
    sub(/\.drv$/, "", p)
    return p
}
function human(b) {
    if (b >= 1073741824) return sprintf("%.1f GiB", b / 1073741824)
    if (b >= 1048576) return sprintf("%.0f MiB", b / 1048576)
    return sprintf("%.0f KiB", b / 1024)
}
function tail_add(s, i) {
    for (i = 1; i < TAILN; i++) tl[i] = tl[i + 1]
    tl[TAILN] = s
}
function dump(now, permille, sum, dl_frac, b_frac, i, f) {
    # compressed bytes off the network for the download part, a plain count
    # for the build part. downloads are most of the wait, so they get most of
    # the bar. nix keeps finding work as it goes, so the totals can grow and
    # the bar can step back a little. that's honest, a clamp got stuck at 100%
    dl_done = x_finished
    for (i in x_done) dl_done += x_done[i]
    dl_frac = dl_exp > 0 ? dl_done / dl_exp : (paths_exp > 0 ? paths_done / paths_exp : 0)
    if (dl_frac > 1) dl_frac = 1
    b_frac = builds_exp > 0 ? builds_done / builds_exp : 0
    if (builds_exp == 0) f = dl_frac
    else if (dl_exp + paths_exp == 0) f = b_frac
    else f = dl_frac * 0.8 + b_frac * 0.2
    permille = int(f * 1000)
    if (permille > 999) permille = 999 # 100% is for when nix exits 0

    sum = ""
    if (dl_exp > 0) sum = human(dl_done) " / " human(dl_exp)
    if (paths_exp > 0) sum = sum (sum ? " · " : "") paths_done " / " paths_exp " packages"
    if (builds_exp > 0) sum = sum (sum ? " · " : "") builds_done " / " builds_exp " built"
    if (builds_running > 0) sum = sum " (" builds_running " running)"
    if (builds_failed + paths_failed > 0) sum = sum " · " (builds_failed + paths_failed) " failed"
    if (sum == "") sum = "working out what to download"

    printf "%d\n%s\n%s\n", permille, sum, current > tmp
    for (i = 1; i <= TAILN; i++) if (tl[i] != "") print tl[i] > tmp
    close(tmp)
    system("mv -f '" tmp "' '" state "'")
    last_dump = now
}

BEGIN {
    TAILN = 4
    tmp = state ".tmp"
    current = "evaluating the configuration (a minute or two, no download yet)"
}

!/^@nix / { # plain stderr from nix itself (warnings, eval errors)
    print > logf
    fflush(logf)
    next
}

{
    match($0, /"action":"([a-z]+)"/, m); act = m[1]
    id = ""; if (match($0, /"id":([0-9]+)/, m)) id = m[1]
    type = ""; if (match($0, /"type":([0-9]+)/, m)) type = m[1]
}

act == "start" {
    if (type == 103) copies_id = id
    else if (type == 104) builds_id = id
    else if (type == 105 && match($0, /"fields":\["([^"]+)"/, m)) {
        bname[id] = short(m[1])
        current = "building " bname[id]
        print "building " m[1] > logf
        fflush(logf)
        dirty = 1
    } else if (type == 101 && match($0, /"fields":\["([^"]+)"/, m)) {
        # nar downloads only, the narinfo lookups are noise
        if (m[1] !~ /\.narinfo$/) xfer[id] = 1
    } else if (type == 100 && match($0, /"fields":\["([^"]+)"/, m)) {
        if (builds_running == 0) current = "downloading " short(m[1])
        print "copying " m[1] > logf
    }
}

act == "stop" {
    if (id in xfer) {
        x_finished += x_done[id]
        delete x_done[id]; delete xfer[id]
    }
    if (id in bname) {
        print "built " bname[id] > logf
        delete bname[id]
        current = ""
        for (i in bname) current = "building " bname[i]
        dirty = 1
    }
}

act == "result" {
    if (type == 105 && match($0, /"fields":\[([0-9]+),([0-9]+),([0-9]+),([0-9]+)\]/, m)) {
        if (id == builds_id) {
            builds_done = m[1]; builds_exp = m[2]; builds_running = m[3]; builds_failed = m[4]
        } else if (id == copies_id) {
            paths_done = m[1]; paths_exp = m[2]; paths_failed = m[4]
        } else if (id in xfer) {
            x_done[id] = m[1]
        }
    } else if (type == 106 && match($0, /"fields":\[([0-9]+),([0-9]+)\]/, m)) {
        # nix sets these once, on the realise activity. 101 is download bytes
        if (m[1] == 101) dl_exp = m[2]
    } else if (type == 101 && match($0, /"fields":\["((\\.|[^"\\])*)"/, m)) {
        s = jstr(m[1])
        print (id in bname ? bname[id] "> " : "") s > logf
        if (s ~ /[^ ]/) tail_add(s)
    } else if (type == 104 && (id in bname) && match($0, /"fields":\["([^"]+)"/, m)) {
        current = "building " bname[id] " (" m[1] ")"
        print bname[id] "> " m[1] > logf
    }
}

act == "msg" && match($0, /"msg":"((\\.|[^"\\])*)"/, m) {
    s = jstr(m[1])
    print s > logf
    fflush(logf)
    # level 0 is an error. those are what the failure screen needs to show
    if (match($0, /"level":0/)) { tail_add(s); dirty = 1 }
}

{
    now = systime()
    if (now != last_dump || dirty) { dump(now); dirty = 0 }
}

END {
    current = ""
    dump(systime())
    fflush(logf)
}
