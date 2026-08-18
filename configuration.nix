# NixOS 系统配置入口。具体配置按功能拆分在 modules/ 目录下：
#   boot.nix         引导加载器和内核
#   networking.nix   主机名、网络、防火墙
#   i18n.nix         时区、语言环境、Fcitx 5 输入法
#   desktop.nix      KDE Plasma 桌面、音频、打印
#   nvidia.nix       NVIDIA 显卡驱动
#   users.nix        用户账户和 sudo 权限
#   fonts.nix        系统字体（中西文常用字体、Emoji）
#   pjsk-cursors.nix Project Sekai 鼠标指针主题
#   packages.nix     系统软件包（装软件改这里）
#   nix-settings.nix Nix 镜像源、flakes、stateVersion
# 修改并保存后，运行 `git add -A && git commit`，再运行
# `sudo nixos-rebuild switch --flake /etc/nixos` 构建并启用新配置。
# 注意：新增的配置文件必须先 git add，否则 nixos-rebuild 看不到它。
{ ... }:

{
  imports = [
    # 安装系统时自动生成的硬件配置，包含磁盘、文件系统和启动所需的内核模块等信息。
    # 一般不要手动修改 hardware-configuration.nix，以免影响系统启动或磁盘挂载。
    ./hardware-configuration.nix

    ./modules/boot.nix
    ./modules/networking.nix
    ./modules/i18n.nix
    ./modules/desktop.nix
    ./modules/nvidia.nix
    ./modules/users.nix
    ./modules/fonts.nix
    ./modules/pjsk-cursors.nix
    ./modules/packages.nix
    ./modules/nix-settings.nix
  ];
}
