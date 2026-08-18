# Project Sekai 鼠标指针主题。软件包本体定义在 pkgs/pjsk-cursor-theme.nix。
# 安装后在 系统设置 → 颜色与主题 → 光标 中选择 “PJSK ...” 主题并应用。
{ pkgs, ... }:

{
  environment.systemPackages = [ (pkgs.callPackage ../pkgs/pjsk-cursor-theme.nix { }) ];
}
