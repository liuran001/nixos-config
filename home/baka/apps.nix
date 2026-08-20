# baka 的桌面应用。
# bakaPackages.* 来自 pkgs/overlay.nix，即仓库 pkgs/ 目录下的自封装软件包。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # 通讯、协作与远程桌面。
    bakaPackages.wechat # 官方包外加了 QT_IM_MODULE，否则无法输入中文
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
    tsukimi # GTK4 的 Emby 客户端，MPV 播放
    vlc
    obs-studio

    # 办公与文档。
    bakaPackages.wpsoffice # 官方包外加了 QT_IM_MODULE，否则无法输入中文

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
    bakaPackages.ksystemlog # 去掉 X-KDE-SubstituteUID，否则 Plasma 菜单点击无反应
    # partitionmanager 不在这里装：见 modules/desktop.nix 的
    # programs.partition-manager.enable，它同时提供提权所需的 polkit 与 D-Bus 配置。
    microsoft-edge
    bakaPackages.motrix
    # OpenChamber 桌面版在 home/baka/ai.nix 安装：它 fork 的 opencode 需要
    # agenix 密钥，只能走那里的包装器，直接装原包会拿不到模型和 MCP 认证。
    bakaPackages.pjsk-cursor-theme
  ];
}
