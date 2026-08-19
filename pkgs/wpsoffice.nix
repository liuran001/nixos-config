# 给 WPS Office 国内版补上中文输入法。
#
# WPS 自带一整套改名的 Qt 5.12.12（office6/libQt5*Kso.so），不走系统 Qt，
# 因此 nixpkgs 的 fcitx5-qt 插件既装不进去也加载不了（Qt 版本与符号都对不上）。
# 好在上游 deb 里已经带了自己的输入法插件
# office6/qt/plugins/platforminputcontexts/libfcitxplatforminputcontextplugin.so，
# 它链接的是 WPS 自己的 libQt5DBusKso，只差 QT_IM_MODULE 把它选中。
#
# 该插件用的是 fcitx4 的 DBus 协议，连接 org.fcitx.Fcitx-<显示编号>；
# fcitx5 的 dbusfrontend 会同时注册 org.fcitx.Fcitx-0，因此可以直接对接，
# 不需要额外装 fcitx5 的兼容层。
#
# modules/i18n.nix 使用 Wayland 原生输入法前端，有意不设置全局 QT_IM_MODULE
# （避免干扰原生 Wayland 程序），而 WPS 是 XWayland 上的 X11 程序，拿不到
# Wayland 原生输入法，所以这个变量只在这里、只对 WPS 生效。
# 用 --set-default 便于临时改成 ibus 等值排查（fcitx5 同时提供
# org.freedesktop.IBus 名称）。
{
  makeWrapper,
  symlinkJoin,
  wpsoffice-cn,
}:

symlinkJoin {
  name = "wpsoffice-cn-fcitx-${wpsoffice-cn.version}";
  paths = [ wpsoffice-cn ];
  nativeBuildInputs = [ makeWrapper ];

  # wps（文字）、wpp（演示）、et（表格）、wpspdf（PDF）四个入口都要包装：
  # .desktop 里写的是 Exec=wps/wpp/et 这类裸命令，按 PATH 解析后命中这里。
  # symlinkJoin 把 bin 下的文件做成软链，因此先摘掉软链再写入包装器。
  postBuild = ''
    for entry in wps wpp et wpspdf; do
      rm "$out/bin/$entry"
      makeWrapper "${wpsoffice-cn}/bin/$entry" "$out/bin/$entry" \
        --set-default QT_IM_MODULE fcitx
    done

    for desktopFile in "$out"/share/applications/*.desktop; do
      sourceFile=$(readlink -f "$desktopFile")
      rm "$desktopFile"
      install -Dm444 "$sourceFile" "$desktopFile"
      sed -i \
        's/^Categories=.*/Categories=Office;WordProcessor;Spreadsheet;Presentation;/' \
        "$desktopFile"
    done
  '';

  inherit (wpsoffice-cn) meta;
}
