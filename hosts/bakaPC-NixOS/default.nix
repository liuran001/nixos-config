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
