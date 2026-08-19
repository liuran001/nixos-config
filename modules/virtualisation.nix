# Docker 与 Waydroid 容器运行时。
{ config, pkgs, ... }:

let
  waydroidPackage = config.virtualisation.waydroid.package;
  waydroidGappsInit = pkgs.writeShellScript "waydroid-gapps-init" ''
    set -eu

    stateDir=/var/lib/waydroid
    # waydroid.cfg 和镜像会在初始化中途就出现；同时检查最后阶段生成的
    # LXC 配置和基础属性，避免把一次中断的初始化误判为成功。
    if [ -s "$stateDir/waydroid.cfg" ] \
      && [ -s "$stateDir/images/system.img" ] \
      && [ -s "$stateDir/images/vendor.img" ] \
      && [ -s "$stateDir/lxc/waydroid/config" ] \
      && [ -s "$stateDir/waydroid_base.prop" ] \
      && [ -d "$stateDir/rootfs" ]; then
      echo "Waydroid is already initialized; preserving the existing images and data."
      exit 0
    fi

    echo "Initializing Waydroid with the GAPPS image."
    ${waydroidPackage}/bin/waydroid init -s GAPPS
  '';
in
{
  virtualisation.docker = {
    enable = true;
    # 桌面开发机使用 socket activation，首次执行 docker 命令时再启动 daemon。
    enableOnBoot = false;
    # 显式固定驱动，避免 Docker 升级后根据环境改变存储实现。
    storageDriver = "overlay2";
  };

  # Waydroid 共享宿主内核，并在 Plasma Wayland 会话中运行 Android 应用。
  virtualisation.waydroid.enable = true;

  # Linux 6.17 起 legacy iptables 由 CONFIG_NETFILTER_XTABLES_LEGACY 门控，
  # zen 内核默认不再提供 ip_tables/iptable_nat 模块；而 waydroid-net.sh 上游
  # 始终优先调用 iptables-legacy（waydroid#178 仍未修），容器启动时报
  # "Module ip_tables not found"。nixpkgs 为此提供官方变体 waydroid-nftables：
  # 构建时 USE_NFTABLES=1 把脚本的 LXC_USE_NFT 改为 true，包装 PATH 中的
  # iptables 也换成 nftables，与 NixOS 防火墙的 nftables 后端共存。
  virtualisation.waydroid.package = pkgs.waydroid-nftables;

  # 不启用 KernelSU：Waydroid 没有独立内核，启用它必须修改宿主内核，
  # 会把实验性 Android root 补丁带进整台主机的信任边界。

  # NixOS 的 Waydroid 模块只安装运行环境，不会选择 Android 镜像。
  # 首次启动容器前下载 GAPPS 镜像；已有完整镜像时绝不覆盖用户数据。
  systemd.services = {
    waydroid-gapps-init = {
      description = "Initialize Waydroid with GAPPS image";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      before = [ "waydroid-container.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "30min";
        ExecStart = waydroidGappsInit;
      };
    };

    waydroid-container = {
      requires = [ "waydroid-gapps-init.service" ];
      after = [ "waydroid-gapps-init.service" ];
    };
  };
}
