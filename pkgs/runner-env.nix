{
  stdenv,
  lib,
  nb-cli,
  gnused,
  # params
  pyproject,
  uvlock,
}:

let
  fs = lib.fileset;
  sourceFiles = fs.unions [ ../src ];
in

(stdenv.mkDerivation {
  name = "generatedNBProject";
  src = fs.toSource {
    root = ../.;
    fileset = sourceFiles;
  };

  nativeBuildInputs = [
    nb-cli
    gnused
  ];

  patchPhase = ''
    runHook prePatch
    cp ${uvlock} uv.lock
    cp ${pyproject} pyproject.toml
    runHook postPatch
  '';

  buildPhase = ''
    runHook preBuild
    nb generate -f src/generatedNoneBot/bot.py
    sed -i 's|pyproject.toml|${pyproject}|' src/generatedNoneBot/bot.py
    runHook postBuild
  '';

  postInstall = ''
    mkdir "$out"
    cp ./* "$out" -r
  '';
})
// {
  inherit pyproject uvlock;
}
