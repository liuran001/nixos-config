# home-manager：以声明方式管理 baka 的用户级配置（git、bash、~/.config 点文件）。
# 点文件本体存放在 modules/dotfiles/ 下，目录结构与 ~/.config 一一对应；
# 修改后运行 `sudo nixos-rebuild switch --flake /etc/nixos` 生效（niri 会热重载新配置）。
# 注意：被管理的文件是只读软链，应用内的图形化设置改动不会持久保存，要改就改 dotfiles/ 里的文件。
{ ... }:

{
  home-manager = {
    # 与系统共用同一份 nixpkgs 求值结果，避免重复下载和版本错位。
    useGlobalPkgs = true;
    # 用户软件包装进用户 profile（/etc/profiles/per-user），而不是系统环境。
    useUserPackages = true;
    # flameshot、fcitx5 这类程序运行时会回写自己的配置文件；
    # 激活时若发现已有文件，备份成 <文件名>.hm-bak 而不是报错中断。
    backupFileExtension = "hm-bak";

    users.baka = { ... }: {
      # 与 system.stateVersion 类似的兼容基线，固定为首次启用 home-manager 时的版本，之后不要改动。
      home.stateVersion = "26.05";

      # git 全局配置（此前只有本 repo 的局部占位身份）。
      programs.git = {
        enable = true;
        settings = {
          user.name = "liuran001";
          user.email = "bdovo@bdovo.cc";
          init.defaultBranch = "main";
        };
      };

      # bash 配置（系统原先没有 ~/.bashrc）。
      programs.bash = {
        enable = true;
        shellAliases = {
          ll = "ls -alh";
          # 应用本仓库系统配置的常用命令。不要用 sudo 包裹整个命令（会在 .git/objects
          # 留下 root 属主文件）；--sudo 让 nixos-rebuild 只在激活等必要步骤提权。
          nrs = "nixos-rebuild switch --flake /etc/nixos --sudo";
        };
        # 历史记录：忽略重复命令和以空格开头的命令。
        historyControl = [ "ignoredups" "ignorespace" ];
        historySize = 10000;
        historyFileSize = 100000;
      };

      xdg.configFile = {
        # niri 桌面套件（合成器、状态栏、通知、启动器、锁屏）。
        "niri/config.kdl".source = ./dotfiles/niri/config.kdl;
        "waybar/config.jsonc".source = ./dotfiles/waybar/config.jsonc;
        "waybar/style.css".source = ./dotfiles/waybar/style.css;
        "mako/config".source = ./dotfiles/mako/config;
        "fuzzel/fuzzel.ini".source = ./dotfiles/fuzzel/fuzzel.ini;
        "swaylock/config".source = ./dotfiles/swaylock/config;
        # Flameshot 截图工具设置。
        "flameshot/flameshot.ini".source = ./dotfiles/flameshot/flameshot.ini;
        # Fcitx 5 输入法偏好（拼音、简繁转换、标点等）；输入法组和候选窗字体由 modules/i18n.nix 管理。
        "fcitx5/conf/pinyin.conf".source = ./dotfiles/fcitx5/conf/pinyin.conf;
        "fcitx5/conf/chttrans.conf".source = ./dotfiles/fcitx5/conf/chttrans.conf;
        "fcitx5/conf/punctuation.conf".source = ./dotfiles/fcitx5/conf/punctuation.conf;
        "fcitx5/conf/notifications.conf".source = ./dotfiles/fcitx5/conf/notifications.conf;
      };
    };
  };
}
