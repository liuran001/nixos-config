# Lark 海外版：封装官方 Linux 安装包，并让依赖和更新继续由 NixOS 管理。
{
  addDriverRunpath,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  autoPatchelfHook,
  cairo,
  cups,
  dbus,
  dpkg,
  expat,
  fetchurl,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  glibc,
  gnutls,
  gtk3,
  jq,
  lib,
  libGL,
  libappindicator,
  libcxx,
  libdbusmenu,
  libdrm,
  libgcrypt,
  libgbm,
  libglvnd,
  libnotify,
  libpulseaudio,
  libuuid,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxkbfile,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,
  makeShellWrapper,
  nspr,
  nss,
  pango,
  pciutils,
  pipewire,
  pixman,
  stdenv,
  systemd,
  wayland,
  xdg-utils,
}:

let
  runtimeLibraryPath = lib.makeLibraryPath [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    glibc
    gnutls
    gtk3
    libGL
    libappindicator
    libcxx
    libdbusmenu
    libdrm
    libgcrypt
    libgbm
    libglvnd
    libnotify
    libpulseaudio
    libuuid
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxkbfile
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
    nspr
    nss
    pango
    pciutils
    pipewire
    pixman
    stdenv.cc.cc
    systemd
    wayland
    xdg-utils
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "lark";
  version = "7.72.23";

  src = fetchurl {
    # 去掉官方临时签名参数后的永久 CDN 地址。
    url = "https://sf16-sg.larksuitecdn.com/obj/lark-version-sg/b69ee051/Lark-linux_x64-${finalAttrs.version}.deb";
    hash = "sha256-cSKhFlj8DqkTkrMkEYNzP4jRrG6ruyO+LLV24MhNrI8=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    jq
    makeShellWrapper
  ];

  buildInputs = [
    alsa-lib
    cups
    gtk3
    libdrm
    libgbm
    libgcrypt
    libpulseaudio
    libxdamage
    libxshmfence
    libxtst
    nspr
    nss
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    # 安装包包含发行版专用路径；只保留应用本体、桌面入口和图标数据。
    dpkg --fsys-tarfile "$src" | tar --extract
    mkdir -p "$out"
    mv opt "$out/"
    mv usr/share "$out/"

    appRoot="$out/opt/bytedance/lark"
    desktopFile="$out/share/applications/bytedance-lark.desktop"

    # Lark 的应用内升级不能修改只读 Nix store；明确关闭升级入口，统一通过本包更新。
    jq \
      '.inhouse_update_config_v2.feishu.update_enable = 0
       | .inhouse_update_config_v2.lark.update_enable = 0' \
      "$appRoot/lark_settings" > "$appRoot/lark_settings.tmp"
    mv "$appRoot/lark_settings.tmp" "$appRoot/lark_settings"

    substituteInPlace "$desktopFile" \
      --replace-fail "/usr/bin/bytedance-lark-stable" "$out/bin/bytedance-lark"

    # 主进程会继续拉起会议、文档等子进程，因此把完整运行库路径放进主进程包装器。
    wrapProgram "$appRoot/lark" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --prefix XDG_DATA_DIRS : "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH" \
      --prefix LD_LIBRARY_PATH : "${runtimeLibraryPath}:$appRoot:${addDriverRunpath.driverLink}/share"

    mkdir -p "$out/bin" "$out/share/icons/hicolor"
    ln -s "$appRoot/bytedance-lark" "$out/bin/bytedance-lark"
    for size in 16 24 32 48 64 128 256; do
      iconDir="$out/share/icons/hicolor/''${size}x''${size}/apps"
      mkdir -p "$iconDir"
      ln -s "$appRoot/product_logo_''${size}.png" "$iconDir/bytedance-lark.png"
    done

    runHook postInstall
  '';

  meta = {
    description = "All-in-one collaboration suite for international teams";
    homepage = "https://www.larksuite.com/";
    downloadPage = "https://www.larksuite.com/download";
    license = lib.licenses.unfree;
    mainProgram = "bytedance-lark";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
