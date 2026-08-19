# baka 的编程语言、IDE 与开发工具。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # 显式包含 pip；项目依赖仍应安装到 venv，而不是写入只读的 Nix store。
    (python3.withPackages (pythonPackages: [ pythonPackages.pip ]))
    nodejs
    # OpenChamber Web CLI 同样在 home/baka/ai.nix 安装，原因见那里的包装器注释。
    ast-grep
    # 命令行音视频转码；核显的 VA-API 栈见 hosts/bakaPC-NixOS/graphics.nix，
    # 可用 `ffmpeg -hwaccels` 确认 vaapi 可用。需要更多冷门编解码器时换成 ffmpeg-full。
    ffmpeg
    android-tools
    android-studio
    jetbrains.idea
    vscode
  ];
}
