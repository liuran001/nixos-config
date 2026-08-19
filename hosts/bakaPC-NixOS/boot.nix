# 引导加载器和内核配置。
{ pkgs, ... }:

{
  # 使用 GRUB 管理 UEFI 启动菜单，并通过 os-prober 自动探测其他硬盘上的 Windows 启动项。
  boot.loader.grub = {
    enable = true;
    # UEFI 模式安装，不写入硬盘 MBR。
    efiSupport = true;
    device = "nodev";
    # 扫描所有硬盘上的其他操作系统（如 Windows）并加入启动菜单。
    useOSProber = true;
    # 默认启动上次选择的系统（比如上次进了 Windows，这次还进 Windows）。
    default = "saved";
    # /boot 是 500 MiB 的 ESP，而每个代际的内核加 initrd 约 58 MiB。
    # 上限必须留出余量，否则内核升级时会在拷贝阶段撞上 ENOSPC。
    # 旧代际本身仍按 nix.gc 策略保留，只是不再出现在启动菜单里。
    configurationLimit = 5;
    # 高分屏下放大 GRUB 菜单字体。默认的 unicode.pf2 位图字体无法缩放，
    # 必须换成 TTF 字体，fontSize 才会生效。
    font = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf";
    fontSize = 36;
  };
  # 允许 NixOS 写入 UEFI 固件变量，以便创建和更新系统启动项。
  boot.loader.efi.canTouchEfiVariables = true;
  # 启动菜单等待 5 秒后自动进入默认项。
  boot.loader.timeout = 5;

  # 使用 linux-zen 内核：面向桌面响应速度调优（低延迟调度、1000 Hz 时钟、
  # 抢占模型等），并自带 binder/ashmem，Waydroid 可直接使用。
  # 如果遇到驱动兼容问题，可改回 pkgs.linuxPackages_latest。
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # /tmp 位于 Btrfs 根上，不会自动清空；每次启动清理构建残留。
  # 不用 tmpfs：Nix 会在 /tmp 里构建大包，占满内存比占磁盘更危险。
  boot.tmp.cleanOnBoot = true;
}
