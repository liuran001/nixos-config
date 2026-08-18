# baka 的桌面应用。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    fastfetch
    kdePackages.kate
    telegram-desktop
    microsoft-edge
    vlc
    flameshot
    (callPackage ../../pkgs/pjsk-cursor-theme.nix { })
  ];
}
