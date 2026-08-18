# baka 的 AI 编程工具；provider 与秘密读取配置也集中在此文件。
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    codex
    (callPackage ../../pkgs/kimi-code.nix { })
  ];
}
