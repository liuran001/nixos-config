# niri 滚动平铺式 Wayland 合成器及配套组件。
# 安装后 SDDM 登录界面的会话菜单会多出 “niri” 选项，KDE Plasma 会话不受影响。
# programs.niri 模块已自动配置好 portal、gnome-keyring、polkit、swaylock 的 PAM；
# fcitx5、polkit-gnome 认证弹窗、nm-applet、blueman 托盘在 niri 会话里经 XDG autostart 自动启动。
{ pkgs, ... }:

{
  programs.niri.enable = true;

  # niri / waybar / mako 等用户级配置由 home-manager 管理，见 modules/home.nix。

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
