# 用户账户和 sudo 权限。
{ ... }:

{
  # 定义本机用户 baka。若需要修改密码，可在终端运行 `passwd`。
  users.users.baka = {
    isNormalUser = true; # 普通可登录用户，而不是系统服务账户。
    description = "baka"; # 用户的显示名称。
    # networkmanager 组允许管理网络；wheel 组允许通过 sudo 执行管理员命令。
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # wheel 用户使用 sudo 时必须输入自己的密码。
  security.sudo.wheelNeedsPassword = true;
}
