# baka 的桌面应用。
# bakaPackages.* 来自 pkgs/overlay.nix，即仓库 pkgs/ 目录下的自封装软件包。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # 通讯、协作与远程桌面。
    wechat
    qq
    ayugram-desktop
    telegram-desktop
    feishu
    bakaPackages.lark
    wemeet
    rustdesk-flutter
    termius

    # 影音、音乐与直播。
    bakaPackages.bilibili
    bakaPackages.douyin
    bakaPackages.open-orpheus
    bakaPackages.splayer-next
    go-musicfox
    vlc
    obs-studio

    # 桌面工具和外观。
    bakaPackages.keyguard
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
    bakaPackages.motrix
    bakaPackages.pjsk-cursor-theme
  ];
}
