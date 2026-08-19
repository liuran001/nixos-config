# bakaPC-NixOS 主机入口：汇总本机专属配置、可复用系统模块与 baka 的 Home Manager 配置。
{
  codex-desktop-linux,
  ohMyClaudeCodeSource,
  omp,
  ...
}:

{
  imports = [
    # 本机专属配置。
    ./hardware-configuration.nix
    ./boot.nix
    ./display.nix
    ./graphics.nix
    ./networking.nix
    ./nvidia.nix
    ./secrets.nix
    ./storage.nix
    ./users.nix

    # 可复用于其他主机的系统功能。
    ../../modules/desktop.nix
    ../../modules/fonts.nix
    ../../modules/gaming.nix
    ../../modules/ghelper.nix
    ../../modules/i18n.nix
    ../../modules/niri.nix
    ../../modules/nix-settings.nix
    ../../modules/packages.nix
    ../../modules/virtualisation.nix
  ];

  # stateVersion 是本机有状态数据的兼容基线，例如部分服务的数据目录和数据库版本。
  # 它不是当前安装的 NixOS 版本；正常升级系统时也不要随版本号一起修改，
  # 随意提高可能触发不可逆的数据迁移。它绑定这台机器的安装历史，
  # 因此留在主机目录里，而不是放进可复用的 modules/。
  system.stateVersion = "26.05"; # 本机首次安装时使用的 NixOS 版本。

  # NixOS 与 Home Manager 的接线；具体用户配置位于 home/baka/。
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    extraSpecialArgs = { inherit ohMyClaudeCodeSource omp; };
    users.baka.imports = [
      ../../home/baka
      codex-desktop-linux.homeManagerModules.default
      omp.homeManagerModules.default
    ];
  };
}
