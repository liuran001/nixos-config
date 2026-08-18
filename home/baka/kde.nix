# baka 的 KDE Plasma 用户偏好；只写需要声明固定的键，保留其余系统设置可编辑。
{ lib, pkgs, ... }:

{
  # KWin Wayland 按 libinput 设备保存触摸板选项。用 kwriteconfig6 精确更新
  # 当前内置触摸板，避免把外接鼠标的滚轮方向也一并反转。
  home.activation.kdeTouchpadNaturalScroll = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6"} \
      --file kcminputrc \
      --group Libinput \
      --group 1267 \
      --group 13026 \
      --group "ASCE1200:00 04F3:32E2 Touchpad" \
      --key NaturalScroll \
      --type bool \
      --notify \
      true
  '';
}
