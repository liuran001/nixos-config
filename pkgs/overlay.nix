# 把仓库自封装的软件包统一挂到 pkgs.bakaPackages 命名空间下，
# 供 NixOS 模块、Home Manager 和 flake 的 packages 输出共用同一份定义。
#
# 用命名空间而不是直接覆盖 nixpkgs 顶层属性：pkgs/bilibili.nix 这类包
# 本身就以 nixpkgs 的同名包为输入，直接覆盖会造成无限递归。
#
# pkgs/ghelper 不在这里：它需要 config.hardware.nvidia.package，
# 依赖 NixOS 配置的求值结果，只能在 modules/ghelper.nix 里 callPackage。
{ ohMyClaudeCodeSource }:

_final: prev: {
  bakaPackages = {
    ai-tools = prev.callPackage ./ai-tools.nix { };
    bilibili = prev.callPackage ./bilibili.nix { };
    camoufox = prev.callPackage ./camoufox.nix { };
    cc-switch = prev.callPackage ./cc-switch.nix { };
    douyin = prev.callPackage ./douyin.nix { };
    keyguard = prev.callPackage ./keyguard.nix { };
    kimi-code = prev.callPackage ./kimi-code.nix { };
    # 用 kdePackages.callPackage，让 KF6 与 Qt 6 的依赖直接从 KDE 包集里解析。
    krunner-pinyin-search = prev.kdePackages.callPackage ./krunner-pinyin-search.nix { };
    # 去掉上游 .desktop 的 X-KDE-SubstituteUID，否则 Plasma 菜单点击无反应。
    ksystemlog = prev.callPackage ./ksystemlog.nix { };
    lark = prev.callPackage ./lark.nix { };
    microsoft-edge-outlook = prev.callPackage ./microsoft-edge-outlook.nix { };
    # KernelSU 模块本身要按内核版本编译，只能在 modules/virtualisation.nix 里
    # 用 boot.kernelPackages.callPackage；加载器不依赖内核，放在这里方便单独构建。
    modloader = prev.callPackage ./modloader.nix { };
    motrix = prev.callPackage ./motrix.nix { };
    # 上游仓库直接作为源码输入，由 flake.nix 传入。
    oh-my-claudecode = prev.callPackage ./oh-my-claudecode.nix {
      src = ohMyClaudeCodeSource;
    };
    open-orpheus = prev.callPackage ./open-orpheus.nix { };
    openchamber-desktop = prev.callPackage ./openchamber/desktop.nix { };
    openchamber-web = prev.callPackage ./openchamber/web.nix { };
    opencode-claude-auth = prev.callPackage ./opencode-claude-auth.nix { };
    opencode-models-discovery = prev.callPackage ./opencode-models-discovery.nix { };
    pjsk-cursor-theme = prev.callPackage ./pjsk-cursor-theme.nix { };
    splayer-next = prev.callPackage ./splayer-next.nix { };
    # 在 nixpkgs 的微信之上补输入法环境变量，不改动上游包本身。
    wechat = prev.callPackage ./wechat.nix { };
    zcode = prev.callPackage ./zcode.nix { };
    # 同理，给 WPS 补上 QT_IM_MODULE，让它用上自带的 fcitx 插件。
    wpsoffice = prev.callPackage ./wpsoffice.nix { };
    # 从同一份 deb 里取出被 nixpkgs 删掉的自带字体，由 modules/fonts.nix 安装。
    wps-office-fonts = prev.callPackage ./wps-office-fonts.nix { };
  };
}
