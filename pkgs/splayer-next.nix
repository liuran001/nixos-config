# SPlayer Next：固定官方 x86_64 AppImage，并补齐桌面入口、图标和 Wayland/Fcitx 参数。
{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
  util-linux,
}:

let
  pname = "splayer-next";
  version = "1.0.0";

  src = fetchurl {
    url = "https://github.com/SPlayer-Dev/SPlayer-Next/releases/download/v${version}/splayer-next-${version}-x86_64.AppImage";
    hash = "sha256-11aQDxg76QtHG8cuRFGZRb5is1Ne5YercPXaI8la9Ug=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  # AppRun 用 unshare 检测 Chromium 用户命名空间；检测通过时继续启用 Electron sandbox。
  extraPkgs = _pkgs: [ (lib.getBin util-linux) ];

  extraInstallCommands = ''
    wrapProgram "$out/bin/${pname}" \
      --set PORTABLE_EXECUTABLE_DIR "$out" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}"

    install -Dm444 "${appimageContents}/top.imsyy.splayer_next.desktop" \
      "$out/share/applications/top.imsyy.splayer_next.desktop"
    substituteInPlace "$out/share/applications/top.imsyy.splayer_next.desktop" \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=splayer-next %U'
    install -Dm444 \
      "${appimageContents}/usr/share/icons/hicolor/512x512/apps/SPlayer-Next.png" \
      "$out/share/icons/hicolor/512x512/apps/SPlayer-Next.png"
  '';

  meta = {
    description = "Cross-platform desktop music player with rich lyric support";
    homepage = "https://github.com/SPlayer-Dev/SPlayer-Next";
    license = lib.licenses.agpl3Only;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
