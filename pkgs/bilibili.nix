# msojocs/bilibili-linux：复用 nixpkgs 的 Electron/Wayland 封装，只更新固定的上游发行包。
# 这样可保留 Electron sandbox，避免直接运行 AppImage 中的 --no-sandbox 启动脚本。
{
  bilibili,
  fetchurl,
}:

bilibili.overrideAttrs (_oldAttrs: rec {
  version = "1.18.0-1";

  src = fetchurl {
    url = "https://github.com/msojocs/bilibili-linux/releases/download/v${version}/io.github.msojocs.bilibili_${version}_amd64.deb";
    hash = "sha256-EK0w3PwaNhGJhJZuTYBjpu+u6A3pb4V6zKji15ZeQwA=";
  };
})
