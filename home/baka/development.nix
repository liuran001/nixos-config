# baka 的编程语言、IDE 与开发工具。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    python3
    nodejs
    android-tools
    android-studio
    jetbrains.idea
    vscode
  ];
}
