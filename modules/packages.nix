# 系统软件包。以后安装/卸载软件主要修改这个文件。
# 可运行 `nix search nixpkgs <关键词>` 搜索软件包；添加或删除名称后要重新构建系统。
{ pkgs, ... }:

let
  # 当前 nixpkgs 尚未收录 Kimi，因此把官方发行的 Linux x64 二进制封装为本地 Nix 软件包。
  # 版本和 SHA-256 均固定，重新构建时会验证下载内容，避免上游文件被静默替换。
  kimiCode = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "kimi-code";
    version = "0.37.1";

    src = pkgs.fetchurl {
      url = "https://github.com/MoonshotAI/kimi-code/releases/download/%40moonshot-ai/kimi-code%40${version}/kimi-code-linux-x64.zip";
      hash = "sha256-9dVX4Eg4vcD/PWD7EIoNt/9S9MhwKpT8q84Eh/YAZbc=";
    };

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.unzip
    ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    dontStrip = true;

    unpackPhase = ''
      runHook preUnpack
      unzip "$src"
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 kimi "$out/bin/kimi"
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Kimi Code command-line coding agent";
      homepage = "https://github.com/MoonshotAI/kimi-code";
      license = licenses.mit;
      mainProgram = "kimi";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
    };
  };
in
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
    kimiCode # Kimi Code 命令行编程助手，运行命令为 kimi。
    vlc # 视频和音频播放器。
    vscode # Visual Studio Code 编辑器，需要允许非自由软件。
    snipaste # 截图和贴图工具。
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
