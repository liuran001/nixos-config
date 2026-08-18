# Claude Code 插件版 Oh My ClaudeCode；上游仓库已提交运行所需的 bridge/dist 产物。
{
  fetchFromGitHub,
  lib,
  makeWrapper,
  nodejs_24,
  stdenvNoCC,
  tmux,
}:

stdenvNoCC.mkDerivation {
  pname = "oh-my-claudecode";
  version = "4.15.10";

  src = fetchFromGitHub {
    owner = "Yeachan-Heo";
    repo = "oh-my-claudecode";
    rev = "5aa678c6f7a769df84561d9486d8e9e30b68c3dc";
    hash = "sha256-LtaQ/WRb+IeiRtZE+hK+rzJNpPmyT07aBO9rV8cIomk=";
  };

  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    pluginRoot="$out/share/oh-my-claudecode"
    mkdir -p "$pluginRoot" "$out/bin"
    cp -R . "$pluginRoot/"

    # 4.15.10 提交的 bridge/cli.cjs 已捆绑运行时依赖，可直接提供 CLI；
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
