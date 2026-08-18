# 系统软件包。以后安装/卸载软件主要修改这个文件。
# 可运行 `nix search nixpkgs <关键词>` 搜索软件包；添加或删除名称后要重新构建系统。
#
# nixpkgs 没有、需要自己动手打包的软件，请按 callPackage 约定放到 pkgs/ 目录下：
# 每个包一个 .nix 文件（参考 pkgs/kimi-code.nix），然后在这里加一行
# (callPackage ../pkgs/<包名>.nix { }) 引用它。
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
    fastfetch # 在终端显示系统和硬件概要信息。
    telegram-desktop # Telegram 桌面客户端。
    git # 版本控制工具。
    curl # 用于下载内容和测试网络接口的命令行工具。
    microsoft-edge # Microsoft Edge 浏览器，需要允许非自由软件。
    codex # OpenAI Codex 命令行工具。
    (callPackage ../pkgs/kimi-code.nix { }) # Kimi Code 命令行编程助手，运行命令为 kimi。
    vlc # 视频和音频播放器。
    vscode # Visual Studio Code 编辑器，需要允许非自由软件。
    flameshot # 截图工具，支持贴图钉在屏幕上；KDE 也自带 Spectacle，按 PrintScreen 可用。
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
