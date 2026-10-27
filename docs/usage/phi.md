# φ pwnbox·phi

```
  ⡏⠉⣩⠟⠋⠉⡏⠙⠫⡍⡏⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⡇
  ⣧⠞⠁⠀⠀⠀⡇⠀⠀⠘⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡇
  ⡏⠀⠀⠀⠀⠀⣯⡉⠉⣩⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡜⡇    p w n b o x  ·  φ
  ⡏⠉⠉⠉⠉⠉⠉⠉⠉⠉⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡰⠁⡇    ──────────────────────
  ⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡔⠁⠀⡇    φ = 1.618033988749894…
  ⡇⢧⡀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠎⠀⠀⠀⡇
  ⡇⠀⠳⣄⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⢀⠤⠊⠁⠀⠀⠀⠀⡇    irrational, but in a good way
  ⡇⠀⠀⠈⠙⠦⢄⣀⠀⠀⡇⠀⠀⣀⣀⠤⠔⠊⠁⠀⠀⠀⠀⠀⠀⠀⡇
  ⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠁
```

pwnbox·phi is a fork of [kernelstub/Pwnbox](https://github.com/kernelstub/Pwnbox)
It runs Mullvad by default, adds some hardening on top of upstream's, and puts a φ header on every script.

## What phi adds

| Piece | Where | What it does |
| --- | --- | --- |
| `phi` | `phi/bin/phi` | banner, golden-spiral animation, digits of φ, the script stamp |
| `phi-vpn` | `phi/bin/phi-vpn` | Mullvad wrapper: up / down / hop / leak check / harden |
| `phi-audit` | `phi/bin/phi-audit` | grades the live box against the hardening it should have |
| `phi-panic` | `phi/bin/phi-panic` | kill switch + network off + clipboard wipe + lock (`SUPER+SHIFT+ESC`) |
| Mullvad module | `modules/nixos/phi/mullvad.nix` | keeps the tunnel working under locked kernel modules, applies defaults at boot |
| Hardening module | `modules/nixos/phi/hardening.nix` | MAC randomisation, hidden DHCP hostname, NTS time, optional USBGuard / lockdown |
| Branding | `modules/nixos/phi/default.nix` | os-release + boot entries say `pwnbox-phi` |
| `phi-install` | `phi/bin/phi-install` | the installer on the ISO, see [phi-install](../setup/phi-install.md) |
| Art | `phi/art/` | boot splashes and the `phi-golden-spiral` wallpaper (`make-art.py`), the readme banner (`make-banner.py`) |

## Mullvad

Mullvad is on for the main host (`hosts/nixos/default.nix`). After the first
rebuild:

```bash
phi-vpn login
```

Mullvad asks for your account number itself, so it stays out of shell
history. After login, `phi-vpn harden` turns on:

- lockdown mode (the kill switch): no traffic leaves the box unless the tunnel is up
- auto-connect at boot, LAN sharing blocked
- quantum-resistant key exchange and DAITA
- Mullvad DNS with ad / tracker / malware blocking

Lockdown waits until you're logged in, because with no account it would
block the traffic you need to log in.

`phi-mullvad-tune.service` runs `phi-vpn harden` on every boot, so anything
you change in the Mullvad app gets reset to the flake's values. Change them
in the host config instead:

```nix
pwnbox.phi.vpn = {
  lockdown = true;
  relay = "se got";          # country [city [host]], empty = auto
  multihop = false;
  daita = true;
  quantumResistant = true;
  dnsBlocklists = [ "ads" "trackers" "malware" ];
};
```

Day to day:

```bash
phi-vpn            # status
phi-vpn up ch      # connect via Switzerland
phi-vpn hop        # random country
phi-vpn check      # exit IP + DNS leak test, exits 1 on a leak
```

### Kernel modules

Upstream `hardening.nix` sets `security.lockKernelModules`, so no kernel
module can load after boot. Mullvad needs `wireguard`, `tun` and a few
nftables modules, so `phi/mullvad.nix` loads them at boot. It also sets
`src_valid_mark`, or strict reverse-path filtering drops tunnel replies.

## Hardening

On by default (`pwnbox.phi.hardening.enable`), on top of upstream's
`hardening.nix`:

- a new random MAC address per connection, on Wi-Fi and ethernet
- hostname not sent in DHCP requests
- pings ignored, `io_uring` limited to root
- chrony with NTS (authenticated time) instead of plain NTP

These are off by default because each one can lock you out or break tools:

```nix
pwnbox.phi.hardening = {
  usbguard = true;        # new USB devices blocked until allowed
  noWebcam = true;        # uvcvideo blacklisted
  kernelLockdown = true;  # lockdown=confidentiality, breaks bpftrace/perf
};
```

Check the result:

```bash
phi-audit            # full run, includes the Mullvad exit check
phi-audit --offline  # skip network checks
```

The grade is golden at 95% or more, gilded at 61.8% (1/φ), brass at 38.2%
(1/φ²), and flatlined below that.

## The mark

Every script in the repo has this header:

```
# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: install.sh
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
```

The rule is 55 characters wide with φ at column 34 (both Fibonacci numbers).
To mark a new script:

```bash
phi stamp path/to/script.sh
```

The header goes under the shebang, with `#`, `//` or `--` depending on the
file extension. Files that already have it are skipped. The vendored ranger
code isn't marked, and neither are the Quickshell `.js` files, because Qt
wants `.pragma library` on the first line.

## Extras

```bash
phi spiral       # draws r = a·φ^(2θ/π) one dot at a time
phi digits 500   # 500 digits of φ, typed out
phi selftest     # tests digits, the rule and the stamp
phi extras       # install the extras phi-install left for after first boot
```
