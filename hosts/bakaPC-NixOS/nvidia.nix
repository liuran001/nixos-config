# NVIDIA 显卡驱动（RTX 5060 Laptop，Blackwell 架构）。
# 本机是 Intel 核显 + NVIDIA 独显的混合显卡笔记本。
# 默认由 Intel 核显渲染桌面以省电；需要独显的程序用 nvidia-offload 命令启动，例如：
#   nvidia-offload steam
{ config, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # 启用内核 modesetting，Wayland 和屏幕缩放需要它。
    modesetting.enable = true;
    # 笔记本电源管理，修复挂起/唤醒后独显异常的问题。
    powerManagement.enable = true;
    # Blackwell（RTX 50 系）只支持开源内核模块，必须开启。
    open = true;
    # 安装 nvidia-settings 图形设置面板。
    nvidiaSettings = true;
    # Blackwell 配合最新内核优先使用 nixpkgs 当前的新驱动分支；
    # 具体版本仍由 flake.lock 固定，更新失败时可以回退上一代系统。
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    # 混合显卡 PRIME 卸载模式。
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # 提供 nvidia-offload 命令
      };
      # 两个显卡的 PCI 总线地址，来自 lspci（00:02.0 和 02:00.0）。
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:2:0:0";
    };
  };
}
