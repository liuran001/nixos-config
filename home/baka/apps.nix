# baka 的桌面应用。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # 通讯、协作与远程桌面。
    wechat
    qq
    telegram-desktop
    feishu
    wemeet
    rustdesk-flutter

    # 影音、音乐与直播。
    (callPackage ../../pkgs/bilibili.nix { })
    (callPackage ../../pkgs/douyin.nix { })
    (callPackage ../../pkgs/open-orpheus.nix { })
    (callPackage ../../pkgs/splayer-next.nix { })
    go-musicfox
    vlc
    obs-studio

    # 桌面工具和外观。
    fastfetch
    kdePackages.kate
    microsoft-edge
    flameshot
    (callPackage ../../pkgs/pjsk-cursor-theme.nix { })
  ];
}
