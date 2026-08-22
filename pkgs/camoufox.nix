{
  lib,
  stdenv,
  fetchurl,
  fetchPypi,
  unzip,
  wrapGAppsHook3,
  autoPatchelfHook,
  patchelfUnstable,
  makeWrapper,
  alsa-lib,
  curl,
  dbus-glib,
  gtk3,
  libxtst,
  libva,
  pciutils,
  pipewire,
  adwaita-icon-theme,
  python3Packages,
}:

let
  browserVersion = "152.0.4-beta.28";
  browserLibName = "camoufox-${browserVersion}";

  browser = stdenv.mkDerivation {
    pname = "camoufox-browser";
    version = browserVersion;

    src = fetchurl {
      url = "https://github.com/daijro/camoufox/releases/download/v${browserVersion}/camoufox-${browserVersion}-lin.x86_64.zip";
      hash = "sha256-kk8xCczW1HzWoDhNZ6NF+t+XXUi2MZ+Nu9WVTFiJgr0=";
    };

    nativeBuildInputs = [
      unzip
      wrapGAppsHook3
      autoPatchelfHook
      patchelfUnstable
    ];

    buildInputs = [
      gtk3
      adwaita-icon-theme
      alsa-lib
      dbus-glib
      libxtst
    ];

    runtimeDependencies = [
      curl
      pciutils
      libva.out
    ];

    appendRunpaths = [ "${pipewire}/lib" ];
    patchelfFlags = [ "--no-clobber-old-sections" ];

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      unzip "$src"
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/${browserLibName}" "$out/bin"
      cp -r . "$out/lib/${browserLibName}"
      printf '%s\n' \
        '{"version":"152.0.4","build":"beta.28"}' \
        > "$out/lib/${browserLibName}/version.json"
      ln -s "$out/lib/${browserLibName}/camoufox-bin" "$out/bin/camoufox-browser"

      runHook postInstall
    '';

    passthru = {
      binaryName = "camoufox-browser";
      libName = browserLibName;
    };

    meta = {
      description = "Camoufox anti-detect browser binary";
      homepage = "https://camoufox.com";
      license = lib.licenses.mpl20;
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      platforms = [ "x86_64-linux" ];
      mainProgram = "camoufox-browser";
    };
  };
in
python3Packages.buildPythonApplication rec {
  pname = "camoufox";
  version = "0.5.5";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-GLerf4Ry77KojnI1gmWqPrV669f4fZO9+oZW3KtwNbo=";
  };

  build-system = [ python3Packages.poetry-core ];

  dependencies = with python3Packages; [
    rich-click
    rich
    requests
    orjson
    browserforge
    playwright
    pyyaml
    platformdirs
    numpy
    ua-parser
    typing-extensions
    screeninfo
    lxml
    language-tags
    pysocks
    inquirer
  ];

  # 上游尚未放宽到 1.61；下面的运行测试会验证当前 nixpkgs 版本兼容。
  pythonRelaxDeps = [ "playwright" ];

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    # 浏览器由 Nix 固定版本提供；用户缓存仍只用于 Camoufox 的可写运行时数据。
    substituteInPlace camoufox/pkgman.py \
      --replace-fail \
        "    from .multiversion import get_active_path" \
        $'    bundled_path = os.getenv("CAMOUFOX_BROWSER_PATH")\n    if bundled_path:\n        return Version.from_path(Path(bundled_path)).full_string\n    from .multiversion import get_active_path' \
      --replace-fail \
        "    from .multiversion import COMPAT_FLAG, get_active_path" \
        $'    bundled_path = os.getenv("CAMOUFOX_BROWSER_PATH")\n    if bundled_path:\n        return Path(bundled_path)\n    from .multiversion import COMPAT_FLAG, get_active_path'
  '';

  postInstall = ''
    wrapProgram "$out/bin/camoufox" \
      --set CAMOUFOX_BROWSER_PATH "${browser}/lib/${browserLibName}"
    ln -s "${browser}/bin/camoufox-browser" "$out/bin/camoufox-browser"
  '';

  pythonImportsCheck = [ "camoufox" ];
  doCheck = false;

  passthru = {
    inherit browser;
    browserPath = "${browser}/lib/${browserLibName}";
  };

  meta = {
    description = "Python interface and packaged browser for Camoufox";
    homepage = "https://camoufox.com/python";
    license = [
      lib.licenses.mit
      lib.licenses.mpl20
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "camoufox";
  };
}
