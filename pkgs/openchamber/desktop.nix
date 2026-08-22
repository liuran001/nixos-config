{
  appimageTools,
  fetchurl,
  imagemagick,
  lib,
  makeWrapper,
}:

let
  pname = "openchamber-desktop";
  version = "1.19.0";

  src = fetchurl {
    url = "https://github.com/openchamber/openchamber/releases/download/v${version}/OpenChamber-1.19.0-linux-x86_64.AppImage";
    hash = "sha256-HrSI4Pd+0qxUXVc1o6CLC9LJlUbj4Nh4O4HVqgkOv4g=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [
    imagemagick
    makeWrapper
  ];

  extraInstallCommands = ''
    wrapProgram "$out/bin/${pname}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}"

    install -Dm444 "${appimageContents}/openchamber.desktop" \
      "$out/share/applications/openchamber.desktop"
    substituteInPlace "$out/share/applications/openchamber.desktop" \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=openchamber-desktop %U'
    install -Dm444 "${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/openchamber.png" \
      "$out/share/icons/hicolor/1024x1024/apps/openchamber.png"
    for size in 16 24 32 48 64 128 256 512; do
      mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
      magick \
        "${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/openchamber.png" \
        -resize "''${size}x''${size}" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/openchamber.png"
    done
  '';

  meta = {
    description = "Desktop GUI for OpenChamber";
    homepage = "https://github.com/openchamber/openchamber";
    license = lib.licenses.mit;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
