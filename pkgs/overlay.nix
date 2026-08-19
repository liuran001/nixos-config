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
    douyin = prev.callPackage ./douyin.nix { };
    keyguard = prev.callPackage ./keyguard.nix { };
    kimi-code = prev.callPackage ./kimi-code.nix { };
    lark = prev.callPackage ./lark.nix { };
    motrix = prev.callPackage ./motrix.nix { };
    # 上游仓库直接作为源码输入，由 flake.nix 传入。
    oh-my-claudecode = prev.callPackage ./oh-my-claudecode.nix {
      src = ohMyClaudeCodeSource;
    };
    open-orpheus = prev.callPackage ./open-orpheus.nix { };
    pjsk-cursor-theme = prev.callPackage ./pjsk-cursor-theme.nix { };
    splayer-next = prev.callPackage ./splayer-next.nix { };
    # 在 nixpkgs 的微信之上补输入法环境变量，不改动上游包本身。
    wechat = prev.callPackage ./wechat.nix { };
  };
}
