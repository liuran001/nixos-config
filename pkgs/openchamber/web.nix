{
  buildNpmPackage,
  fetchurl,
  lib,
  nodejs_22,
}:

buildNpmPackage {
  pname = "openchamber-web";
  version = "1.19.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@openchamber/web/-/web-1.19.0.tgz";
    hash = "sha256-Yf/ZWtQz4OGvvQrGz760XM+F371z73EQCyejqi26ppY=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  nodejs = nodejs_22;
  npmDepsHash = "sha256-XVE7YCOsEDwb6jJObnNPWrLCo1olM9aThw+qmRkDc+Y=";
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  meta = {
    description = "Web CLI for OpenChamber";
    homepage = "https://github.com/openchamber/openchamber";
    license = lib.licenses.mit;
    mainProgram = "openchamber";
    platforms = lib.platforms.linux;
  };
}
