# 第三方抖音 Linux 客户端，封装方式参考 AUR 的 douyin-bin。
# 这是第一阶段兼容性优先的 Electron 壳加固；这不是字节跳动官方发布的软件。
# 完整的 nodeIntegration/contextIsolation/sandbox 加固需要先将 dy-js.js 迁移到
# preload/contextBridge，因此本阶段有意保留当前注入式 IPC 所需的设置。
{
  dpkg,
  electron_42,
  fetchurl,
  lib,
  libnotify,
  makeWrapper,
  python3,
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
    python3
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

        # 第一阶段加固：保留注入式 IPC 所需的 nodeIntegration/contextIsolation 兼容性，
        # 但启用 webSecurity，并限制 worker/subframe 的 Node 暴露；完整隔离需迁移
        # dy-js.js 到 preload/contextBridge，故本阶段不启用 nodeIntegration=false、
        # contextIsolation=true 或 sandbox=true。
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

        # 仅允许 HTTPS 的 douyin.com 主域及其子域作为顶层导航/弹窗目标；保留
        # bytedance:// 拦截、显式外部浏览器跳转及帮助/用户页路由。
        python3 - "$dyMain" <<'PY'
    import pathlib
    import re
    import sys

    path = pathlib.Path(sys.argv[1])
    text = path.read_text()

    def replace_once(old, new, label):
        global text
        if text.count(old) != 1:
            raise SystemExit(f"expected exactly one {label}")
        text = text.replace(old, new)

    replace_once(
        "const { dyjs } = require('./dy-js.js')",
        """const { dyjs } = require('./dy-js.js')

    function isAllowedDouyinUrl(rawUrl) {
        try {
            const url = new URL(rawUrl)
            return url.protocol === 'https:' &&
                (url.hostname === 'douyin.com' || url.hostname.endsWith('.douyin.com'))
        } catch (_) {
            return false
        }
    }""",
        "Douyin URL helper",
    )

    if text.count('webSecurity: false') != 2:
        raise SystemExit('expected exactly two unsafe webSecurity settings')
    text = text.replace('webSecurity: false', 'webSecurity: true')

    text, preference_count = re.subn(
        r'contextIsolation: false,\n(?P<indent>\s*)webSecurity: true',
        lambda match: (
            'contextIsolation: false,\n'
            f"{match.group('indent')}nodeIntegrationInWorker: false,\n"
            f"{match.group('indent')}nodeIntegrationInSubFrames: false,\n"
            f"{match.group('indent')}webSecurity: true"
        ),
        text,
    )
    if preference_count != 2:
        raise SystemExit('expected exactly two compatibility preference blocks')
    if text.count('nodeIntegrationInWorker: false') != 2 or text.count('nodeIntegrationInSubFrames: false') != 2:
        raise SystemExit('failed to add Node scope restrictions to both windows')

    navigation_check = "if (url.startsWith('bytedance://')) {\n            event.preventDefault()\n        }"
    if text.count(navigation_check) != 2:
        raise SystemExit('expected exactly two navigation protocol checks')
    text = text.replace(
        navigation_check,
        "if (!isAllowedDouyinUrl(url) || url.startsWith('bytedance://')) {\n            event.preventDefault()\n        }",
    )
    replace_once(
        "        // 在主窗口加载的 URL",
        """        // 其余弹窗仅允许 HTTPS Douyin URL
            if (!isAllowedDouyinUrl(url)) {
                return { action: 'deny' };
            }

            // 在主窗口加载的 URL""",
        "popup URL check",
    )

    if 'const { ipcRenderer } = require(\'electron\')' not in path.with_name('dy-js.js').read_text():
        raise SystemExit('legacy renderer IPC bridge is missing')
    if text.count('webSecurity: true') != 2 or 'webSecurity: false' in text:
        raise SystemExit('webSecurity hardening assertion failed')
    if text.count('isAllowedDouyinUrl') != 4:
        raise SystemExit('URL helper is not used by both navigation events and popup handler')
    if re.search(r"action: 'allow',\s*overrideBrowserWindowOptions:", text) is None:
        raise SystemExit('allowed popup compatibility branch is missing')

    path.write_text(text)
    PY

        # 构建时断言保持 fail-closed：校验精确安全设置、路由检查、弹窗兼容分支，
        # 以及尚未迁移的 renderer require('electron') bridge。
        grep -qz 'webSecurity: true' "$dyMain"
        ! grep -qz 'webSecurity: false' "$dyMain"
        grep -qz 'function isAllowedDouyinUrl(rawUrl)' "$dyMain"
        grep -qz 'nodeIntegrationInWorker: false' "$dyMain"
        grep -qz 'nodeIntegrationInSubFrames: false' "$dyMain"
        grep -qz 'isAllowedDouyinUrl(url)' "$dyMain"
        grep -qz "action: 'allow',\s*overrideBrowserWindowOptions:" "$dyMain"
        grep -qz "const { ipcRenderer } = require('electron')" "$out/lib/douyin/dy-js.js"

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
