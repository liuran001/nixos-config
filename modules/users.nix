# 用户账户和 sudo 权限。
{ pkgs, ... }:

{
  # 定义本机用户 baka。若需要修改密码，可在终端运行 `passwd`。
  users.users."baka" = {
    isNormalUser = true; # 普通可登录用户，而不是系统服务账户。
    description = "baka"; # 用户的显示名称。
    # networkmanager 组允许管理网络；wheel 组允许通过 sudo 执行管理员命令。
    extraGroups = [ "networkmanager" "wheel" ];
    # 这里的软件只提供给 baka 用户；需要给所有用户安装的软件应放到 packages.nix。
    packages = with pkgs; [
      kdePackages.kate # KDE 自带的图形文本编辑器。
      # thunderbird # 如需安装 Thunderbird，删除本行最前面的井号。
    ];
  };

  # 允许 baka 通过 sudo 执行任意管理员命令，且不再要求输入密码。
  security.sudo.extraRules = [
    {
      users = [ "baka" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
