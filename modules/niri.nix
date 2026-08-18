# niri 滚动平铺式 Wayland 合成器。
# 安装后 SDDM 登录界面的会话菜单会多出 “niri” 选项，KDE Plasma 会话不受影响。
# niri 的模块已自动配置好 portal、gnome-keyring 等；本机桌面由 Intel 核显渲染，开箱即用。
{ pkgs, ... }:

{
  programs.niri.enable = true;

  environment.systemPackages = with pkgs; [
    # niri 不内置 Xwayland，X11 程序需要它在后台运行。
    # 首次进入 niri 后，把下行加入 ~/.config/niri/config.kdl 让它自动启动：
    #   spawn-at-startup "xwayland-satellite"
    xwayland-satellite
    # niri 默认快捷键 Mod+T 启动 alacritty 终端，装上保证默认配置开箱可用。
    alacritty
  ];
}
