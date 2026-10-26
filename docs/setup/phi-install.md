# phi-install

The pwnbox-phi installer ISO boots into `phi-install`, a full-screen
installer that partitions a disk, writes a host config into the flake and
runs `nixos-install`. The manual route in [ISOs](isos.md#installer-iso) still
works if you'd rather do it by hand.

## Build the ISO

```bash
./scripts/iso.sh installer
```

The image lands in `iso/pwnbox-phi-installer-<arch>.iso`. Flash it like any
other ISO (`dd`, Ventoy).

## What the ISO does differently

- GRUB (UEFI) and syslinux (BIOS) show the golden-spiral splash from
  `phi/art/`. Re-render it with `python3 phi/art/make-art.py`.
- The console is `kmscon` with DejaVu Sans Mono instead of the kernel's
  text console, so the braille art renders and colours match the phi
  palette. If kmscon can't start, the plain console gets the same palette
  and the installer falls back to text-only art.
- NetworkManager replaces wpa_supplicant, so the installer can open `nmtui`
  for Wi-Fi.
- The first shell runs `sudo phi-install`. Quit it and you're at a normal
  prompt; it won't start again by itself.

## The steps

| Step | What it asks |
| --- | --- |
| welcome | nothing, it checks firmware type, memory and that the flake is there |
| network | only shows up when cache.nixos.org can't be reached |
| disk | which disk. Disks with Windows are marked, and picking one asks: next to Windows, or wipe. The USB stick you booted from isn't listed |
| layout | encryption yes/no, ext4 or btrfs |
| system | hostname, username, full name, time zone |
| extras | desktop, pentest toolset, Mullvad, NVIDIA driver (if there's a card), adaptive power (laptops), performance mode, Docker, libvirt, Wireshark, creative, gaming, USBGuard, no webcam |
| review | everything on one screen. Installing means typing the disk name |
| install | runs it all, with the live log tail on screen |
| done | reboot, or stay with the new system mounted at `/mnt` |

Keys: arrows or `j`/`k` to move, `space` to tick, `enter` to pick, `q` to
quit. Nothing touches the disk before you type its name on the review
screen.

## Disk layout

UEFI:

| # | Size | Type | Use |
| --- | --- | --- | --- |
| 1 | 987 MiB | EFI system | `/boot`, FAT32, systemd-boot |
| 2 | rest | Linux / LUKS | root |

BIOS:

| # | Size | Type | Use |
| --- | --- | --- | --- |
| 1 | 1 MiB | BIOS boot | GRUB's core image |
| 2 | 987 MiB | Linux | `/boot`, ext4 |
| 3 | rest | Linux / LUKS | root |

987 is a Fibonacci number, and close to the usual 1 GiB.

On BIOS, `/boot` sits outside the encrypted partition because GRUB can't
unlock LUKS2 volumes that use Argon2id.

btrfs gets `@`, `@home` and `@nix` subvolumes, mounted with
`noatime,compress=zstd`. There's no swap partition; pwnbox uses zram.

## Next to Windows

phi-install looks for Windows Boot Manager on every disk. The welcome
screen says where it found it, and the disk list marks those disks. Pick
one and you get a choice: install next to Windows, or wipe the disk.

Next to Windows uses free space only. It never resizes or touches a Windows
partition, so make room from Windows first:

1. Disk Management → right-click `C:` → **Shrink Volume**
2. Shrink by at least 34 GiB (89 GiB+ if you want the pentest toolset)
3. Boot the installer

Layout after install:

| Partition | Use |
| --- | --- |
| Windows' EFI partition (untouched apart from adding systemd-boot) | `/efi`, systemd-boot itself |
| new 987 MiB XBOOTLDR | `/boot`, NixOS kernels and initrds |
| new root, rest of the free space | `/`, LUKS2 if you picked encryption |

Windows' EFI partition is usually 100 MiB, too small for NixOS kernels,
which is why they get their own XBOOTLDR partition. systemd-boot finds
Windows Boot Manager on its own, so the boot menu lists both, with 5
seconds to pick.

The host also gets `time.hardwareClockInLocalTime = true`, because Windows
keeps the hardware clock in local time and the two would otherwise disagree
by your UTC offset.

Things to know:

- UEFI only. Windows on a BIOS machine sits on an MBR disk, which can't be
  split this way, so on BIOS you only get the wipe option.
- If BitLocker is on, the installer warns you. Windows may ask for the
  recovery key once after the boot order changes, so have it ready
  (account.microsoft.com/devices/recoverykey).
- A Windows update can put Windows Boot Manager back in first place. Pick
  **Linux Boot Manager** in the firmware boot menu (often F12 or F8) and
  it's fixed.
- Windows on a *different* disk than the one you install to is left alone
  and stays bootable from the firmware boot menu, but systemd-boot won't
  list it.

In an answers file, `mode=alongside` or `mode=wipe`. `alongside` is refused
if the disk has no Windows, the machine booted BIOS, or there's less than
34 GiB free.

## NVIDIA

If there's an NVIDIA card, the extras list gets an **nvidia driver** entry,
ticked. It writes `hosts/<hostname>/gpu.nix` with:

- the open kernel modules (required for RTX 50, recommended from RTX 20 on)
  and the latest driver
- on laptops with an AMD or Intel GPU too: PRIME offload. The integrated GPU
  runs the desktop and the NVIDIA card sleeps until you run something with
  `nvidia-offload <program>`. Bus IDs are read from `lspci` at install time
- every NVIDIA module loaded at boot, because the hardening locks module
  loading afterwards and `nvidia_uvm` would otherwise miss its chance

On a laptop (anything with a battery) the extras list offers **adaptive
power**, ticked: performance governor and turbo on the charger, powersave
with turbo off on battery, switching the moment you plug in or out. It's
`auto-cpufreq` under the hood (`pwnbox.phi.power.adaptive`).

**Performance mode** (deep CPU sleep states off, max clocks) is for
desktops. It sets kernel parameters at boot, so it can't follow the charger,
and it can't be on together with adaptive power. If you tick both, adaptive
wins.

## Encryption

`cryptsetup luksFormat --type luks2 --pbkdf argon2id --cipher aes-xts-plain64 --key-size 512`.

cryptsetup asks for the passphrase itself on the real terminal, so it never
goes through the installer script. Same for your user password, which
`passwd` asks for inside the new system at the end.

## What gets written

- the flake, copied to `/home/<user>/pwnbox` and owned by you
- `hosts/<hostname>/default.nix` with your answers as `pwnbox.*` options
- `hosts/<hostname>/hardware-configuration.nix` from `nixos-generate-config`
  (it picks up the LUKS device on its own)
- `hosts/<hostname>/boot.nix`: systemd-boot on UEFI, GRUB on BIOS

## If a step fails

The installer stops at the first command that fails and says which step it
was. The full log is at `/tmp/phi-install.log`. Running `sudo phi-install`
again is safe:

- whatever a failed run left behind (the target mounted at `/mnt`, the LUKS
  container open) is released before any disk is scanned, so Windows is
  still detected and the kernel can load the new partition table
- next to Windows, the `PHI_XBOOT` / `PHI_ROOT` partitions from an earlier
  attempt are removed and their space reused, so a rerun never piles up a
  second pair. Windows' own partitions are never touched
- partitions are found by the partuuid the installer gave them, never by
  guessing their number
- after partitioning, the installer checks that the kernel really loaded the
  new table. If something still holds the disk, it stops there and says so,
  instead of writing to partitions that don't exist

Before a wipe, the review screen lists every partition that will be erased.
If the disk isn't empty but has no Windows boot manager on it, you get a
separate warning screen first.

## Wifi

On the stick, pick **connect to wifi** on the network screen. The installer
unblocks the radio first, since many laptops start with it soft-blocked. The
network you join is copied to the installed system, so it's online at first
boot.

On the installed system, `hardware.enableRedistributableFirmware` is on,
because Intel, Realtek, MediaTek, Broadcom and Qualcomm cards all need
firmware. The WPA2/WPA3 crypto modules are also loaded before
`security.lockKernelModules` disables module loading.

After the first boot, rebuild from the flake as usual:

```bash
cd ~/pwnbox
./scripts/install.sh switch
```

## Trying it without a disk

```bash
phi-install --dry-run
```

walks through every screen and prints the commands instead of running them.
For scripted runs, put the answers in a file:

```
disk=/dev/nvme0n1
mode=wipe
encrypt=yes
fs=btrfs
host=phibox
user=phi
fullname=phi
tz=Europe/Berlin
extras=desktop hacking mullvad
next=install
typed=nvme0n1
```

```bash
sudo phi-install --answers answers.txt
```

`extras=none` installs no extras. Answers go through the same checks as
typed input, and the file is parsed line by line, never sourced.

When testing outside the ISO, `PHI_FLAKE`, `PHI_MNT`, `PHI_FIRMWARE`
(`uefi`/`bios`) and `PHI_SKIP_NET=1` override what the installer would
normally detect.
