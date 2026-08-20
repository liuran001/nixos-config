# 本机 mihomo 透明代理（TUN 模式，开机自启）。
#
# 配置文件与 SSID 直连名单均含敏感信息（订阅地址、内网 SSID），
# 走 agenix 密文注入，见 secrets/ 与 ./secrets.nix 的说明。
#
# 连接到直连名单里的 WiFi（上游网关自带代理）时由 NetworkManager
# dispatcher 自动停止 mihomo，切到其他网络时自动拉起。
{
  config,
  pkgs,
  lib,
  ...
}:
let
  # vernesong smart 内核 fork（配置用了 type: smart 策略组，官方 mihomo 不支持），
  # 含本机贡献的 tailscale lanfix / subnet router 等补丁。仓库公开，无敏感信息。
  mihomo-smart = pkgs.buildGoModule rec {
    pname = "mihomo-smart";
    version = "alpha-smart-46c2e061";
    src = pkgs.fetchFromGitHub {
      owner = "liuran001";
      repo = "mihomo";
      rev = "46c2e06118173b481562f49e3221d757ea8ce6a7";
      hash = "sha256-g9lD/RCM9Y7FZLfAXduaMndrOw46mjbrBvQYhYZ/Ccc=";
    };
    vendorHash = "sha256-qYOqdrlg2drUqQuXT6OuIOb+uWMnlU+fCv2IYpcefWk=";
    tags = [ "with_gvisor" ];
    ldflags = [
      "-s"
      "-w"
      "-X github.com/metacubex/mihomo/constant.Version=${version}"
      "-X github.com/metacubex/mihomo/constant.BuildTime=nix"
    ];
    subPackages = [ "." ];
    doCheck = false;
    meta.mainProgram = "mihomo";
  };

  # 连接这些 SSID 时停止 mihomo（名单是 agenix 密文，一行一个 SSID）。
  dispatcherScript = pkgs.writeText "mihomo-ssid-gate" ''
    #!${pkgs.runtimeShell}
    # $1=interface $2=action；只在连接状态变化时评估。
    case "$2" in
      up|down|connectivity-change) ;;
      *) exit 0 ;;
    esac
    blacklist=${config.age.secrets.mihomo-ssid-direct.path}
    ssid="$(${pkgs.wirelesstools}/bin/iwgetid --raw 2>/dev/null || true)"
    if [ -n "$ssid" ] && [ -r "$blacklist" ] && ${pkgs.gnugrep}/bin/grep -qxF "$ssid" "$blacklist"; then
      ${pkgs.systemd}/bin/systemctl stop mihomo.service
    else
      ${pkgs.systemd}/bin/systemctl start mihomo.service
    fi
  '';
in
{
  age.secrets.mihomo-config.file = ../../secrets/mihomo-config.age;
  age.secrets.mihomo-ssid-direct.file = ../../secrets/mihomo-ssid-direct.age;

  services.mihomo = {
    enable = true;
    package = mihomo-smart;
    configFile = config.age.secrets.mihomo-config.path;
    tunMode = true;
  };

  networking.networkmanager.dispatcherScripts = [
    {
      source = dispatcherScript;
      type = "basic";
    }
  ];
}
