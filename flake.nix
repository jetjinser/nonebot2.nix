{
  description = "NoneBot.nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.treefmt-nix.flakeModule
        inputs.devshell.flakeModule
      ];
      perSystem =
        {
          pkgs,
          config,
          ...
        }:
        let
          inherit (pkgs) callPackage;
          python = pkgs.python3;
        in
        {
          treefmt.config = {
            projectRootFile = ".git/config";
            programs = {
              nixfmt.enable = true;
              deadnix.enable = true;
              statix.enable = true;
              mypy.enable = true;
              black.enable = true;
            };
          };

          overlayAttrs = {
            inherit (config.packages) nb2-runner-env nb2-runner nb-cli;
          };
          packages = rec {
            default = nb2-runner;
            nb2-runner-env = callPackage ./pkgs/runner-env.nix {
              pyproject = ./pyproject.toml;
              uvlock = ./uv.lock;
            };
            nb2-runner = callPackage ./pkgs/runner.nix {
              inherit (inputs)
                pyproject-nix
                uv2nix
                pyproject-build-systems
                ;
              python' = python;
              runnerEnv = config.packages.nb2-runner-env;
            };

            nb-cli = pkgs.nb-cli.overridePythonAttrs (prev: {
              version = "${prev.version}-fixed";
              src = pkgs.fetchFromGitHub {
                owner = "jetjinser";
                repo = "nb-cli";
                # use `1.0` watchfiles
                rev = "11e7e50c1586490cbc01c580f9a0ed76dd125399";
                hash = "sha256-/iCxCeKU6fPw4tvUVeeIyJNrq3u7ylrHZpVG3GCSgNM=";
              };
            });
          };

          apps.default.program = config.packages.default;

          devshells.default = {
            packages =
              [ python ]
              ++ (with pkgs; [
                uv
                config.packages.nb-cli
              ]);
          };
        };

      flake = {
        nixosModules.nonebot2 = import ./nixos/module.nix inputs;
        nixosModules.default = self.nixosModules.nonebot2;
      };

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
}
