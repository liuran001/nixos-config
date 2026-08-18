# 用户账户、登录 Shell 和 sudo 权限。
{ pkgs, ... }:

{
  # 定义本机用户 baka。若需要修改密码，可在终端运行 `passwd`。
  users.users.baka = {
    isNormalUser = true; # 普通可登录用户，而不是系统服务账户。
    description = "baka"; # 用户的显示名称。
    shell = pkgs.zsh;
    # kvm 供 Android 模拟器使用；networkmanager 管理网络；wheel 使用 sudo。
    extraGroups = [
      "kvm"
      "networkmanager"
      "wheel"
    ];
  };

  # 将 Zsh 注册为可用登录 Shell；Bash 仍保留，可随时运行 bash 进入。
  programs.zsh.enable = true;

  # wheel 用户使用 sudo 时必须输入自己的密码。
  security.sudo.wheelNeedsPassword = true;
}
