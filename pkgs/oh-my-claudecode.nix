# Claude Code 插件版 Oh My ClaudeCode；上游仓库已提交运行所需的 bridge/dist 产物。
{
  lib,
  makeWrapper,
  nodejs_24,
  src,
  stdenvNoCC,
  tmux,
}:

stdenvNoCC.mkDerivation {
  pname = "oh-my-claudecode";
  version = "unstable-${src.lastModifiedDate or "unknown"}";

  inherit src;

  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    pluginRoot="$out/share/oh-my-claudecode"
    mkdir -p "$pluginRoot" "$out/bin"
    cp -R . "$pluginRoot/"

    # 上游提交的 bridge/cli.cjs 已捆绑运行时依赖，可直接提供 CLI；
    # 固定插件根目录后，setup 会自动使用适合不可变 Nix store 的 plugin-dir 模式。
    makeWrapper ${lib.getExe nodejs_24} "$out/bin/omc" \
      --add-flags "$pluginRoot/bin/oh-my-claudecode.js" \
      --set-default OMC_PLUGIN_ROOT "$pluginRoot" \
      --prefix PATH : ${
        lib.makeBinPath [
          nodejs_24
          tmux
        ]
      }
    ln -s omc "$out/bin/oh-my-claudecode"
    runHook postInstall
  '';

  meta = {
    description = "Multi-agent orchestration plugin for Claude Code";
    homepage = "https://github.com/Yeachan-Heo/oh-my-claudecode";
    license = lib.licenses.mit;
    mainProgram = "omc";
    platforms = lib.platforms.linux;
  };
}
