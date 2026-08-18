# baka 的 Home Manager 入口；软件、Shell 与 dotfiles 按职责拆分，避免单个文件持续膨胀。
{
  imports = [
    ./ai.nix
    ./apps.nix
    ./development.nix
    ./shell.nix
    ./xdg.nix
  ];

  # 与 system.stateVersion 类似的兼容基线，固定为首次启用 Home Manager 时的版本。
  home.stateVersion = "26.05";
}
