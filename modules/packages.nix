# 系统级软件包。这里仅保留所有用户和故障排查都需要的基础工具；
# baka 的桌面应用与开发工具统一放在 home.nix 的 home.packages 中。
# 可运行 `nix search nixpkgs <关键词>` 搜索软件包；添加或删除名称后要重新构建系统。
{ pkgs, ... }:

{
  # 允许安装许可证不符合 Nixpkgs 自由软件标准的软件；Microsoft Edge、VS Code 等软件需要此选项。
  nixpkgs.config.allowUnfree = true;

  # 通过 NixOS 模块安装并集成 Firefox。
  programs.firefox.enable = true;

  # 这里列出的软件会安装到系统环境中，并对所有用户可用。
  environment.systemPackages = with pkgs; [
    vim # 文本编辑器，可用于修改配置文件；系统默认也提供 Nano。
    wget # 命令行文件下载工具。
    git # 版本控制工具。
    curl # 用于下载内容和测试网络接口的命令行工具。
  ];

  # 少数程序需要额外的特权包装器或用户会话服务，不能只放进 systemPackages。
  # 以下是 MTR 网络诊断工具和 GnuPG 密钥代理的配置示例，目前均未启用。
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # 如果需要从其他电脑远程登录本机，可以取消下一行的注释来启用 OpenSSH 服务。
  # 启用后还应配置登录密钥或安全密码，并检查防火墙规则。
  # services.openssh.enable = true;
}
