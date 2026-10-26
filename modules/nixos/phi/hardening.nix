# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: hardening.nix
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
# extra hardening on top of hardening.nix. phi-audit checks most of this,
# so add a check there when you add something here.
{
  config,
  lib,
  ...
}:
let
  cfg = config.pwnbox.phi.hardening;
in
lib.mkIf cfg.enable (
  lib.mkMerge [
    {
      boot.kernel.sysctl = {
        # io_uring has had a long run of kernel privesc bugs. 1 = root (and
        # io_uring_group) only
        "kernel.io_uring_disabled" = 1;
        # ignore pings. the firewall drops them too, but this also covers
        # boot before the firewall is up
        "net.ipv4.icmp_echo_ignore_all" = 1;
        # ipv6 temporary addresses: nixos already sets use_tempaddr = 2
        # through networking.tempAddresses, defining it again is an error
      };
      networking.firewall.allowPing = false;

      # random mac per connection, and no hostname in dhcp requests.
      # scanRandMacAddress in networking.nix only covers wifi scans.
      networking.networkmanager = {
        wifi.macAddress = "random";
        ethernet.macAddress = "random";
        connectionConfig = {
          "ipv4.dhcp-send-hostname" = false;
          "ipv6.dhcp-send-hostname" = false;
          "ipv6.ip6-privacy" = 2;
        };
      };
    }

    # plain ntp is unauthenticated, so anyone on the path can shift the clock
    # (expired certs start validating again). nts authenticates the server.
    (lib.mkIf cfg.ntsTime {
      services.chrony = {
        enable = true;
        enableNTS = true;
        servers = [
          "time.cloudflare.com"
          "nts.netnod.se"
          "ptbtime1.ptb.de"
        ];
      };
    })

    (lib.mkIf cfg.usbguard {
      services.usbguard = {
        enable = true;
        presentDevicePolicy = "allow";
        implicitPolicyTarget = "block";
        IPCAllowedGroups = [ "wheel" ];
      };
    })

    (lib.mkIf cfg.noWebcam {
      boot.blacklistedKernelModules = [ "uvcvideo" ];
    })

    (lib.mkIf cfg.kernelLockdown {
      boot.kernelParams = [ "lockdown=confidentiality" ];
    })
  ]
)
