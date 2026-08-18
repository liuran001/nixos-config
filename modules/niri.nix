# niri 滚动平铺式 Wayland 合成器及配套组件。
# 安装后 SDDM 登录界面的会话菜单会多出 “niri” 选项，KDE Plasma 会话不受影响。
# programs.niri 模块已自动配置好 portal、gnome-keyring、polkit、swaylock 的 PAM；
# fcitx5、polkit-gnome 认证弹窗、nm-applet、blueman 托盘在 niri 会话里经 XDG autostart 自动启动。
{ pkgs, ... }:

{
  programs.niri.enable = true;

  # 用户级配置文件集中存放在 modules/niri/ 目录下，通过软链接部署到 ~/.config/。
  # 链接目标在 nix store 中是只读的：要改配置请编辑本 repo 中的文件并重新构建系统，
  # niri 会热重载新配置，无需重新登录。
  systemd.tmpfiles.rules = [
    "d /home/baka/.config/niri 0755 baka users - -"
    "L+ /home/baka/.config/niri/config.kdl - - - - ${./niri/config.kdl}"
    "d /home/baka/.config/waybar 0755 baka users - -"
    "L+ /home/baka/.config/waybar/config.jsonc - - - - ${./niri/waybar-config.jsonc}"
    "L+ /home/baka/.config/waybar/style.css - - - - ${./niri/waybar-style.css}"
    "d /home/baka/.config/mako 0755 baka users - -"
    "L+ /home/baka/.config/mako/config - - - - ${./niri/mako-config}"
    "d /home/baka/.config/fuzzel 0755 baka users - -"
    "L+ /home/baka/.config/fuzzel/fuzzel.ini - - - - ${./niri/fuzzel.ini}"
    "d /home/baka/.config/swaylock 0755 baka users - -"
    "L+ /home/baka/.config/swaylock/config - - - - ${./niri/swaylock.conf}"
  ];

  environment.systemPackages = with pkgs; [
    xwayland-satellite # niri 不内置 Xwayland，X11 程序靠它运行（config.kdl 中自启）
    alacritty # 终端，默认快捷键 Mod+T
    fuzzel # 应用启动器，默认快捷键 Mod+D
    waybar # 状态栏（自启）
    mako # 通知守护进程（自启）
    swaylock # 锁屏，Super+Alt+L
    swayidle # 空闲管理：5 分钟锁屏，10 分钟关屏（自启）
    swaybg # 壁纸（自启，当前为纯色背景）
    wlsunset # 夜间色温（自启，按上海经纬度）
    brightnessctl # 屏幕亮度快捷键
    playerctl # 媒体播放快捷键
    wl-clipboard # Wayland 剪贴板命令行工具
    pavucontrol # 图形化音量面板（waybar 音量图标点击打开）
    networkmanagerapplet # 网络托盘图标与连接编辑器
    blueman # 蓝牙托盘与管理器
    polkit_gnome # 提权认证弹窗（niri 会话自动启动）
  ];
}
