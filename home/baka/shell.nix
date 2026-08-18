# baka 的 Git、Bash 与 Zsh 配置。
let
  shellAliases = {
    ll = "ls -alh";
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
        "git"
        "docker"
        "npm"
        "python"
        "sudo"
      ];
      theme = "robbyrussell";
    };
  };
}
