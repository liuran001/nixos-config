# home-manager：以声明方式管理 baka 的用户级配置（~/.config 下的点文件）。
# 配置文件本体存放在 modules/niri/ 目录下；修改后运行
# `sudo nixos-rebuild switch --flake /etc/nixos` 生效（niri 会热重载新配置）。
{ ... }:

{
  home-manager = {
    # 与系统共用同一份 nixpkgs 求值结果，避免重复下载和版本错位。
    useGlobalPkgs = true;
    # 用户软件包装进用户 profile（/etc/profiles/per-user），而不是系统环境。
    useUserPackages = true;

    users.baka = { ... }: {
      # 与 system.stateVersion 类似的兼容基线，固定为首次启用 home-manager 时的版本，之后不要改动。
      home.stateVersion = "26.05";

      # niri 桌面套件的用户配置（状态栏、通知、启动器、锁屏等）。
      xdg.configFile = {
        "niri/config.kdl".source = ./niri/config.kdl;
        "waybar/config.jsonc".source = ./niri/waybar-config.jsonc;
        "waybar/style.css".source = ./niri/waybar-style.css;
        "mako/config".source = ./niri/mako-config;
        "fuzzel/fuzzel.ini".source = ./niri/fuzzel.ini;
        "swaylock/config".source = ./niri/swaylock.conf;
      };
    };
  };
}
