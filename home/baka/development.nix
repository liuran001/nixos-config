# baka 的编程语言、IDE 与开发工具。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # 显式包含 pip；项目依赖仍应安装到 venv，而不是写入只读的 Nix store。
    (python3.withPackages (pythonPackages: [ pythonPackages.pip ]))
    nodejs
    ast-grep
    android-tools
    android-studio
    jetbrains.idea
    vscode
  ];
}
