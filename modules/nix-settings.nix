# Nix 包管理器自身的设置和系统状态版本。
{ ... }:

{
  # 使用 CERNET 的 Nix 二进制缓存镜像下载已经构建好的软件包，以改善中国大陆的下载速度。
  # 这只改变下载来源，不会改变 nixpkgs 软件源的版本或系统配置内容。
  nix.settings.substituters = [
    "https://mirrors.cernet.edu.cn/nix-channels/store"
  ];

  # 启用 nix-command 和 flakes 实验特性，以支持 flake.nix 管理配置。
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # 每周自动清理 30 天前的旧系统代际和不再被引用的 store 路径，避免 store 随重建无限膨胀。
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  # 通过硬链接去重 store 中的相同文件，节省磁盘空间。
  # 用定时任务而不是 auto-optimise-store：后者会给每一次构建都加一遍
  # 全量去重开销，而这里每周集中做一次，效果相同且不拖慢日常重建。
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };
}
