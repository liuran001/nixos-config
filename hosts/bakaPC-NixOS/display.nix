# 本机显示器布局：让 SDDM 的 KWin 使用与 Plasma 会话相同的缩放和输出设置。
{ ... }:

{
  # Plasma 中修改显示器设置后，需重新复制 ~/.config/kwinoutputconfig.json 到本目录。
  systemd.tmpfiles.rules = [
    "d /var/lib/sddm/.config 0755 sddm sddm - -"
    "L+ /var/lib/sddm/.config/kwinoutputconfig.json - - - - ${./kwinoutputconfig.json}"
  ];
}
