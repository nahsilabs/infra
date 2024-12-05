{
  description = "Setup ops things";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  inputs.systems.url = "github:nix-systems/default";
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.systems.follows = "systems";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          system = "${system}";
          config.allowUnfree = true;
        };
      in
      {
        formatter = pkgs.nixfmt-rfc-style;
        devShells.default = pkgs.mkShell {
          name = "infra";

          packages = [
            pkgs.bashInteractive
            pkgs.nixfmt-rfc-style

            pkgs.terraform
            pkgs.packer
            pkgs.vault
            pkgs.talosctl
            pkgs.kubectl
            pkgs.kubelogin-oidc
            pkgs.kubernetes-helm
            pkgs.cilium-cli
            pkgs.fluxcd

            pkgs.age
            pkgs.sops
          ];

          shellHook = ''
            [[ -f $NAHSILABS_SECRETS ]] && source $NAHSILABS_SECRETS
            [[ -f kubeconfig ]] && export KUBECONFIG=$(realpath kubeconfig)
            [[ -f talosconfig ]] && export TALOSCONFIG=$(realpath talosconfig)
          '';
        };
      }
    );
}
