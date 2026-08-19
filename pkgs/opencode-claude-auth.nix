# OpenCode 的 Anthropic 认证插件：直接复用 Claude Code 的 OAuth 凭据，
# 读取 ~/.claude/.credentials.json（macOS 走 Keychain），无需单独登录或 API key。
# npm 发布包自带编译好的 dist/，运行时只有 node 内置模块导入，无需安装依赖。
{
  fetchzip,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode-claude-auth";
  version = "2.1.6";

  src = fetchzip {
    url = "https://registry.npmjs.org/opencode-claude-auth/-/opencode-claude-auth-${finalAttrs.version}.tgz";
    hash = "sha256-wlTQ9wGUC4WWP0+KNZuO+2s6vZdLfdlKn4pglGtdZ9Q=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    cp -R . "$out"
    runHook postInstall
  '';

  meta = {
    description = "OpenCode plugin that authenticates the Anthropic provider with existing Claude Code OAuth credentials";
    homepage = "https://github.com/griffinmartin/opencode-claude-auth";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
