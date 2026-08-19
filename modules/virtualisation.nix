# Docker 与 Waydroid 容器运行时。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  kernel = config.boot.kernelPackages.kernel;
  # Waydroid 用的就是宿主内核，所以 Android 侧的 root 只能来自宿主内核模块。
  kernelsuModule = config.boot.kernelPackages.callPackage ../pkgs/kernelsu-waydroid { };
  kernelsuKo = "${kernelsuModule}/lib/modules/${kernel.modDirVersion}/extra/kernelsu.ko";

  # 容器里的 ksud/管理器靠 reboot(0xDEADBEEF, 0xCAFEBABE, ...) 这个魔数调用向
  # KernelSU 驱动要文件描述符，之后才走 ioctl。Waydroid 默认的 seccomp 黑名单
  # 把 reboot 整个挡掉，管理器会一直显示“未安装”，所以放行这一个系统调用。
  # 容器有独立的 pid namespace，真正的 reboot 只会打到容器自己身上。
  waydroidPackage = pkgs.waydroid-nftables.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      sed -i '/^reboot$/d' data/configs/waydroid.seccomp
    '';
  });

  loadKernelsu = pkgs.writeShellScript "waydroid-kernelsu-load" ''
    set -eu

    # kernelsu.ko 引用了 ext4_unregister_sysfs。ext4 在 zen 内核里是可加载模块，
    # 没加载时这个符号根本不出现在 kallsyms 中，modloader 也就无从修补。
    ${pkgs.kmod}/bin/modprobe ext4

    # 模块只在 Android init 首次 exec 时抓 tracepoint，容器停掉后就自行失效，
    # 因此每次拉起容器前都重新加载一遍。
    if ${pkgs.kmod}/bin/lsmod | ${pkgs.gnugrep}/bin/grep -q '^kernelsu '; then
      ${pkgs.kmod}/bin/rmmod kernelsu
    fi

    ${pkgs.bakaPackages.modloader}/bin/modloader ${kernelsuKo}
  '';

  # 管理器 APK 走官方渠道：内核模块内置的是官方签名哈希，第三方重打包过不了校验。
  # 32389 是与当前模块（32386）最接近的官方版本。
  kernelsuManagerApk = pkgs.fetchurl {
    url = "https://github.com/tiann/KernelSU/releases/download/v3.2.0/KernelSU_v3.2.0_32389-release.apk";
    hash = "sha256-xu/0iY4TWneNVQVPQM1drBOjdI7VCMcyAEVeMwyvII8=";
  };

  kernelsuManagerInstall = pkgs.writeShellScriptBin "waydroid-kernelsu-manager" ''
    set -eu
    echo "Installing KernelSU manager into Waydroid..."
    exec ${waydroidPackage}/bin/waydroid app install ${kernelsuManagerApk}
  '';

  # Android 侧的行为开关。waydroid prop set 只改运行时属性，写在这里的会经由
  # waydroid.cfg 的 [properties] 展开进 waydroid_base.prop，容器每次启动都带上。
  waydroidProperties = {
    # 让每个 Android 应用各自开一个 Wayland 窗口，交给 Plasma 管理，
    # 而不是全部挤在 waydroid show-full-ui 那一块全屏画布里。
    "persist.waydroid.multi_windows" = "true";
  };

  waydroidSyncProps = pkgs.writeShellScript "waydroid-sync-props" ''
    set -eu

    # 还没初始化就什么都别做，交给 waydroid-gapps-init。
    [ -s /var/lib/waydroid/waydroid.cfg ] || exit 0

    exec ${pkgs.python3}/bin/python3 ${./waydroid/sync-props.py} \
      ${waydroidPackage}/bin/waydroid \
      ${lib.escapeShellArgs (lib.mapAttrsToList (name: value: "${name}=${value}") waydroidProperties)}
  '';

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
  virtualisation.waydroid.package = waydroidPackage;

  # KernelSU：Waydroid 没有独立内核，root 只能装在宿主内核里。这里用的是
  # supechicken 的 waydroid 分支，编译成外部模块而不是重编内核，风险局限在
  # 一个随时可以 rmmod 的模块上，但仍然要清楚它的含义：
  #  - Waydroid 的 LXC 没有 user namespace（config 里没有 lxc.idmap），容器 root
  #    就是宿主 root，只是被 cap.keep 限制。KernelSU 让容器内任意被授权的 App
  #    都能拿到这一级权限。
  #  - 没有 user namespace 也意味着 uid 直通：Android 的 uid 1000（system）就是
  #    宿主的 uid 1000（baka）。授权列表里只放普通 App，别给系统 uid 放行。
  #  - 模块要从 /proc/kallsyms 修补十余个未导出符号才能加载，属于绕过内核的
  #    模块 ABI 约定；换内核版本后必须重新验证，编译不过时就别硬上。
  # 授权列表由 Waydroid 里的 KernelSU 管理器维护，装它：waydroid-kernelsu-manager
  environment.systemPackages = [ kernelsuManagerInstall ];

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

    # 属性变了要重新生成 waydroid_base.prop，这一步必须在容器起来之前完成。
    waydroid-props = {
      description = "Apply declarative Waydroid properties";
      requires = [ "waydroid-gapps-init.service" ];
      after = [ "waydroid-gapps-init.service" ];
      before = [ "waydroid-container.service" ];
      requiredBy = [ "waydroid-container.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = waydroidSyncProps;
      };
    };

    # 每次容器启动前重新加载 KernelSU。RemainAfterExit 保持关闭，服务跑完就回到
    # inactive，下一次 waydroid-container 启动才会再次触发加载。
    # 用 requiredBy 而不是 wantedBy：加载失败时宁可容器起不来，也好过 Android
    # 正常启动、管理器却一直显示“未安装”，让人去别处找原因。
    waydroid-kernelsu = {
      description = "Load KernelSU kernel module for Waydroid";
      before = [ "waydroid-container.service" ];
      requiredBy = [ "waydroid-container.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        ExecStart = loadKernelsu;
      };
    };

    waydroid-container = {
      requires = [ "waydroid-gapps-init.service" ];
      after = [ "waydroid-gapps-init.service" ];
    };
  };
}
