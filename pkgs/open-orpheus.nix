# Open Orpheus：固定官方 x86_64 AppImage，并补齐桌面入口、图标和 Wayland/Fcitx 参数。
{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
}:

let
  pname = "open-orpheus";
  version = "0.16.2";

  src = fetchurl {
    url = "https://github.com/YUCLing/open-orpheus/releases/download/v${version}/Open.Orpheus-${version}-x64.AppImage";
    hash = "sha256-CrvExjQsJRfSfgpRQHfPp2OfdM27oOu7c7LqQN+03Yo=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  extraInstallCommands = ''
    wrapProgram "$out/bin/${pname}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}"

    install -Dm444 "${appimageContents}/Open Orpheus.desktop" \
      "$out/share/applications/open-orpheus.desktop"
    substituteInPlace "$out/share/applications/open-orpheus.desktop" \
      --replace-fail 'Categories=Audio;AudioVideo;Music;Network;' \
      'Categories=Audio;AudioVideo;Music;'
    install -Dm444 \
      "${appimageContents}/usr/share/icons/hicolor/256x256/apps/open-orpheus.png" \
      "$out/share/icons/hicolor/256x256/apps/open-orpheus.png"
  '';

  meta = {
    description = "Cross-platform third-party NetEase Cloud Music client";
    homepage = "https://github.com/YUCLing/open-orpheus";
    license = lib.licenses.mit;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
