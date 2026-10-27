{
  config,
  lib,
  pkgs,
  ...
}:
let
  # loaded lazily the first time you join a wpa2/wpa3 network, which is
  # usually after modules_disabled=1 has been flipped. then the connection
  # just hangs at "configuring". ccm/gcm/ctr = wpa2/wpa3 ciphers, cmac =
  # protected management frames (mandatory on wpa3), the rest = old tkip
  wifiCrypto = [
    "ccm"
    "gcm"
    "ctr"
    "cmac"
    "ghash_generic" # gcm pulls this in at runtime, not as a module dependency
    "aes_generic"
    "libarc4"
    "michael_mic"
  ];
in
{
  networking.hostName = config.pwnbox.hostName;

  # wifi cards (intel, realtek, mediatek, broadcom, qualcomm) don't work
  # without their firmware blobs. the installer stick has them; the
  # installed system didn't, so wifi died after the first reboot
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  # CONFIG_PACKET is built as a module (af_packet.ko).  hardening.nix sets
  # security.lockKernelModules, which flips kernel.modules_disabled=1 once the
  # system is up, so af_packet has to be loaded before that or PF_PACKET
  # sockets (NetworkManager DHCP, wpa_supplicant, tcpdump) fail afterwards.
  boot.kernelModules = [ "af_packet" ];

  # same problem for wifi: load what it needs before the lock. done as a
  # service, not boot.kernelModules, because module names shift between
  # kernels (some of these are built in on some kernels) and a missing name
  # shouldn't fail the boot. intel's op-mode driver (iwlmvm / iwlmld) is
  # loaded by iwlwifi after its firmware comes up, which can lose the race
  # against the lock too
  systemd.services.phi-wifi-modules = lib.mkIf config.security.lockKernelModules {
    description = "φ load wifi modules before kernel module loading is locked";
    wantedBy = [ "disable-kernel-module-loading.service" ];
    before = [ "disable-kernel-module-loading.service" ];
    after = [
      "systemd-modules-load.service"
      "systemd-udev-trigger.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [
      pkgs.kmod
      config.systemd.package
    ];
    script = ''
      for m in ${lib.concatStringsSep " " wifiCrypto}; do
        modprobe -q "$m" || true
      done
      udevadm settle --timeout=20 || true
      if [ -d /sys/module/iwlwifi ]; then
        modprobe -q iwlmvm || true
        modprobe -q iwlmld || true
        modprobe -q iwldvm || true
      fi
    '';
  };

  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";

    wifi.scanRandMacAddress = true;
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      # "opportunistic" makes resolved probe every DHCP-provided resolver on
      # port 853.  Home routers (e.g. Fritz!Box) do not speak DoT, so after
      # each link/DHCP change the probe fails and lookups can time out until
      # resolved falls back to plain UDP.  Keep plain DNS here; if you want
      # encrypted DNS, point resolved at real DoT servers and use "yes".
      DNSOverTLS = false;
      DNSSEC = "allow-downgrade";
      LLMNR = false;
      MulticastDNS = false;
      Cache = true;
      # Only consulted when no per-link DNS server is known at all -- this is
      # not failover for an unreachable router DNS server.
      FallbackDNS = [
        "9.9.9.9"
        "149.112.112.112"
      ];
    };
  };
}
