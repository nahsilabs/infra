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
  inputs.grafana-skills = {
    url = "github:grafana/skills";
    flake = false;
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      mcp-servers-nix,
      grafana-skills,
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
            oauth.clientId = "0828d20757190928";
          };
          settings.servers.grafana = {
            type = "http";
            url = "https://ai.nahsi.dev/mcp/grafana";
            oauth.clientId = "9c9f8850dc579f51";
          };
          settings.servers.victorialogs = {
            type = "http";
            url = "https://ai.nahsi.dev/mcp/victorialogs";
            oauth.clientId = "0d26a34d5060ae09";
          };
          settings.servers.victoriametrics = {
            type = "http";
            url = "https://ai.nahsi.dev/mcp/victoriametrics";
            oauth.clientId = "e2e576888a416c0e";
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
            ln -sfn ${grafana-skills}/skills/grafana-core/dashboarding .agents/skills/dashboarding
            [[ -f $NAHSILABS_SECRETS ]] && source $NAHSILABS_SECRETS
            [[ -f terraform/talos/kubeconfig ]] && export KUBECONFIG=$(realpath terraform/talos/kubeconfig)
            [[ -f terraform/talos/talosconfig ]] && export TALOSCONFIG=$(realpath terraform/talos/talosconfig)
          '';
        };
      }
    );
}
