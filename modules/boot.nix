# 引导加载器和内核配置。
{ pkgs, ... }:

{
  # 使用 systemd-boot 管理 UEFI 启动菜单。
  boot.loader.systemd-boot.enable = true;
  # 允许 NixOS 写入 UEFI 固件变量，以便创建和更新系统启动项。
  boot.loader.efi.canTouchEfiVariables = true;

  # 使用当前 nixpkgs 提供的最新内核系列；如果以后遇到驱动兼容问题，可删除此行以使用默认稳定内核。
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
