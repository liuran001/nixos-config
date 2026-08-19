# Motrix 2.x beta：从上游源码构建应用，并使用 nixpkgs 维护的 Electron 运行时。
{
  electron_43,
  fetchFromGitHub,
  fetchPnpmDeps,
  fetchurl,
  glib,
  gnutar,
  gtk3,
  gtk4,
  gzip,
  lib,
  makeDesktopItem,
  makeWrapper,
  nodejs_24,
  patchelf,
  pkg-config,
  pnpmConfigHook,
  pnpm_11,
  python3,
  rustPlatform,
  stdenv,
  wrapGAppsHook3,
}:

let
  pnpm = pnpm_11;

  aria2Archive = fetchurl {
    url = "https://github.com/motrixapp/aria2/releases/download/v1.37.0-motrix.4/aria2c-1.37.0-motrix.4-linux-x64.tar.gz";
    hash = "sha256-nPJZRTS4Suv0WW+cc6UmlxGQgQmQnJVN0DB35u9nslA=";
  };

  builtinArtifacts = [
    {
      name = "motrix.filename-template-1.1.1.moext";
      src = fetchurl {
        url = "https://github.com/motrixapp/builtin-plugins/releases/download/motrix.filename-template%401.1.1/motrix.filename-template-1.1.1.moext";
        hash = "sha256-O4jkt5rjoBnx7+wIzNab9vgwiIh/fBMgXx1Y6iK/xNo=";
      };
      signature = fetchurl {
        url = "https://github.com/motrixapp/builtin-plugins/releases/download/motrix.filename-template%401.1.1/motrix.filename-template-1.1.1.moext.sig";
        hash = "sha256-W2v8x04Nkj7TfE8jQL/cTNrDD2QZGhXOXEbdyGWQvG0=";
      };
    }
    {
      name = "motrix.scraper-hook-1.0.0.moext";
      src = fetchurl {
        url = "https://github.com/motrixapp/builtin-plugins/releases/download/motrix.scraper-hook%401.0.0/motrix.scraper-hook-1.0.0.moext";
        hash = "sha256-K20XcfoMy9IeOj2hKEpYm9j5PToq1saBP7pvIdLPyyU=";
      };
      signature = fetchurl {
        url = "https://github.com/motrixapp/builtin-plugins/releases/download/motrix.scraper-hook%401.0.0/motrix.scraper-hook-1.0.0.moext.sig";
        hash = "sha256-dAPV7F9hgZNwvPFT/pVeBzYQm4RMHrU/lZ5uvQeQvng=";
      };
    }
    {
      name = "motrix.url-resolver-1.0.0.moext";
      src = fetchurl {
        url = "https://github.com/motrixapp/builtin-plugins/releases/download/motrix.url-resolver%401.0.0/motrix.url-resolver-1.0.0.moext";
        hash = "sha256-MI39DOhjMvQ6627oT602o31x+Pt+8esbeaDmvrWOSp4=";
      };
      signature = fetchurl {
        url = "https://github.com/motrixapp/builtin-plugins/releases/download/motrix.url-resolver%401.0.0/motrix.url-resolver-1.0.0.moext.sig";
        hash = "sha256-cWr4frKtu0eW7WrGAMmxSEDLg1TrnM6/5hImFbqIwXw=";
      };
    }
  ];

  desktopItem = makeDesktopItem {
    name = "motrix";
    desktopName = "Motrix";
    genericName = "Download Manager";
    comment = "Full-featured download manager";
    exec = "motrix %U";
    icon = "motrix";
    categories = [ "Network" ];
    keywords = [
      "download"
      "bittorrent"
      "magnet"
      "aria2"
    ];
    mimeTypes = [
      "application/x-bittorrent"
      "x-scheme-handler/magnet"
      "x-scheme-handler/motrix"
      "x-scheme-handler/mo"
    ];
    startupWMClass = "Motrix";
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "motrix";
  version = "2.0.0-beta.19";

  src = fetchFromGitHub {
    owner = "agalwood";
    repo = "Motrix";
    tag = "v${finalAttrs.version}";
    hash = "sha256-oxm4bvywZ0w3tatqCIy6WQHT2jjl1HfQxNhyG8WCfqE=";
  };

  cargoRoot = "packages/native-host";
  cargoHash = "sha256-Bm6XPBDP8cCwh3tuTFOmuTE1Q4MIPvOsSb+QG3NAro8=";

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-j0dV3ngYsXfLqakz0Py/qKLB2maQSt5TKc3CHM2jxWI=";
    prePnpmInstall = ''
      printf '\nminimumReleaseAge: 0\n' >> pnpm-workspace.yaml
    '';
  };

  nativeBuildInputs = [
    gnutar
    gzip
    makeWrapper
    nodejs_24
    patchelf
    pkg-config
    pnpm
    pnpmConfigHook
    python3
    wrapGAppsHook3
  ];

  buildInputs = [
    glib
    gtk3
    gtk4
  ];

  npm_config_nodedir = electron_43.headers;
  npm_config_target = electron_43.version;
  npm_config_runtime = "electron";
  npm_config_build_from_source = "true";
  pnpm_config_verify_deps_before_run = "false";
  ELECTRON_OVERRIDE_DIST_PATH = electron_43.dist;
  MOTRIX_SKIP_ELECTRON_REBUILD = "1";
  MOTRIX_SKIP_ENGINE_FETCH = "1";

  postPatch = ''
    printf '\nminimumReleaseAge: 0\n' >> pnpm-workspace.yaml
  '';

  buildPhase = ''
    runHook preBuild

    rm -rf node_modules/electron/dist
    ln -s ${electron_43.dist} node_modules/electron/dist
    printf 'electron\n' > node_modules/electron/path.txt

    builtinArtifactDir=$(mktemp -d)
    ${lib.concatMapStringsSep "\n" (artifact: ''
      cp ${artifact.src} "$builtinArtifactDir/${artifact.name}"
      cp ${artifact.signature} "$builtinArtifactDir/${artifact.name}.sig"
    '') builtinArtifacts}
    export MOTRIX_BUILTIN_ARTIFACT_DIR="$builtinArtifactDir"

    mkdir -p extra/linux/x64
    tar -xzf ${aria2Archive} -C extra/linux/x64
    echo "015e539bc212342818ccac099a8a25b792d30a12a0a1c304de03829fa1b636a8  extra/linux/x64/aria2c" \
      | sha256sum --check --strict
    chmod +x extra/linux/x64/aria2c

    cargo build \
      --manifest-path packages/native-host/Cargo.toml \
      --bins \
      --release \
      --locked \
      --offline
    install -Dm755 \
      packages/native-host/target/release/motrix-native-host \
      packages/native-host/dist/linux-x64/motrix-native-host

    pnpm exec electron-rebuild \
      --force \
      --only better-sqlite3 \
      --arch x64 \
      --version ${electron_43.version}
    pnpm run build:builtin
    pnpm run build:legal
    pnpm run build:electron
    pnpm run stage:electron -- --platform linux --arch x64

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/motrix"
    cp -a ${electron_43.unwrapped}/libexec/electron/. "$out/lib/motrix/"
    chmod -R u+w "$out/lib/motrix"
    rm "$out/lib/motrix/chrome-sandbox"
    rm "$out/lib/motrix/resources/default_app.asar"

    cp -a dist/electron-app "$out/lib/motrix/resources/app"
    install -Dm755 extra/linux/x64/aria2c \
      "$out/lib/motrix/resources/extra/linux/x64/aria2c"
    install -Dm644 extra/aria2.conf \
      "$out/lib/motrix/resources/extra/aria2.conf"
    cp -a dist/builtin-plugins "$out/lib/motrix/resources/builtin-plugins"
    install -Dm755 packages/native-host/dist/linux-x64/motrix-native-host \
      "$out/lib/motrix/resources/bin/motrix-native-host"

    gappsWrapperArgs+=(
      --set CHROME_DEVEL_SANDBOX "${electron_43}/libexec/electron/chrome-sandbox"
    )
    wrapGApp "$out/lib/motrix/electron"
    mkdir -p "$out/bin"
    ln -s ../lib/motrix/electron "$out/bin/motrix"

    install -Dm644 build/256x256.png \
      "$out/share/icons/hicolor/256x256/apps/motrix.png"
    install -Dm444 ${desktopItem}/share/applications/motrix.desktop \
      "$out/share/applications/motrix.desktop"
    install -Dm444 LICENSE "$out/share/licenses/motrix/LICENSE"

    runHook postInstall
  '';

  dontWrapGApps = true;
  doCheck = false;

  postFixup = ''
    # Electron loads graphics/media integrations dynamically, so retain the
    # complete runtime search path from nixpkgs instead of letting the generic
    # ELF fixup remove entries that do not appear in DT_NEEDED.
    while IFS= read -r runtimeElf; do
      runtimeRpath=$(patchelf --print-rpath "$runtimeElf" 2>/dev/null) || continue
      runtimeName=$(basename "$runtimeElf")
      if [ "$runtimeName" = electron ]; then
        installedElf="$out/lib/motrix/.electron-wrapped"
      else
        installedElf="$out/lib/motrix/$runtimeName"
      fi
      if [ -f "$installedElf" ]; then
        patchelf --set-rpath "$runtimeRpath" "$installedElf"
      fi
    done < <(
      find ${electron_43.unwrapped}/libexec/electron \
        -maxdepth 1 -type f -print
    )

    # better-sqlite3 is rebuilt locally for Electron's ABI and needs the C++
    # runtime explicitly in its immutable output closure.
    while IFS= read -r nativeModule; do
      patchelf --add-rpath "${stdenv.cc.cc.lib}/lib" "$nativeModule"
    done < <(find "$out/lib/motrix/resources/app" -type f -name '*.node')
  '';

  meta = {
    description = "Full-featured download manager";
    homepage = "https://motrix.app";
    changelog = "https://github.com/agalwood/Motrix/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "motrix";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
  };
})
