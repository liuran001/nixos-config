# 固定发布版 npm 包，供 DeepSeek Harness、Oh My Codex 和 Oh My OpenCode 使用。
# package-lock.json 带 registry integrity，构建时不会执行第三方安装脚本。
{
  buildNpmPackage,
  bun,
  codex,
  lib,
  makeWrapper,
  nodejs_24,
  pnpm,
  tmux,
}:

buildNpmPackage {
  pname = "nixos-ai-tools";
  version = "1.0.0";
  src = ./ai-tools;

  nodejs = nodejs_24;
  npmDepsHash = "sha256-5wdWw6glSV+U59ywtQ8toztcVVTZ9ZsvBiZ57lHnXHQ=";
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;
  dontNpmPrune = true;

  nativeBuildInputs = [
    codex
    makeWrapper
  ];

  postInstall = ''
    packageRoot="$out/lib/node_modules/nixos-ai-tools/node_modules"

    makeWrapper ${lib.getExe nodejs_24} "$out/bin/dsh" \
      --add-flags "$packageRoot/@deepseek-ai/dsh/lib/bin.js" \
      --prefix PATH : ${
        lib.makeBinPath [
          nodejs_24
          pnpm
        ]
      }
    makeWrapper ${lib.getExe nodejs_24} "$out/bin/omx" \
      --add-flags "$packageRoot/oh-my-codex/dist/cli/omx.js" \
      --set-default OMX_AUTO_UPDATE 0 \
      --prefix PATH : ${
        lib.makeBinPath [
          codex
          nodejs_24
          tmux
        ]
      }
    makeWrapper ${lib.getExe nodejs_24} "$out/bin/oh-my-opencode" \
      --add-flags "$packageRoot/oh-my-opencode/bin/oh-my-opencode.js" \
      --set-default DO_NOT_TRACK 1 \
      --set-default OMO_DISABLE_POSTHOG 1 \
      --set-default OMO_SEND_ANONYMOUS_TELEMETRY 0 \
      --prefix PATH : ${
        lib.makeBinPath [
          bun
          nodejs_24
        ]
      }

    ln -s oh-my-opencode "$out/bin/oh-my-openagent"
    ln -s oh-my-opencode "$out/bin/omo-agent-toolkit"
    ln -s oh-my-opencode "$out/bin/lazycodex"
    ln -s oh-my-opencode "$out/bin/lazycodex-ai"

    # 以 legacy 用户模式离线生成 OMX 的技能、角色与全局编排说明；
    # 用户的 config.toml 由 Home Manager 生成；这里保留完整运行资源，
    # 并把 hook 信任片段中的构建期 HOME 改成可替换占位符。
    setupHome=$(mktemp -d)
    HOME="$setupHome" \
      CODEX_HOME="$setupHome/.codex" \
      OMX_AUTO_UPDATE=0 \
      "$out/bin/omx" setup \
        --scope user \
        --legacy \
        --force \
        --no-mcp

    mkdir -p "$out/share/oh-my-codex/.omx"
    cp -R \
      "$setupHome/.codex/AGENTS.md" \
      "$setupHome/.codex/agents" \
      "$setupHome/.codex/prompts" \
      "$setupHome/.codex/skills" \
      "$out/share/oh-my-codex/"
    install -Dm444 \
      "$setupHome/.codex/hooks.json" \
      "$out/share/oh-my-codex/hooks.json"
    install -Dm444 \
      "$setupHome/.codex/.omx/native-agents.json" \
      "$out/share/oh-my-codex/.omx/native-agents.json"

    sed -n \
      '/# OMX-owned Codex hook trust state/,/# End OMX-owned Codex hook trust state/p' \
      "$setupHome/.codex/config.toml" \
      | sed "s|$setupHome/.codex|@CODEX_HOME@|g" \
      > "$out/share/oh-my-codex/hooks-trust.toml.in"
  '';

  meta = {
    description = "Pinned runtime bundle for declarative AI agent tools";
    # DSH/OMX are MIT; Oh My OpenCode 5.x uses SUL-1.0.
    license = [
      lib.licenses.mit
      lib.licenses.sustainableUse
    ];
    platforms = lib.platforms.linux;
  };
}
