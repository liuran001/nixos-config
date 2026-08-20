# 本机核显（Core Ultra 9 275HX 的 Xe 核显）的视频加速栈。
# 桌面默认由核显渲染，独显只在 nvidia-offload 时介入，因此浏览器、
# 播放器的硬件解码全部依赖这里的 VA-API 驱动。缺少它们时只能软解，
# 会明显推高 CPU 占用、发热和耗电。
{ pkgs, ... }:

{
  # hardware.graphics.enable 已由 Plasma 与 NVIDIA 模块开启；
  # 这里只补核显自己的驱动，列表会与 NVIDIA 模块提供的条目合并。
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver # iHD：Broadwell 以后的 VA-API 解码与编码
    vpl-gpu-rt # oneVPL 运行时，供 Quick Sync 编码使用
  ];

  # vainfo 是诊断工具，不是 VA-API 驱动；安装到 PATH 方便确认 profile 是否真的可用。
  environment.systemPackages = with pkgs; [
    libva-utils
  ];

  # 32 位程序（Steam 内的旧游戏、Wine）也走核显解码。
  hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [
    intel-media-driver
  ];

  # 明确让 libva 选择 iHD 后端；混合显卡下自动探测可能先命中 NVIDIA 的后端。
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
}
