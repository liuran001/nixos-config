# baka 的 Git、Bash 与 Zsh 配置。
{ lib, pkgs, ... }:
let
  shellAliases = {
    # ls/la/lt/lla 由 programs.eza 自动生成（见下方），这里只覆盖 ll 的参数。
    ll = "eza -la --group-directories-first";
    # 不要用 sudo 包裹整个命令，否则会在 .git/objects 留下 root 属主文件。
    nrt = "nixos-rebuild test --flake /etc/nixos --sudo";
    nrb = "nixos-rebuild boot --flake /etc/nixos --sudo";
    nrs = "nixos-rebuild switch --flake /etc/nixos --sudo";
  };
in
{
  programs.git = {
    enable = true;
    # 不声明姓名和邮箱，让每个仓库自行决定提交身份。
    settings.init.defaultBranch = "main";
  };

  programs.bash = {
    enable = true;
    inherit shellAliases;
    historyControl = [
      "ignoredups"
      "ignorespace"
    ];
    historySize = 10000;
    historyFileSize = 100000;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    inherit shellAliases;

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 10000;
      save = 100000;
      ignoreDups = true;
      ignoreSpace = true;
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "colored-man-pages" # man 手册按语法着色。
        "dirhistory" # Alt+左/右 在最近访问过的目录间前进后退。
        "docker"
        "extract" # `x 文件` 解压任意常见归档格式，不必记 tar 参数。
        "git"
        "npm"
        "python"
        "sudo" # 连按两次 Esc 给当前命令行补上 sudo。
        "systemd" # sc-status、sc-restart 等 systemctl 缩写。
      ];
      # 主题留空：提示符交给下面的 powerlevel10k，避免 oh-my-zsh 再设一次 ZSH_THEME。
      theme = "";
    };

    # powerlevel10k 不在 oh-my-zsh 自带主题里，作为独立插件加载。
    # Home Manager 在 .zshrc 的 900 位置 source 插件，正好排在 oh-my-zsh（800）之后。
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    initContent = lib.mkMerge [
      # 即时提示符：缓存命中时先画出提示符再跑完 .zshrc，必须排在所有输出之前。
      (lib.mkOrder 500 ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')
      # 样式配置必须排在主题本体（900）之后才能生效。
      (lib.mkOrder 1200 ''
        source ~/.p10k.zsh
      '')
    ];
  };

  # powerlevel10k 的样式。以上游 lean 预设为底，只覆盖少数几项，
  # 免得把 1700 行的生成配置抄进仓库。
  # 本文件是指向 Nix store 的只读软链，`p10k configure` 无法写入它；
  # 要改提示符请改这里再重新构建。
  home.file.".p10k.zsh".text = ''
    source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/config/p10k-lean.zsh

    # 让 `p10k reload` 等命令指回本文件，而不是上游预设在 store 里的路径。
    typeset -g POWERLEVEL9K_CONFIG_FILE=''${''${(%):-%x}:a}

    # 给两行提示符补上左侧连接线，视觉上把一次命令框起来。
    typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX='%240F╭─'
    typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX='%240F╰─'

    # 默认的 verbose 会在 .zshrc 有任何输出时每次开终端都打印告警，改成静默。
    typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
  '';

  # Ctrl-R 搜历史、Ctrl-T 找文件、Alt-C 跳目录，均带预览窗格。
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --exclude .git";
    defaultOptions = [
      "--height=40%"
      "--layout=reverse"
      "--border"
    ];
    fileWidget.command = "fd --type f --hidden --exclude .git";
    fileWidget.options = [
      "--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
    ];
    changeDirWidget.command = "fd --type d --hidden --exclude .git";
    changeDirWidget.options = [
      "--preview 'eza --tree --level=2 --color=always {}'"
    ];
  };

  # 按访问频率记录目录，`z 关键词` 直接跳过去，`zi` 用 fzf 交互挑选。
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  # ls 的替代品；同时提供 ls/la/lt/lla 别名，ll 在上面单独覆盖。
  programs.eza = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    icons = "auto";
    git = true;
  };

  # 带语法高亮和 Git 标记的 cat；上面的 fzf 预览也用它。
  # 不覆盖 cat 本身，避免管道里出现分页器和颜色转义。
  programs.bat.enable = true;

  home.packages = with pkgs; [
    fd # 更快的 find，也是 fzf 的取文件命令。
    ripgrep # 更快的 grep，按 .gitignore 跳过无关文件。
  ];
}
