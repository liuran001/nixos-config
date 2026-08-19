# ksystemlog 从 Plasma 菜单点击毫无反应，但终端里直接运行完全正常。
#
# 原因在上游 .desktop 的 X-KDE-SubstituteUID=true：Plasma 6 通过 systemd 把应用
# 拉起为 app-org.kde.ksystemlog@*.service，看到该字段后会把 ExecStart 换成 kdesu
# 去提权。NixOS 没有 kdesu 可执行文件，于是 unit 直接以 203/EXEC 失败，
# 而桌面上不会有任何提示：
#   app-org.kde.ksystemlog@….service: Unable to locate executable 'kdesu'
#   Failed at step EXEC spawning kdesu: No such file or directory
# 终端启动不经过这条提权路径，所以只有菜单点击失效。
#
# 补 kdesu 并不能解决问题：kdesu 是 su 的前端，而本机 root 没有设置密码。
# 这里改为以当前用户运行——baka 属于 wheel，systemd-journald 的 ACL 已授予该组
# 读权限（journalctl 可直接读系统日志），查看日志不需要 root。
{
  kdePackages,
  symlinkJoin,
}:

symlinkJoin {
  name = "ksystemlog-${kdePackages.ksystemlog.version}";
  paths = [ kdePackages.ksystemlog ];

  # symlinkJoin 把 share 下的文件做成软链，因此先摘掉软链再写入改过的副本。
  postBuild = ''
    rm "$out/share/applications/org.kde.ksystemlog.desktop"
    install -Dm444 \
      ${kdePackages.ksystemlog}/share/applications/org.kde.ksystemlog.desktop \
      "$out/share/applications/org.kde.ksystemlog.desktop"
    substituteInPlace "$out/share/applications/org.kde.ksystemlog.desktop" \
      --replace-fail 'X-KDE-SubstituteUID=true' 'X-KDE-SubstituteUID=false'
  '';

  inherit (kdePackages.ksystemlog) meta;
}
