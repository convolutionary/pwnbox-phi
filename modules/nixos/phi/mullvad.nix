# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: mullvad.nix
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
# vpn.nix only starts the daemon. this file keeps mullvad working with
# hardening.nix's module lock and applies phi's settings on every boot.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.pwnbox.phi.vpn;
  mullvad = config.services.mullvad-vpn.package;
  onOff = b: if b then "on" else "off";

  # the daemon takes a moment to open its socket after systemd says "started"
  waitForDaemon = pkgs.writeShellScript "phi-mullvad-wait" ''
    for _ in $(seq 30); do
      ${mullvad}/bin/mullvad status >/dev/null 2>&1 && exit 0
      sleep 1
    done
    echo "mullvad-daemon never answered" >&2
    exit 1
  '';
in
lib.mkIf config.pwnbox.vpn.mullvad {
  # hardening.nix flips kernel.modules_disabled=1 after boot, so whatever
  # the tunnel + mullvad's nftables firewall need must already be loaded
  boot.kernelModules = [
    "tun"
    "wireguard"
    "nf_tables"
    "nft_ct"
    "nft_fib_inet"
    "nft_reject_inet"
  ];

  # strict rp_filter (hardening.nix) drops tunnel replies unless the
  # fwmark counts as a valid source. wg-quick sets the same sysctl.
  boot.kernel.sysctl."net.ipv4.conf.all.src_valid_mark" = 1;
  networking.firewall.checkReversePath = "loose";

  systemd.services.phi-mullvad-tune = {
    description = "φ push pwnbox-phi defaults into mullvad";
    after = [ "mullvad-daemon.service" ];
    requires = [ "mullvad-daemon.service" ];
    wantedBy = [ "multi-user.target" ];

    path = [ mullvad ];
    environment = {
      NO_COLOR = "1";
      PHI_VPN_RELAY = cfg.relay;
      PHI_VPN_LOCKDOWN = onOff cfg.lockdown;
      PHI_VPN_MULTIHOP = onOff cfg.multihop;
      PHI_VPN_DAITA = onOff cfg.daita;
      PHI_VPN_QUANTUM = onOff cfg.quantumResistant;
      PHI_VPN_DNS_BLOCKS = lib.concatMapStringsSep " " (l: "--block-${l}") cfg.dnsBlocklists;
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = waitForDaemon;
      ExecStart = "${config.pwnbox.phi.package}/bin/phi-vpn harden";
    };
  };
}
