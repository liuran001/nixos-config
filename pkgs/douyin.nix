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
  version = "8.3.0";

  src = fetchurl {
    url = "https://github.com/kota-rina3/hokeshi/releases/download/douyin${version}/com.douyin.otohime_${version}_amd64.deb";
    hash = "sha256-chAraILGu4G3cyYYV26kLxPKu0E1QSZnHjGfN5qkpAY=";
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

    # 修复上游 setWindowOpenHandler 的默认分支：它返回 action: 'deny'，却同时给出
    # overrideBrowserWindowOptions —— 后者只在 'allow' 时生效。结果所有没被前面特判
    # 的 window.open 都被静默拦掉，表现为「设置」等弹窗页面点了没反应。
    # 只改这一处：overrideBrowserWindowOptions 全文仅出现一次，其余 deny 分支
    # （bytedance:// 协议、外部浏览器跳转、主窗口内加载）保持原样。
    # 文件是 CRLF，且要跨行匹配，因此用 sed -z 而不是 substituteInPlace。
    dyMain=$(find "$out/lib/douyin" -name dy.js -maxdepth 2 | head -1)
    grep -qz "action: 'deny',\s*overrideBrowserWindowOptions:" "$dyMain"
    sed -i -z \
      "s/action: 'deny',\(\s*\)overrideBrowserWindowOptions:/action: 'allow',\1overrideBrowserWindowOptions:/" \
      "$dyMain"
    # 上游改版导致补丁失效时让构建直接失败，而不是静默退回坏行为。
    grep -qz "action: 'allow',\s*overrideBrowserWindowOptions:" "$dyMain"

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
