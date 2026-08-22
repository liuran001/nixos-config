# Waywallen 的第三方插件 open-wallpaper-engine（Wallpaper Engine 场景/Web 渲染）。
#
# waywallen 只扫描两个插件目录（src/plugin/renderer_registry.rs 的
# standard_plugin_roots）：可执行文件自带的 system 目录（AppImage 内、只读
# store 里，无法追加）与 $XDG_DATA_HOME/waywallen/plugins 用户目录。这里把
# pkgs/open-wallpaper-engine.nix 的产物以只读软链挂进用户目录，与上游
# install_zip 生成的布局完全一致，UI 手动安装的 ZIP 也长这样。
#
# 注意：插件固定后 UI 的「安装插件更新」写不进只读软链会失败，属预期；
# 升级改 pkgs/open-wallpaper-engine.nix 的 version 随 flake 走。
{ pkgs, ... }:

{
  xdg.dataFile."waywallen/plugins/org.waywallen.open-wallpaper-engine".source =
    pkgs.bakaPackages.open-wallpaper-engine;
}
