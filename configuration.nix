# 这是本机的主要 NixOS 配置文件，用来声明系统要启用的功能和安装的软件。
# 修改并保存后，需要运行 `sudo nixos-rebuild switch` 构建并启用新配置。
# 以 `#` 开头或跟在 `#` 后面的内容只是注释，不会改变系统；大多数配置项必须以分号结束。
# 如果构建失败，NixOS 不会启用有问题的新配置，当前可以正常使用的系统仍会保留。
# 可运行 `man configuration.nix` 或 `nixos-help` 查看本机自带的帮助文档。

# config 表示合并后的系统配置，pkgs 表示当前 nixpkgs 中可用的软件包集合。
{ config, pkgs, ... }:

let
  # 当前 nixpkgs 尚未收录 Kimi，因此把官方发行的 Linux x64 二进制封装为本地 Nix 软件包。
  # 版本和 SHA-256 均固定，重新构建时会验证下载内容，避免上游文件被静默替换。
  kimiCode = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "kimi-code";
    version = "0.37.1";

    src = pkgs.fetchurl {
      url = "https://github.com/MoonshotAI/kimi-code/releases/download/%40moonshot-ai/kimi-code%40${version}/kimi-code-linux-x64.zip";
      hash = "sha256-9dVX4Eg4vcD/PWD7EIoNt/9S9MhwKpT8q84Eh/YAZbc=";
    };

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.unzip
    ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    dontStrip = true;

    unpackPhase = ''
      runHook preUnpack
      unzip "$src"
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 kimi "$out/bin/kimi"
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Kimi Code command-line coding agent";
      homepage = "https://github.com/MoonshotAI/kimi-code";
      license = licenses.mit;
      mainProgram = "kimi";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
    };
  };
in
{
  imports =
    [ # 导入安装系统时自动生成的硬件配置，其中包含磁盘、文件系统和启动所需的内核模块等信息。
      # 一般不要手动修改 hardware-configuration.nix，以免影响系统启动或磁盘挂载。
      ./hardware-configuration.nix
    ];

  # 使用 systemd-boot 管理 UEFI 启动菜单。
  boot.loader.systemd-boot.enable = true;
  # 允许 NixOS 写入 UEFI 固件变量，以便创建和更新系统启动项。
  boot.loader.efi.canTouchEfiVariables = true;

  # 使用当前 nixpkgs 提供的最新内核系列；如果以后遇到驱动兼容问题，可删除此行以使用默认稳定内核。
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # 设置本机主机名；它会显示在终端提示符、局域网设备列表等位置。
  networking.hostName = "nixos";
  # 下面的选项会使用 wpa_supplicant 管理无线网络。当前已经启用 NetworkManager，因此不要同时启用它。
  # networking.wireless.enable = true;

  # 仅在网络环境要求使用代理时才取消注释并填写；普通家庭网络不需要设置。
  # default 表示默认代理地址，noProxy 表示不经过代理的主机或域名。
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # 启用 NetworkManager，用于管理有线网络、Wi-Fi、VPN 等；KDE 系统托盘会提供图形界面。
  networking.networkmanager.enable = true;

  # 设置系统时区为中国标准时间（北京时间，UTC+8）。
  time.timeZone = "Asia/Shanghai";

  # 设置默认语言环境。这里保留英文界面，同时保证程序使用 UTF-8 编码。
  i18n.defaultLocale = "en_US.UTF-8";

  # 单独将地址、计量单位、货币、姓名、数字、纸张、电话和日期时间格式设为中国大陆格式。
  # 这些设置主要影响日期、金额等显示方式，不会把 KDE 或应用程序界面改成中文。
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  # 启用 Fcitx 5 中文输入法框架。登录桌面后按 Ctrl+Space 可在英文和中文之间切换。
  # KDE Wayland 如果无法输入，可在“系统设置 → 虚拟键盘”中选择“Fcitx 5”，然后注销并重新登录。
  i18n.inputMethod = {
    # 输入法总开关。
    enable = true;
    # 指定使用 Fcitx 5，而不是 IBus 等其他输入法框架。
    type = "fcitx5";
    fcitx5 = {
      # 安装中文拼音插件和 Rime（中州韵）引擎；当前默认使用普通拼音。
      addons = [
        pkgs.qt6Packages.fcitx5-chinese-addons # 提供拼音、双拼、五笔等常用中文输入方式。
        pkgs.fcitx5-rime # 提供可高度自定义的 Rime 输入法框架。
      ];
      # 预先创建一个输入法组，避免首次启动后还要手动添加英文键盘和拼音。
      settings.inputMethod = {
        "Groups/0" = {
          Name = "Default"; # 输入法组名称。
          "Default Layout" = "us"; # 默认使用美式键盘布局。
          DefaultIM = "pinyin"; # 激活输入法时默认进入拼音。
        };
        # 输入法组中的第一个项目是英文键盘。
        "Groups/0/Items/0" = {
          Name = "keyboard-us";
          Layout = "";
        };
        # 输入法组中的第二个项目是中文拼音。
        "Groups/0/Items/1" = {
          Name = "pinyin";
          Layout = "";
        };
        # 指定输入法组的显示顺序。
        GroupOrder."0" = "Default";
      };
    };
  };

  # 让 Chromium 和 Electron 类程序优先使用原生 Wayland。
  # nixpkgs 的 Edge 启动包装器会据此自动启用 Wayland 输入法和 text-input-v3 协议。
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # 启用 X11 图形服务，以保留 Plasma (X11) 登录会话；当前使用的 Plasma Wayland 会话不受影响。
  # 如果以后确认只使用 Wayland，可以测试关闭此选项；新手建议先保持启用。
  services.xserver.enable = true;

  # 启用 SDDM 登录管理器和 KDE Plasma 6 桌面环境。
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # 设置 X11 程序使用美式键盘布局；这不会影响 Fcitx 5 的中英文切换。
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # 启用 CUPS 打印服务，用于发现、添加和使用打印机。
  services.printing.enable = true;

  # 使用 PipeWire 统一处理声音，并通过兼容层支持 ALSA 和 PulseAudio 应用程序。
  # 关闭旧的 PulseAudio 服务，避免它与 PipeWire 的 PulseAudio 兼容服务发生冲突。
  services.pulseaudio.enable = false;
  # 允许音频服务获得实时调度权限，以减少爆音、卡顿和延迟。
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true; # 启用 PipeWire 服务。
    alsa.enable = true; # 让使用 ALSA 的程序通过 PipeWire 输出声音。
    alsa.support32Bit = true; # 为 Steam、旧游戏等 32 位程序提供声音支持。
    pulse.enable = true; # 提供 PulseAudio 兼容接口。
    # 如果以后需要运行专业音频或音乐制作软件，可以取消下一行的注释来启用 JACK 兼容接口。
    # jack.enable = true;
    # 当前 NixOS 会默认使用 WirePlumber 管理 PipeWire 会话，不需要在这里额外指定会话管理器。
  };

  # Plasma 6 默认会启用 libinput 触摸板支持，通常无需重复配置。
  # 如果触摸板无法使用，可尝试取消下一行的注释后重新构建系统。
  # services.libinput.enable = true;

  # 定义本机用户 baka。若需要修改密码，可在终端运行 `passwd`。
  users.users."baka" = {
    isNormalUser = true; # 普通可登录用户，而不是系统服务账户。
    description = "baka"; # 用户的显示名称。
    # networkmanager 组允许管理网络；wheel 组允许通过 sudo 执行管理员命令。
    extraGroups = [ "networkmanager" "wheel" ];
    # 这里的软件只提供给 baka 用户；需要给所有用户安装的软件应放到 environment.systemPackages。
    packages = with pkgs; [
      kdePackages.kate # KDE 自带的图形文本编辑器。
      # thunderbird # 如需安装 Thunderbird，删除本行最前面的井号。
    ];
  };

  # 允许 baka 通过 sudo 执行任意管理员命令，且不再要求输入密码。
  security.sudo.extraRules = [
    {
      users = [ "baka" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # 通过 NixOS 模块安装并集成 Firefox。
  programs.firefox.enable = true;

  # 允许安装许可证不符合 Nixpkgs 自由软件标准的软件；Microsoft Edge 等软件需要此选项。
  nixpkgs.config.allowUnfree = true;

  # 这里列出的软件会安装到系统环境中，并对所有用户可用。
  # 可运行 `nix search nixpkgs <关键词>` 搜索软件包；添加或删除名称后要重新构建系统。
  environment.systemPackages = with pkgs; [
    vim # 文本编辑器，可用于修改 configuration.nix；系统默认也提供 Nano。
    wget # 命令行文件下载工具。
    fastfetch # 在终端显示系统和硬件概要信息。
    telegram-desktop # Telegram 桌面客户端。
    git # 版本控制工具。
    curl # 用于下载内容和测试网络接口的命令行工具。
    microsoft-edge # Microsoft Edge 浏览器，需要允许非自由软件。
    codex # OpenAI Codex 命令行工具。
    kimiCode # Kimi Code 命令行编程助手，运行命令为 kimi。
    vlc # 视频和音频播放器。
  ];

  # 少数程序需要额外的特权包装器或用户会话服务，不能只放进 systemPackages。
  # 以下是 MTR 网络诊断工具和 GnuPG 密钥代理的配置示例，目前均未启用。
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # 如果需要从其他电脑远程登录本机，可以取消下一行的注释来启用 OpenSSH 服务。
  # 启用后还应配置登录密钥或安全密码，并检查防火墙规则。
  # services.openssh.enable = true;

  # NixOS 默认启用防火墙。服务器程序需要从其他设备访问时，可在这里开放对应的 TCP 或 UDP 端口。
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # 不建议直接关闭整个防火墙；只有明确了解风险并确有需要时才使用下一项。
  # networking.firewall.enable = false;

  # stateVersion 是有状态数据格式的兼容基线，例如部分服务的数据目录和数据库版本。
  # 它不是当前安装的 NixOS 版本；正常升级系统时也不要随版本号一起修改。
  # 通常应永久保留首次安装系统时的值。随意提高它可能触发不可逆的数据迁移。
  # 修改前务必阅读 `man configuration.nix` 中 system.stateVersion 的说明。
  system.stateVersion = "26.05"; # 本机首次安装时使用的 NixOS 版本。

  # 使用 CERNET 的 Nix 二进制缓存镜像下载已经构建好的软件包，以改善中国大陆的下载速度。
  # 这只改变下载来源，不会改变 nixpkgs 软件源的版本或系统配置内容。
  nix.settings.substituters = [
    "https://mirrors.cernet.edu.cn/nix-channels/store"
  ];

  # 启用 nix-command 和 flakes 实验特性，以支持 flake.nix 管理配置。
  nix.settings.experimental-features = [ "nix-command" "flakes" ];


  # ===== NVIDIA 显卡驱动（RTX 5060 Laptop，Blackwell 架构）=====
  # 本机是 Intel 核显 + NVIDIA 独显的混合显卡笔记本。
  # 默认由 Intel 核显渲染桌面以省电；需要独显的程序用 nvidia-offload 命令启动，例如：
  #   nvidia-offload steam
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
    # 使用当前内核对应的稳定版驱动。
    package = config.boot.kernelPackages.nvidiaPackages.stable;
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
