# ~/.config 下的声明式 dotfiles；这些文件会成为只读软链接，应修改仓库中的源文件。
{
  xdg.configFile = {
    # Blueman 托盘只在 niri 中启动；KDE 使用原生 Bluedevil。
    "autostart/blueman.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Blueman Applet
      Exec=blueman-applet
      OnlyShowIn=niri;
    '';

    # niri 桌面套件。
    "niri/config.kdl".source = ./dotfiles/niri/config.kdl;
    "waybar/config.jsonc".source = ./dotfiles/waybar/config.jsonc;
    "waybar/style.css".source = ./dotfiles/waybar/style.css;
    "mako/config".source = ./dotfiles/mako/config;
    "fuzzel/fuzzel.ini".source = ./dotfiles/fuzzel/fuzzel.ini;
    "swaylock/config".source = ./dotfiles/swaylock/config;

    "flameshot/flameshot.ini".source = ./dotfiles/flameshot/flameshot.ini;

    # Fcitx 5 输入法偏好；输入法组和候选窗字体由 modules/i18n.nix 管理。
    "fcitx5/conf/pinyin.conf".source = ./dotfiles/fcitx5/conf/pinyin.conf;
    "fcitx5/conf/chttrans.conf".source = ./dotfiles/fcitx5/conf/chttrans.conf;
    "fcitx5/conf/punctuation.conf".source = ./dotfiles/fcitx5/conf/punctuation.conf;
    "fcitx5/conf/notifications.conf".source = ./dotfiles/fcitx5/conf/notifications.conf;
  };
}
