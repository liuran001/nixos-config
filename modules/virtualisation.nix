# 本机容器运行时。
{
  virtualisation.docker = {
    enable = true;
    # 桌面开发机使用 socket activation，首次执行 docker 命令时再启动 daemon。
    enableOnBoot = false;
    # 显式固定驱动，避免 Docker 升级后根据环境改变存储实现。
    storageDriver = "overlay2";
  };
}
