# ─────────────────────────────────φ─────────────────────
#  pwnbox·phi :: power.nix
#  φ = 1.6180339887…   phi was here
# ───────────────────────────────────────────────────────
# adaptive power for laptops: full speed on the charger, power saving on
# battery, switching the moment you plug in or out.
#
# pwnbox.performance can't do this. it turns deep c-states off with kernel
# parameters, which only change at boot. auto-cpufreq switches governor,
# energy preference and turbo at runtime instead, so the two don't mix.
{
  config,
  lib,
  ...
}:
let
  cfg = config.pwnbox.phi.power;
in
{
  options.pwnbox.phi.power.adaptive = lib.mkEnableOption ''
    adaptive power: performance governor and turbo on the charger, powersave
    with turbo off on battery. For laptops; leave pwnbox.performance off with it
  '';

  config = lib.mkIf cfg.adaptive {
    assertions = [
      {
        assertion = !config.pwnbox.performance.enable;
        message = ''
          pwnbox.phi.power.adaptive and pwnbox.performance are both on.
          performance mode pins the cpu at boot, so adaptive can't do its job.
          set pwnbox.performance.enable = false on this host.
        '';
      }
    ];

    services.auto-cpufreq = {
      enable = true;
      settings = {
        charger = {
          governor = "performance";
          energy_performance_preference = "performance";
          turbo = "auto";
        };
        battery = {
          governor = "powersave";
          energy_performance_preference = "power";
          turbo = "never";
        };
      };
    };

    # gnome turns power-profiles-daemon on by default, and it fights
    # auto-cpufreq over the same knobs
    services.power-profiles-daemon.enable = lib.mkForce false;
    services.tlp.enable = lib.mkForce false;

    # amd_pstate in active mode is what makes the energy preference above
    # mean anything on ryzen. intel ignores it
    boot.kernelParams = [ "amd_pstate=active" ];

    # so the bar and `upower -d` can show charge and time left
    services.upower.enable = lib.mkDefault true;
  };
}
