# Waywallen：固定官方 x86_64 AppImage，并补齐桌面入口和图标。
# AppImage 已自带 Qt6 / ffmpeg / libstdc++；运行环境补 Vulkan 加载器、PipeWire，
# 以及 open-wallpaper-engine 等第三方插件渲染器在 FHS 环境里额外需要的
# liblz4（场景渲染器直接依赖）和 libva（视频解码回退路径）。
{
  appimageTools,
  fetchurl,
  lib,
  libva,
  lz4,
  pipewire,
  vulkan-loader,
}:

let
  pname = "waywallen";
  version = "0.3.5";

  src = fetchurl {
    url = "https://github.com/waywallen/waywallen/releases/download/v${version}/waywallen-${version}-x86_64.AppImage";
    hash = "sha256-s1RnL7/mwh+mHJgBGTTBUece8aTCyQUuXK4bPACpMcc=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = _: [
    libva
    lz4
    pipewire
    vulkan-loader
  ];

  extraInstallCommands = ''
    install -Dm444 "${appimageContents}/usr/share/applications/org.waywallen.waywallen.desktop" \
      "$out/share/applications/org.waywallen.waywallen.desktop"
    install -Dm444 "${appimageContents}/usr/share/metainfo/org.waywallen.waywallen.metainfo.xml" \
      "$out/share/metainfo/org.waywallen.waywallen.metainfo.xml"
    install -Dm444 "${appimageContents}/usr/share/icons/hicolor/scalable/apps/org.waywallen.waywallen.svg" \
      "$out/share/icons/hicolor/scalable/apps/org.waywallen.waywallen.svg"
  '';

  meta = {
    description = "Wallpaper Manager for Linux (dynamic wallpapers, Wallpaper Engine collection)";
    homepage = "https://github.com/waywallen/waywallen";
    license = lib.licenses.mit;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
