# Z.ai ZCode：固定官方 x86_64 AppImage，并在构建时解包以绕过运行时 FUSE。
{
  appimageTools,
  fetchurl,
  lib,
}:

let
  pname = "zcode";
  version = "3.8.1";

  src = fetchurl {
    url = "https://cdn-zcode.z.ai/zcode/electron/releases/3.8.1/linux-x64/ZCode-3.8.1-linux-x64.AppImage";
    hash = "sha256-tCDepQlht31cdbCLkk2kGrUpxyCn7DLqy+labYQxmeA=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # ZCode 每次启动都会按 APPIMAGE 重写用户级协议入口；使用稳定命令名，
  # 避免它把 FHS 环境里的裸 Electron store 路径写进 zcode.desktop。
  profile = ''
    export APPIMAGE=zcode
  '';

  extraInstallCommands = ''
    install -Dm444 "${appimageContents}/zcode.desktop" \
      "$out/share/applications/zcode.desktop"
    substituteInPlace "$out/share/applications/zcode.desktop" \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=zcode %U'

    for size in 16 24 32 48 64 128 256 512 1024; do
      install -Dm444 \
        "${appimageContents}/usr/share/icons/hicolor/''${size}x''${size}/apps/zcode.png" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/zcode.png"
    done
  '';

  meta = {
    description = "AI-powered coding environment from Z.ai";
    homepage = "https://z.ai/";
    downloadPage = "https://z.ai/";
    license = lib.licenses.unfree;
    mainProgram = "zcode";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
