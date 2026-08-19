# niri 滚动平铺式 Wayland 合成器及配套组件。
# 安装后 SDDM 登录界面的会话菜单会多出 “niri” 选项，KDE Plasma 会话不受影响。
# programs.niri 模块已自动配置好 portal、gnome-keyring、polkit、swaylock 的 PAM；
# fcitx5、nm-applet、blueman 托盘经 XDG autostart 启动，polkit-gnome 由 config.kdl 显式启动。
{ pkgs, ... }:

let
  # 只保留二进制、man 手册和 zsh 补全的 mako。
  # mako 包自带的 share/dbus-1/services/fr.emersion.mako.service 与 Plasma 的
  # 通知服务声明同一个 org.freedesktop.Notifications 总线名，而 dbus-broker
  # 按文件名顺序选择激活方（fr.emersion 排在 org.kde 之前），导致 KDE 会话里
  # 通知被 mako 接管；包里的 systemd 用户单元也只为 D-Bus 激活服务。
  # niri 中 mako 由 config.kdl 的 spawn-at-startup 显式启动，不依赖这些文件；
  # 剥离后 KDE 回落到 org.kde.plasma.Notifications.service。
  # 注意不要用 symlinkJoin+rm：它会把子目录做成符号链接，buildEnv 合并时报
  # "not a directory"。
  makoNiri = pkgs.runCommand "mako-nodbus" { } ''
    mkdir -p $out/bin $out/share
    ln -s ${pkgs.mako}/bin/* $out/bin/
    ln -s ${pkgs.mako}/share/man $out/share/man
    ln -s ${pkgs.mako}/share/zsh $out/share/zsh
  '';
in
{
  programs.niri.enable = true;

  # niri / waybar / mako 等用户级配置由 Home Manager 管理，见 home/baka/。

  environment.systemPackages = with pkgs; [
    xwayland-satellite # niri 不内置 Xwayland，X11 程序靠它运行（config.kdl 中自启）
    alacritty # 终端，默认快捷键 Mod+T
    fuzzel # 应用启动器，默认快捷键 Mod+D
    waybar # 状态栏（自启）
    makoNiri # 通知守护进程（由 niri config.kdl 自启；见上方 let 注释）
    swaylock # 锁屏，Super+Alt+L
    swayidle # 空闲管理：5 分钟锁屏，10 分钟关屏（自启）
    wlsunset # 夜间色温（自启，按上海经纬度）
    brightnessctl # 屏幕亮度快捷键
    playerctl # 媒体播放快捷键
    wl-clipboard # Wayland 剪贴板命令行工具
    pavucontrol # 图形化音量面板（waybar 音量图标点击打开）
    networkmanagerapplet # 网络托盘图标与连接编辑器
    polkit_gnome # 提权认证弹窗（由 config.kdl 启动）
  ];
}
