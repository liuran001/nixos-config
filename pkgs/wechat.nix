# 给官方微信 Linux 版补上中文输入法。微信有两套渲染进程，输入法通道不同，
# 因此这里要同时补 Qt 和 GTK 两条路。
#
# 一、主窗口：静态链接 Qt 5 的 CEF 应用（二进制里有
#    QPlatformInputContextFactoryInterface.5.1 和构建路径
#    third_party/fcitx-qt5/qt5/platforminputcontext/），已把 fcitx5-qt 的
#    QFcitxPlatformInputContext 编译进去，运行时通过 DBus 的 org.fcitx.Fcitx5
#    与 fcitx5 通信，不需要额外插件文件，只需要 QT_IM_MODULE 把它选中。
#
# 二、小程序与内置浏览器：独立的 Chromium 进程 RadiumWMPF/WeChatAppEx，
#    走 GTK 输入法通道。它只实现了 zwp_text_input_v1，而 KWin 只提供 v2/v3，
#    所以拿不到 Wayland 原生输入法，必须走 GTK immodule。
#    AppImage 的 FHS 环境里没有 fcitx5 的 immodule，而 GTK 3 只认
#    immodules.cache，因此这里在构建期用 gtk-query-immodules-3.0 生成一份
#    只含 fcitx5 的缓存，再用 GTK_IM_MODULE_FILE 指给微信。
#    bwrap 会绑定整个 /nix，因此 store 路径在沙箱内可直接访问；
#    fcitx5-gtk 与 FHS 环境里的 GTK 3 来自同一份 nixpkgs，ABI 一致。
#
# modules/i18n.nix 使用 Wayland 原生输入法前端，有意不设置全局 QT_IM_MODULE
# 和 GTK_IM_MODULE（避免干扰原生 Wayland 程序），所以这些变量只在这里、
# 只对微信生效。用 --set-default 便于临时改成 ibus 等值排查
# （fcitx5 同时提供 org.freedesktop.IBus 名称）。
{
  fcitx5-gtk,
  gtk3,
  lib,
  makeWrapper,
  runCommand,
  symlinkJoin,
  wechat,
}:

let
  # 生成只含 fcitx5 的 GTK 3 immodules 缓存；该模块同时注册 fcitx 与 fcitx5 两个 id。
  gtk3ImmodulesCache = runCommand "fcitx5-gtk3-immodules.cache" { nativeBuildInputs = [ gtk3 ]; } ''
    gtk-query-immodules-3.0 \
      ${fcitx5-gtk}/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so > "$out"
  '';
in
symlinkJoin {
  name = "wechat-fcitx-${wechat.version}";
  paths = [ wechat ];
  nativeBuildInputs = [ makeWrapper ];

  # .desktop 里是 Exec=wechat，按 PATH 解析，因此会命中下面这个包装器。
  # 同时修正菜单分类：上游只写了 Categories=Utility，微信会落在「实用工具」下；
  # KDE 的「互联网」菜单对应 Network 类别。symlinkJoin 把 share 下的文件做成软链，
  # 因此先摘掉软链再写入改过的副本。
  postBuild = ''
    rm "$out/share/applications/wechat.desktop"
    install -Dm444 \
      ${wechat}/share/applications/wechat.desktop \
      "$out/share/applications/wechat.desktop"
    substituteInPlace "$out/share/applications/wechat.desktop" \
      --replace-fail "Categories=Utility;" "Categories=Network;InstantMessaging;"

    rm "$out/bin/wechat"
    makeWrapper ${lib.getExe wechat} "$out/bin/wechat" \
      --set-default QT_IM_MODULE fcitx \
      --set-default GTK_IM_MODULE fcitx \
      --set-default GTK_IM_MODULE_FILE ${gtk3ImmodulesCache} \
      --prefix GTK_PATH : ${fcitx5-gtk}/lib/gtk-3.0 \
      --prefix GTK_PATH : ${fcitx5-gtk}/lib/gtk-4.0
  '';

  inherit (wechat) meta;
}
