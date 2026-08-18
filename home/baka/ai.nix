# baka 的 AI 编程工具；provider 与秘密读取配置也集中在此文件。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    codex
    (callPackage ../../pkgs/kimi-code.nix { })
  ];

  # 社区封装会审计并修补官方 Electron 包；保留独立的 codex CLI。
  programs.codexDesktopLinux.enable = true;
  home.sessionVariables.CODEX_LINUX_DISABLE_USAGE_REPORTING = "1";
}
