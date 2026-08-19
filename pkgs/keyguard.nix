# Keyguard：nixpkgs 当前版本明显滞后，因此封装官方最新 x86_64 Linux 发行包。
# 上游 Compose/Skiko 暂未支持原生 Wayland，KDE Wayland 会通过 XWayland 运行。
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  cups,
  fontconfig,
  freetype,
  glib,
  gtk3,
  lcms2,
  libglvnd,
  libx11,
  libxext,
  libxi,
  libxinerama,
  libxrandr,
  libxrender,
  libxtst,
  wayland,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "keyguard";
  version = "3.0.3";

  src = fetchurl {
    url = "https://github.com/AChep/keyguard-app/releases/download/r20260818.1/Keyguard-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-7SR9kftNSyTsbqK2v2li4NKhLNwdqG5cey+SSIDh7Xg=";
  };

  sourceRoot = "Keyguard";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    cups
    fontconfig
    freetype
    glib
    gtk3
    lcms2
    libglvnd
    libx11
    libxext
    libxi
    libxinerama
    libxrandr
    libxrender
    libxtst
    stdenv.cc.cc.lib
    wayland
    zlib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/opt/keyguard"
    cp -R . "$out/opt/keyguard"
    mv "$out/opt/keyguard/share" "$out/share"
    sed -i '/^Encoding=/d' "$out/share/applications/com.artemchep.keyguard.desktop"

    makeWrapper "$out/opt/keyguard/bin/Keyguard" "$out/bin/Keyguard" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath finalAttrs.buildInputs}"

    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath "$out/opt/keyguard/lib/runtime/lib"
    addAutoPatchelfSearchPath "$out/opt/keyguard/lib/runtime/lib/server"
  '';

  meta = {
    description = "Alternative client for Bitwarden and KeePass";
    homepage = "https://github.com/AChep/keyguard-app";
    license = lib.licenses.unfree;
    mainProgram = "Keyguard";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
