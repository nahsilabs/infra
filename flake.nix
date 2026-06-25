{
  description = "Setup ops things";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.systems.url = "github:nix-systems/default";
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.systems.follows = "systems";
  };
  inputs.mcp-servers-nix = {
    url = "github:natsukium/mcp-servers-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      mcp-servers-nix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          system = "${system}";
          config.allowUnfree = true;
        };

        mcpConfig = mcp-servers-nix.lib.mkConfig pkgs {
          flavor = "claude-code";
          settings.servers.flux = {
            type = "http";
            url = "https://ai.nahsi.dev/mcp/flux";
          };
          settings.servers.grafana = {
            type = "http";
            url = "https://ai.nahsi.dev/mcp/grafana";
          };
        };
      in
      {
        formatter = pkgs.nixfmt-rfc-style;
        devShells.default = pkgs.mkShell {
          name = "infra";

          packages = [
            pkgs.bashInteractive
            pkgs.nixfmt-rfc-style

            pkgs.ansible
            pkgs.sshpass
            pkgs.talosctl
            pkgs.kubectl
            pkgs.kubectl-cnpg
            pkgs.kubelogin-oidc
            pkgs.kubernetes-helm
            pkgs.cilium-cli
            pkgs.fluxcd
            pkgs.terraform

            pkgs.age
            pkgs.sops
          ];

          shellHook = ''
            [[ -L .mcp.json ]] && unlink .mcp.json
            ln -sf ${mcpConfig} .mcp.json
            [[ -f $NAHSILABS_SECRETS ]] && source $NAHSILABS_SECRETS
            [[ -f terraform/talos/kubeconfig ]] && export KUBECONFIG=$(realpath terraform/talos/kubeconfig)
            [[ -f terraform/talos/talosconfig ]] && export TALOSCONFIG=$(realpath terraform/talos/talosconfig)
          '';
        };
      }
    );
}
