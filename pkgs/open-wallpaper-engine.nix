# open-wallpaper-engine：Waywallen 的 Wallpaper Engine 场景/Web 渲染插件，
# 固定上游官方发布的插件 ZIP。产物根目录即插件目录（plugin.toml 所在处），
# 由 home/baka/waywallen.nix 挂到用户插件目录。
# 渲染器二进制按 FHS 布局链接，在 waywallen AppImage 的沙箱内运行，
# 其 liblz4/libva 依赖由 pkgs/waywallen.nix 的 extraPkgs 提供。
{
  fetchurl,
  lib,
  stdenv,
  unzip,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "open-wallpaper-engine";
  version = "0.2.5";

  src = fetchurl {
    url = "https://github.com/waywallen/open-wallpaper-engine/releases/download/v${finalAttrs.version}/org.waywallen.open-wallpaper-engine-${finalAttrs.version}-linux-x86_64.zip";
    hash = "sha256-4oUhtnsR6d9Z0yY2g3ihHzvHKQapIPQIVgSyGZ257sE=";
  };

  nativeBuildInputs = [ unzip ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    # ZIP 根目录就是插件本体，原样铺到 $out。
    mkdir -p "$out"
    cp -a ./plugin.toml ./files.txt ./main.lua ./bin ./wallpaper_engine "$out/"
    # unzip 对部分条目不保留可执行位，渲染器必须可执行。
    find "$out/bin" -type f -exec chmod +x {} +

    runHook postInstall
  '';

  meta = {
    description = "Wallpaper Engine scene and web renderer plugin for Waywallen";
    homepage = "https://github.com/waywallen/open-wallpaper-engine";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
