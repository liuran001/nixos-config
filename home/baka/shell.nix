# baka 的 Git 与 Bash 配置。
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
    settings = {
      user.name = "liuran001";
      user.email = "bdovo@bdovo.cc";
      init.defaultBranch = "main";
    };
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

}
