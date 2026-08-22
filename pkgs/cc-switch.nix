# CC Switch：固定官方 x86_64 AppImage，并补齐桌面入口和图标。
{
  appimageTools,
  fetchurl,
  lib,
}:

let
  pname = "cc-switch";
  version = "3.16.0";

  src = fetchurl {
    url = "https://github.com/farion1231/cc-switch/releases/download/v${version}/CC-Switch-v${version}-Linux-x86_64.AppImage";
    hash = "sha256-2DbGrJAUH018Pqbkmfc3hLPKEX1uBK0mIPQcnRN8Cl0=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 "${appimageContents}/usr/share/applications/CC Switch.desktop" \
      "$out/share/applications/cc-switch.desktop"
    substituteInPlace "$out/share/applications/cc-switch.desktop" \
      --replace-fail "Categories=" "Categories=Development;"
    install -Dm444 "${appimageContents}/usr/share/icons/hicolor/32x32/apps/cc-switch.png" \
      "$out/share/icons/hicolor/32x32/apps/cc-switch.png"
    install -Dm444 "${appimageContents}/usr/share/icons/hicolor/128x128/apps/cc-switch.png" \
      "$out/share/icons/hicolor/128x128/apps/cc-switch.png"
    install -Dm444 "${appimageContents}/usr/share/icons/hicolor/256x256@2/apps/cc-switch.png" \
      "$out/share/icons/hicolor/256x256@2/apps/cc-switch.png"
  '';

  meta = {
    description = "All-in-One Assistant for Claude Code, Codex and Gemini CLI";
    homepage = "https://github.com/farion1231/cc-switch";
    license = lib.licenses.mit;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
