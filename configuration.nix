# NixOS 系统配置入口。具体配置按功能拆分在 modules/ 目录下：
#   boot.nix         引导加载器和内核
#   networking.nix   主机名、网络、防火墙
#   i18n.nix         时区、语言环境、Fcitx 5 输入法
#   desktop.nix      KDE Plasma 桌面、音频、打印
#   nvidia.nix       NVIDIA 显卡驱动
#   users.nix        用户账户和 sudo 权限
#   fonts.nix        系统字体（中西文常用字体、Emoji）
#   home.nix         home-manager：用户级配置（~/.config 点文件）
#   niri.nix         niri 滚动平铺式 Wayland 合成器及配套组件
#   packages.nix     系统软件包（装软件改这里）
#   nix-settings.nix Nix 镜像源、flakes、stateVersion
# 修改并保存后，运行 `git add -A && git commit`，再运行
# `nixos-rebuild switch --flake /etc/nixos --sudo`（或直接敲别名 nrs）构建并启用新配置。
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
    ./modules/home.nix
    ./modules/niri.nix
    ./modules/packages.nix
    ./modules/nix-settings.nix
  ];

  # hardware-configuration.nix 负责描述检测到的设备和分区；这里单独维护人为选择的挂载策略。
  # Btrfs 透明压缩只影响新写入或之后被改写的数据，不会自动重压缩已有数据。
  fileSystems = {
    "/".options = [ "compress=zstd" ];
    "/home".options = [ "compress=zstd" ];
    # Nix store 不依赖访问时间；noatime 可减少大量读取导致的元数据写入。
    "/nix".options = [
      "compress=zstd"
      "noatime"
    ];
  };

  # 每月校验一次 Btrfs 数据与元数据。三个子卷共用同一文件系统，模块会按设备去重。
  # 单盘 scrub 可以发现校验错误，但不能代替备份，也不能自动修复无冗余的数据。
  services.btrfs.autoScrub.enable = true;

  # 提供约 6.4 GiB 的压缩内存交换区作为 OOM 缓冲；容量按需使用，不会预占 10% 内存。
  # zram 不能用于休眠；本机原本也没有磁盘 swap/休眠配置。
  zramSwap = {
    enable = true;
    memoryPercent = 10;
  };
}
