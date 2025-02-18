inputs:

{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.nonebot2;
  defaultUser = "nonebot2";

  inherit (lib) types;
  mkStrOptionRO =
    default:
    lib.mkOption {
      type = types.str;
      readOnly = true;
      inherit default;
    };

  format = pkgs.formats.toml { };
in
{
  options.services.nonebot2 =
    let
      adapterType = types.submodule {
        options = {
          module_name = lib.mkOption { type = types.str; };
          name = lib.mkOption { type = types.str; };
        };
      };
      nonebotToolType = types.submodule {
        options = {
          adapters = lib.mkOption {
            type = with types; listOf adapterType;
            default = [ ];
          };
          builtin_plugins = lib.mkOption {
            type = with types; listOf str;
            default = [ ];
          };
          plugins = lib.mkOption {
            type = with types; listOf path;
            default = [ ];
          };
        };
      };
      projectType = types.submodule {
        freeformType = format.type;
        options = {
          dependencies = lib.mkOption {
            type = with types; listOf str;
            default = [ ];
          };
          description = mkStrOptionRO "internal nonebot runner";
          name = mkStrOptionRO "generatedNoneBot";
          requires-python = mkStrOptionRO ">=3.9, <4.0";
          scripts = lib.mkOption {
            type = with types; lazyAttrsOf str;
            default.run = "${cfg.settings.project.name}:runner.run";
          };
          version = mkStrOptionRO "0.1.0";
        };
      };
      toolType = types.submodule {
        freeformType = format.type;
        options.nonebot = lib.mkOption {
          type = nonebotToolType;
          default = { };
        };
      };
      settingsType = types.submodule {
        freeformType = format.type;
        options = {
          project = lib.mkOption {
            type = projectType;
            default = { };
          };
          tool = lib.mkOption {
            type = toolType;
            default = { };
          };
        };
      };
    in
    {
      enable = lib.mkEnableOption (lib.mdDoc "Whether to enable nonebot2.");

      mkRunner = lib.mkOption {
        type = with types; functionTo package;
        default =
          {
            pyproject,
            uvlock,
            python ? cfg.python,
            ...
          }:
          pkgs.callPackage ../pkgs/runner.nix {
            inherit (inputs)
              pyproject-nix
              uv2nix
              pyproject-build-systems
              ;
            python' = python;
            runnerEnv = pkgs.callPackage ../pkgs/runner-env.nix {
              inherit pyproject uvlock;
            };
          };
      };
      pyproject = lib.mkOption {
        type = types.path;
        default = format.generate "pyproject.toml" cfg.settings;
      };
      uvlock = lib.mkOption {
        type = types.path;
      };
      python = lib.mkPackageOption pkgs "python3" { };

      user = lib.mkOption {
        type = lib.types.str;
        default = defaultUser;
        description = lib.mdDoc ''
          User under which the service should run. If this is the default value,
          the user will be created, with the specified group as the primary
          group.
        '';
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = defaultUser;
        description = lib.mdDoc ''
          Group under which the service should run. If this is the default value,
          the group will be created.
        '';
      };

      openFirewall = lib.mkEnableOption "Open ports in the firewall for nonebot2.";

      settings = lib.mkOption {
        type = settingsType;
        default = { };
      };
      environment = lib.mkOption {
        type = with types; types.lazyAttrsOf str;
        default = { };
      };
    };

  config = lib.mkIf cfg.enable {
    users.users = lib.optionalAttrs (cfg.user == defaultUser) {
      ${defaultUser} = {
        isSystemUser = true;
        inherit (cfg) group;
      };
    };
    users.groups = lib.optionalAttrs (cfg.group == defaultUser) {
      ${defaultUser} = { };
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf (cfg.openFirewall && builtins.hasAttr "PORT" cfg.environment)
        [
          cfg.environment.PORT
        ];

    systemd.services.nonebot2 = {
      description = "nonebot2 service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      inherit (cfg) environment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        DynamicUser = true;
        StateDirectory = "nonebot2";
        ExecStart = lib.getExe (
          cfg.mkRunner {
            inherit (cfg) pyproject uvlock python;
          }
        );
        Restart = "on-failure";
      };
    };
  };
}
