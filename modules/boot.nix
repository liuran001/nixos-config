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
    # 启动菜单等待 5 秒后自动进入默认项。
    timeout = 5;
    # 高分屏下放大 GRUB 菜单字体。默认的 unicode.pf2 位图字体无法缩放，
    # 必须换成 TTF 字体，fontSize 才会生效。
    font = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf";
    fontSize = 36;
  };
  # 允许 NixOS 写入 UEFI 固件变量，以便创建和更新系统启动项。
  boot.loader.efi.canTouchEfiVariables = true;

  # 使用当前 nixpkgs 提供的最新内核系列；如果以后遇到驱动兼容问题，可删除此行以使用默认稳定内核。
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
