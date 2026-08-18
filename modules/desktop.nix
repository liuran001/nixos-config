# 桌面环境：KDE Plasma 6、SDDM 登录管理器、蓝牙、PipeWire 音频、打印服务。
{ ... }:

{
  # 让 Chromium 和 Electron 类程序优先使用原生 Wayland。
  # nixpkgs 的 Edge 启动包装器会据此自动启用 Wayland 输入法和 text-input-v3 协议。
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # 启用 X11 图形服务，以保留 Plasma (X11) 登录会话；当前使用的 Plasma Wayland 会话不受影响。
  # 如果以后确认只使用 Wayland，可以测试关闭此选项；新手建议先保持启用。
  services.xserver.enable = true;

  # 启用 SDDM 登录管理器和 KDE Plasma 6 桌面环境。
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  # SDDM 使用 Wayland 模式（kwin 合成器），否则登录界面不会跟随屏幕缩放。
  services.displayManager.sddm.wayland = {
    enable = true;
    compositor = "kwin";
  };

  # 设置 X11 程序使用美式键盘布局；这不会影响 Fcitx 5 的中英文切换。
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # 启用 CUPS 打印服务，用于发现、添加和使用打印机。
  services.printing.enable = true;

  # 启用 BlueZ 蓝牙后端，并安装 Blueman 的 D-Bus/systemd 集成供 niri 会话使用。
  # KDE 会继续使用原生 Bluedevil；Blueman 托盘由 home/baka/ 限定为只在 niri 中启动。
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

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
}
