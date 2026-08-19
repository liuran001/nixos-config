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

  # 默认的 swappiness=60 是按机械盘/SSD swap 调的。zram 换页走内存加压缩，
  # 比读盘快一个数量级，应当更积极地把冷页压进去而不是回收页缓存。
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    # zram 是随机访问设备，预读连续页只会浪费解压开销。
    "vm.page-cluster" = 0;
  };

  # 系统本身由 NixOS 代际回滚保护，/home 之前没有任何回滚手段。
  # /home 已是独立子卷，snapper 会在 /home/.snapshots 下按时间线保留快照。
  # 快照是写时复制，只占增量空间，但它同盘存放，不能代替异地备份。
  services.snapper.configs.home = {
    SUBVOLUME = "/home";
    ALLOW_USERS = [ "baka" ];
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = 6;
    TIMELINE_LIMIT_DAILY = 7;
    TIMELINE_LIMIT_WEEKLY = 4;
    TIMELINE_LIMIT_MONTHLY = 2;
    TIMELINE_LIMIT_QUARTERLY = 0;
    TIMELINE_LIMIT_YEARLY = 0;
  };
}
