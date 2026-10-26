# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: default.nix
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
# pwnbox.phi options, the phi-* package and branding.
# mullvad.nix and hardening.nix in this folder do the rest.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption mkEnableOption types;
  cfg = config.pwnbox.phi;
in
{
  imports = [
    ./mullvad.nix
    ./hardening.nix
  ];

  options.pwnbox.phi = {
    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../../pkgs/phi { };
      defaultText = lib.literalExpression "pkgs.callPackage ./pkgs/phi { }";
      description = "The phi-* toolkit (phi, phi-vpn, phi-audit, phi-panic).";
    };

    branding = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Call the OS `pwnbox-phi` in os-release and boot entries. Cosmetic only;
        `ID` stays `nixos`. Needs `pwnbox.branding` on as well.
      '';
    };

    vpn = {
      lockdown = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Mullvad lockdown mode (kill switch): block all traffic whenever the
          tunnel is down. Only armed once an account is logged in, so a fresh
          install can still reach the net to log in.
        '';
      };

      relay = mkOption {
        type = types.str;
        default = "";
        example = "se got";
        description = "Pin a relay location (`country [city [host]]`). Empty lets Mullvad pick.";
      };

      multihop = mkEnableOption "WireGuard multihop (entry and exit on different relays)";

      daita = mkOption {
        type = types.bool;
        default = true;
        description = "DAITA: pad and shape traffic against AI-driven traffic analysis. Costs some bandwidth.";
      };

      quantumResistant = mkOption {
        type = types.bool;
        default = true;
        description = "Post-quantum key exchange for the WireGuard tunnel.";
      };

      dnsBlocklists = mkOption {
        type = types.listOf (
          types.enum [
            "ads"
            "trackers"
            "malware"
            "adult-content"
            "gambling"
            "social-media"
          ]
        );
        default = [
          "ads"
          "trackers"
          "malware"
        ];
        description = "Mullvad DNS content blocking lists.";
      };
    };

    hardening = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Extra hardening on top of pwnbox's hardening.nix: MAC randomisation
          on every link, hostname hidden from DHCP, pings ignored, io_uring
          restricted, NTS-authenticated time.
        '';
      };

      ntsTime = mkOption {
        type = types.bool;
        default = true;
        description = "Use chrony with NTS (authenticated time) instead of plain timesyncd.";
      };

      usbguard = mkEnableOption ''
        USBGuard: devices plugged in at boot are allowed, anything new is
        blocked until `usbguard allow-device` (wheel can manage it).
        Off by default: a keyboard you plug in later gets blocked too.
      '';

      noWebcam = mkEnableOption "blacklisting the uvcvideo driver so webcams never show up";

      kernelLockdown = mkEnableOption ''
        kernel lockdown=confidentiality. Blocks /dev/mem, kexec, unsigned
        modules and most kernel tracing; breaks bpftrace, perf and some
        anti-cheat/driver tooling
      '';
    };
  };

  config = lib.mkMerge [
    { environment.systemPackages = [ cfg.package ]; }

    (lib.mkIf (config.pwnbox.branding && cfg.branding) {
      system.nixos.distroName = lib.mkForce "pwnbox-phi";
      system.nixos.label = lib.mkForce "pwnbox-phi";
    })
  ];
}
