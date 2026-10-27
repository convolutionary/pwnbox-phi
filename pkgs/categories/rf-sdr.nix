{ pkgs, ... }:
# plain nixpkgs on purpose. stubbing out soapyuhd (to skip the uhd download)
# changed the hash of soapysdr, and with it gqrx, sdrpp, rtl_433 and
# gr-osmosdr, so all five compiled from source on every install instead of
# coming from the binary cache
with pkgs;
[
  hackrf
  rtl-sdr
  rtl_433
  sdrpp
  urh
  gqrx
  inspectrum
  multimon-ng
]
