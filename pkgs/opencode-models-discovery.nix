# OpenCode 的模型发现插件：启动时从 OpenAI 兼容端点的 /v1/models 动态拉取
# 模型列表合并进 provider 配置，并为发现的模型回填 context/output 上限。
# npm 发布包直接以 TS 源码分发（opencode 的 bun 运行时直接加载）；
# 对 @opencode-ai/plugin 的引用全部是 import type，运行时唯一真实依赖是
# xdg-basedir（用于定位 opencode 数据目录缓存发现结果），单独铺进 node_modules。
{
  fetchurl,
  lib,
  stdenvNoCC,
}:

let
  xdgBasedir = fetchurl {
    url = "https://registry.npmjs.org/xdg-basedir/-/xdg-basedir-5.1.0.tgz";
    hash = "sha256-XvopyBs/oQbT+3TQCd9KqdlG3MlXv8yKsKY17uv/rHM=";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode-models-discovery";
  version = "1.5.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/opencode-models-discovery/-/opencode-models-discovery-${finalAttrs.version}.tgz";
    hash = "sha256-2cF/TjGLNBXjh18TDJdlkCVHZTaVV0bNCJFcqvluHOw=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    cp -R . "$out"
    mkdir -p "$out/node_modules/xdg-basedir"
    tar xzf ${xdgBasedir} -C "$out/node_modules/xdg-basedir" --strip-components=1
    runHook postInstall
  '';

  meta = {
    description = "OpenCode plugin for dynamic model discovery across OpenAI-compatible providers";
    homepage = "https://git.0xc.cn/0xc0000142/opencode-models-discovery";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
