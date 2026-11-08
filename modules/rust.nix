{ config, pkgs, lib, ... }:

# Optional build toolchain.
#
# Handy if you intend to build whatever you're running directly on the
# server. Drop this import from configuration.nix if you build elsewhere
# (CI, locally, container) and only ship an artifact.
#
# rustup (rather than nixpkgs' rust) keeps toolchain management in your
# hands. After the first `nixos-rebuild switch`, run once as your user:
#
#   rustup default stable
#
# The toolchain persists in ~/.rustup and ~/.cargo across rebuilds.
# Swap this whole file for whatever runtime your app actually needs.

{
  environment.systemPackages = with pkgs; [
    rustup
    gcc           # Linker for cargo
    gnumake       # Native deps (openssl-sys, etc.)
    pkg-config
    openssl
  ];

  # Ensure cargo bin is in PATH for all users
  environment.sessionVariables = {
    PATH = [ "$HOME/.cargo/bin" ];
  };
}
