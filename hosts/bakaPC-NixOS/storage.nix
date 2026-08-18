# 本机存储策略：Btrfs 挂载选项、定期校验与压缩内存交换区。
{ ... }:

{
  # hardware-configuration.nix 只描述检测到的设备和分区；人为挂载策略在这里维护。
  # 透明压缩只影响新写入或之后被改写的数据，不会自动重压缩已有数据。
  fileSystems = {
    "/".options = [ "compress=zstd" ];
    "/home".options = [ "compress=zstd" ];
    # Nix store 不依赖访问时间；noatime 可减少大量读取导致的元数据写入。
    "/nix".options = [
      "compress=zstd"
      "noatime"
    ];
  };

  # 三个子卷共用同一文件系统，模块会按设备去重。单盘 scrub 能发现错误，但不能代替备份。
  services.btrfs.autoScrub.enable = true;

  # 约 6.4 GiB 的按需 zram OOM 缓冲；它不预占 10% 内存，也不能用于休眠。
  zramSwap = {
    enable = true;
    memoryPercent = 10;
  };
}
