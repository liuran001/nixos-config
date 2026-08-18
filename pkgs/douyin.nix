# 第三方抖音 Linux 客户端，封装方式参考 AUR 的 douyin-bin。
# 上游 Electron 壳会以 nodeIntegration=true、contextIsolation=false 和
# webSecurity=false 加载 douyin.com；这不是字节跳动官方发布的软件。
{
  dpkg,
  electron_42,
  fetchurl,
  lib,
  libnotify,
  makeWrapper,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "douyin";
  version = "8.1.201";

  src = fetchurl {
    url = "https://github.com/kota-rina3/hokeshi/releases/download/douyin${version}/com.douyin.otohime_${version}_amd64.deb";
    hash = "sha256-ms8sSAUmlfccU0G+tBDbYTsAK/VtzP8haNrzIoInyVM=";
  };

  nativeBuildInputs = [
    dpkg
    makeWrapper
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --extract "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    packageRoot=opt/apps/com.douyin.otohime
    install -d "$out/lib/douyin" "$out/share/applications"
    cp -r "$packageRoot/files/resources/app/." "$out/lib/douyin/"

    # 修正托盘菜单中上游硬编码的 /opt 自启动路径。
    substituteInPlace "$out/lib/douyin/dy-tray.js" \
      --replace-fail "/opt/apps/com.douyin.otohime/files/douyin" "$out/bin/douyin"

    makeWrapper ${lib.getExe electron_42} "$out/bin/douyin" \
      --add-flags "$out/lib/douyin" \
      --prefix PATH : ${lib.makeBinPath [ libnotify ]}

    install -Dm444 \
      "$packageRoot/entries/applications/douyin.desktop" \
      "$out/share/applications/douyin.desktop"
    substituteInPlace "$out/share/applications/douyin.desktop" \
      --replace-fail "Categories=Video;" "Categories=AudioVideo;Video;" \
      --replace-fail "Exec=/opt/apps/com.douyin.otohime/files/douyin" "Exec=douyin" \
      --replace-fail "Icon=/opt/apps/com.douyin.otohime/files/resources/app/douyin.png" "Icon=douyin"
    sed -i -e '/^Encoding=/d' -e '/^MimeType=$/d' \
      "$out/share/applications/douyin.desktop"

    cp -r "$packageRoot/entries/icons/." "$out/share/icons/"
    install -Dm444 "$packageRoot/files/LICENSE" \
      "$out/share/licenses/douyin/LICENSE"

    runHook postInstall
  '';

  meta = {
    description = "Unofficial third-party Linux client for Douyin";
    homepage = "https://github.com/kota-rina3/hokeshi";
    license = lib.licenses.unfree;
    mainProgram = "douyin";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
