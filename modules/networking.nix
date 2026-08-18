# 网络配置：主机名、NetworkManager。
{ ... }:

{
  # 设置本机主机名；它会显示在终端提示符、局域网设备列表等位置。
  networking.hostName = "nixos";
  # 下面的选项会使用 wpa_supplicant 管理无线网络。当前已经启用 NetworkManager，因此不要同时启用它。
  # networking.wireless.enable = true;

  # 仅在网络环境要求使用代理时才取消注释并填写；普通家庭网络不需要设置。
  # default 表示默认代理地址，noProxy 表示不经过代理的主机或域名。
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # 启用 NetworkManager，用于管理有线网络、Wi-Fi、VPN 等；KDE 系统托盘会提供图形界面。
  networking.networkmanager.enable = true;

  # NixOS 默认启用防火墙。服务器程序需要从其他设备访问时，可在这里开放对应的 TCP 或 UDP 端口。
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # 不建议直接关闭整个防火墙；只有明确了解风险并确有需要时才使用下一项。
  # networking.firewall.enable = false;
}
