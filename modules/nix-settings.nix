# Nix 包管理器自身的设置和系统状态版本。
{ ... }:

{
  # 使用 CERNET 的 Nix 二进制缓存镜像下载已经构建好的软件包，以改善中国大陆的下载速度。
  # 这只改变下载来源，不会改变 nixpkgs 软件源的版本或系统配置内容。
  nix.settings.substituters = [
    "https://mirrors.cernet.edu.cn/nix-channels/store"
  ];

  # 启用 nix-command 和 flakes 实验特性，以支持 flake.nix 管理配置。
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # 每周自动清理 30 天前的旧系统代际和不再被引用的 store 路径，避免 store 随重建无限膨胀。
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  # 通过硬链接去重 store 中的相同文件，节省磁盘空间。
  nix.settings.auto-optimise-store = true;

  # stateVersion 是有状态数据格式的兼容基线，例如部分服务的数据目录和数据库版本。
  # 它不是当前安装的 NixOS 版本；正常升级系统时也不要随版本号一起修改。
  # 通常应永久保留首次安装系统时的值。随意提高它可能触发不可逆的数据迁移。
  # 修改前务必阅读 `man configuration.nix` 中 system.stateVersion 的说明。
  system.stateVersion = "26.05"; # 本机首次安装时使用的 NixOS 版本。
}
