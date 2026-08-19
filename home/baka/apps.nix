# baka 的桌面应用。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # 通讯、协作与远程桌面。
    wechat
    qq
    ayugram-desktop
    telegram-desktop
    feishu
    (callPackage ../../pkgs/lark.nix { })
    wemeet
    rustdesk-flutter
    termius

    # 影音、音乐与直播。
    (callPackage ../../pkgs/bilibili.nix { })
    (callPackage ../../pkgs/douyin.nix { })
    (callPackage ../../pkgs/open-orpheus.nix { })
    (callPackage ../../pkgs/splayer-next.nix { })
    go-musicfox
    vlc
    obs-studio

    # 桌面工具和外观。
    (callPackage ../../pkgs/keyguard.nix { })
    fastfetch
    kdePackages.filelight
    kdePackages.kate
    kdePackages.kcalc
    kdePackages.kclock
    kdePackages.kdf
    kdePackages.kfind
    kdePackages.kleopatra
    kdePackages.kmousetool
    kdePackages.kompare
    kdePackages.ksystemlog
    kdePackages.partitionmanager
    microsoft-edge
    (callPackage ../../pkgs/motrix.nix { })
    (callPackage ../../pkgs/pjsk-cursor-theme.nix { })
  ];
}
