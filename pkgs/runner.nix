{
  pkgs,
  lib,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
  runnerEnv,
  # Avoid duplicate names with `pkgs.python`
  python',
}:

let
  inherit (pkgs) callPackage callPackages;
  inherit (callPackages pyproject-nix.build.util { }) mkApplication;

  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = "${runnerEnv}"; };
  overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
  pyprojectOverrides = _final: _prev: { };
  pythonSet = (callPackage pyproject-nix.build.packages { python = python'; }).overrideScope (
    lib.composeManyExtensions [
      pyproject-build-systems.overlays.default
      overlay
      pyprojectOverrides
    ]
  );
in

mkApplication {
  venv = pythonSet.mkVirtualEnv "nb-runner-env" workspace.deps.default;
  package = pythonSet.generatednonebot;
}
