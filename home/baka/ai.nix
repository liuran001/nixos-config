# baka 的 AI 编程工具：配置、插件与运行时密钥注入集中在此文件。
{
  lib,
  omp,
  pkgs,
  ...
}:

let
  apiBaseUrl = "https://oapi.obdo.cc/v1";
  defaultModel = "gpt-5.6-sol";
  deepseekModel = "deepseek-v4-pro";
  homeDirectory = "/home/baka";
  codexHome = "${homeDirectory}/.codex";
  oapiSecretFile = "/run/agenix/oapi-api-key";
  githubSecretFile = "/run/agenix/github-token";

  # 均来自 pkgs/overlay.nix；oh-my-claudecode 的源码输入在那里接线。
  aiTools = pkgs.bakaPackages.ai-tools;
  kimiPackage = pkgs.bakaPackages.kimi-code;
  ohMyClaudeCode = pkgs.bakaPackages.oh-my-claudecode;
  # nix-bun upstream still reads the deprecated stdenv.isLinux/isDarwin aliases.
  # Supply plain boolean compatibility fields locally so evaluation stays quiet
  # without mutating nixpkgs globally or forking the upstream package.
  ompStdenv = pkgs.stdenv // {
    inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  };
  ompBun = omp.inputs.nix-bun.packages.${pkgs.stdenv.hostPlatform.system}.bun.override {
    stdenv = ompStdenv;
  };
  ompPackage = omp.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
    bun = ompBun;
  };
  ohMyOpenCodeRoot = "${aiTools}/lib/node_modules/nixos-ai-tools/node_modules/oh-my-opencode";
  ohMyOpenCodePlugin = "file://${ohMyOpenCodeRoot}";
  # 复用 Claude Code 官方登录的 OAuth 凭据，为 OpenCode 提供 anthropic provider。
  opencodeClaudeAuthPlugin = "file://${pkgs.bakaPackages.opencode-claude-auth}";
  # 启动时从 /v1/models 动态发现模型列表，替代写死的 models 表。
  opencodeModelsDiscoveryPlugin = "file://${pkgs.bakaPackages.opencode-models-discovery}";

  jsonFormat = pkgs.formats.json { };
  tomlFormat = pkgs.formats.toml { };
  yamlFormat = pkgs.formats.yaml { };

  # 密钥只在目标进程启动时读取，不进入 Nix store 或全局会话环境。
  mkSecretWrapper =
    {
      name,
      executable,
      secretFile,
      secretVariables,
      environment ? { },
      arguments ? [ ],
    }:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        secret_file=${lib.escapeShellArg secretFile}
        if [[ ! -r "$secret_file" ]]; then
          printf '%s\n' ${lib.escapeShellArg "${name}: 无法读取 agenix 运行时密钥"} >&2
          exit 1
        fi

        secret_value="$(<"$secret_file")"
        if [[ -z "$secret_value" ]]; then
          printf '%s\n' ${lib.escapeShellArg "${name}: agenix 运行时密钥为空"} >&2
          exit 1
        fi

        ${lib.concatMapStringsSep "\n" (variable: ''export ${variable}="$secret_value"'') secretVariables}
        unset secret_value
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (variable: value: "export ${variable}=${lib.escapeShellArg value}") environment
        )}

        exec ${lib.escapeShellArg executable} ${lib.escapeShellArgs arguments} "$@"
      '';
    };

  # --plugin-dir 只是主命令的选项，子命令的解析器不认它，会把取值当成多余的
  # 位置参数报 "Unknown argument"（例如 `claude rc`）。因此只在主命令上注入。
  # 列表取自 `claude --help` 的 Commands 段，另加隐藏的 remote-control/rc。
  claudeSubcommands = [
    "agents"
    "auth"
    "auto-mode"
    "doctor"
    "gateway"
    "import"
    "install"
    "mcp"
    "plugin"
    "plugins"
    "project"
    "rc"
    "remote-control"
    "setup-token"
    "ultrareview"
    "update"
    "upgrade"
  ];

  # Claude 使用官方账号登录；这里只加载 Oh My ClaudeCode 插件，不注入第三方
  # API 密钥、端点或模型环境变量。
  claudeWithPlugin = pkgs.writeShellApplication {
    name = "claude";
    text = ''
      # Force the official claude.ai login path even if an old shell exported
      # API-compatible credentials from a previous NixOS generation.
      unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL \
        ANTHROPIC_MODEL ANTHROPIC_DEFAULT_FABLE_MODEL \
        ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL \
        ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_SMALL_FAST_MODEL \
        CLAUDE_CODE_SUBAGENT_MODEL

      case "''${1-}" in
        ${lib.concatStringsSep " | " claudeSubcommands})
          exec ${lib.getExe pkgs.claude-code} "$@"
          ;;
      esac

      exec ${lib.getExe pkgs.claude-code} \
        --plugin-dir ${ohMyClaudeCode}/share/oh-my-claudecode \
        "$@"
    '';
  };

  opencodeWrapper = mkSecretWrapper {
    name = "opencode";
    executable = lib.getExe pkgs.opencode;
    secretFile = oapiSecretFile;
    secretVariables = [ "OPENAI_API_KEY" ];
    environment = {
      DO_NOT_TRACK = "1";
      OMO_DISABLE_POSTHOG = "1";
      OMO_SEND_ANONYMOUS_TELEMETRY = "0";
    };
  };

  ohMyOpenCodeWrapper = mkSecretWrapper {
    name = "oh-my-opencode";
    executable = "${aiTools}/bin/oh-my-opencode";
    secretFile = oapiSecretFile;
    secretVariables = [ "OPENAI_API_KEY" ];
  };

  omoWrapper = mkSecretWrapper {
    name = "omo-agent-toolkit";
    executable = "${aiTools}/bin/omo-agent-toolkit";
    secretFile = oapiSecretFile;
    secretVariables = [ "OPENAI_API_KEY" ];
  };


  ompWrapper = mkSecretWrapper {
    name = "omp";
    executable = "${ompPackage}/bin/omp";
    secretFile = oapiSecretFile;
    secretVariables = [ "OPENAI_API_KEY" ];
    environment.OMP_SKIP_SETUP = "1";
  };

  dshWrapper = mkSecretWrapper {
    name = "dsh";
    executable = "${aiTools}/bin/dsh";
    secretFile = oapiSecretFile;
    secretVariables = [ "DEEPSEEK_API_KEY" ];
    environment.DSH_TELEMETRY_MODE = "DISABLED";
  };

  omxWrapper = mkSecretWrapper {
    name = "omx";
    executable = "${aiTools}/bin/omx";
    secretFile = oapiSecretFile;
    secretVariables = [ "OPENAI_API_KEY" ];
    environment.OMX_AUTO_UPDATE = "0";
  };

  ghWrapper = mkSecretWrapper {
    name = "gh";
    executable = lib.getExe pkgs.gh;
    secretFile = githubSecretFile;
    secretVariables = [
      "GH_TOKEN"
      "GITHUB_TOKEN"
    ];
  };

  codexConfigBase = tomlFormat.generate "codex-config-base.toml" {
    model = defaultModel;
    model_provider = "obdo";
    model_reasoning_effort = "ultra";
    approval_policy = "never";
    sandbox_mode = "danger-full-access";
    web_search = "disabled";

    # Codex asks to persist this trust decision on first launch. Keep it
    # declarative so the generated config remains intentionally read-only.
    projects = {
      "${homeDirectory}".trust_level = "trusted";
      "${homeDirectory}/nixos".trust_level = "trusted";
    };

    developer_instructions = ''
      Oh My Codex 已安装。以 ~/.codex/AGENTS.md 为编排入口，按其中规则使用
      ~/.codex/agents、~/.codex/prompts 与 ~/.codex/skills；适合并行的独立任务优先使用原生 subagent。
    '';
    notify = [
      "${lib.getExe pkgs.nodejs_24}"
      "${aiTools}/lib/node_modules/nixos-ai-tools/node_modules/oh-my-codex/dist/scripts/notify-hook.js"
    ];

    model_providers.obdo = {
      name = "Baka API";
      base_url = apiBaseUrl;
      wire_api = "responses";
      auth = {
        command = "${pkgs.coreutils}/bin/cat";
        args = [ oapiSecretFile ];
      };
    };

    agents = {
      enabled = true;
      default_subagent_model = defaultModel;
      default_subagent_reasoning_effort = "ultra";
    };

    features = {
      goals = true;
      hooks = true;
      multi_agent = true;
      multi_agent_v2 = true;
    };

    shell_environment_policy.set.USE_OMX_EXPLORE_CMD = "0";

    analytics.enabled = false;
    feedback.enabled = false;
    otel = {
      exporter = "none";
      trace_exporter = "none";
      metrics_exporter = "none";
      log_user_prompt = false;
    };

    tui.status_line = [
      "model-with-reasoning"
      "git-branch"
      "context-remaining"
      "total-input-tokens"
      "total-output-tokens"
    ];
  };

  # OMX 的 hook hash 会随其 Nix store 路径变化，因此从同一构建产物合并信任片段。
  codexConfig = pkgs.runCommand "codex-config.toml" { } ''
    install -m 0644 ${codexConfigBase} "$out"
    printf '\n' >> "$out"
    sed 's|@CODEX_HOME@|${codexHome}|g' \
      ${aiTools}/share/oh-my-codex/hooks-trust.toml.in >> "$out"
  '';



  ompModels = yamlFormat.generate "omp-models.yml" {
    providers.obdo = {
      baseUrl = apiBaseUrl;
      api = "openai-responses";
      apiKey = "OPENAI_API_KEY";
      # omp 原生支持从 OpenAI 兼容端点动态发现模型；已知模型（如
      # gpt-5.6-sol）的 reasoning/上下文窗口等元数据从内置 catalog 继承。
      discovery.type = "openai-models-list";
    };
  };

  opencodeConfig = jsonFormat.generate "opencode.json" {
    model = "obdo/${defaultModel}";
    autoupdate = false;
    share = "disabled";
    plugin = [
      ohMyOpenCodePlugin
      opencodeClaudeAuthPlugin
      opencodeModelsDiscoveryPlugin
    ];
    provider.obdo = {
      name = "Baka API";
      npm = "@ai-sdk/openai";
      options = {
        baseURL = apiBaseUrl;
        apiKey = "{env:OPENAI_API_KEY}";
        # 模型列表由 opencode-models-discovery 插件从该端点动态发现，
        # 不再写死；enabled 同时是对该 provider 的强制发现开关。
        modelsDiscovery.enabled = true;
      };
    };
  };

  opencodeTuiConfig = jsonFormat.generate "opencode-tui.json" {
    plugin = [
      ohMyOpenCodePlugin
      opencodeModelsDiscoveryPlugin
    ];
  };

  omoAgentOverrides =
    lib.genAttrs
      [
        "OpenCode-Builder"
        "atlas"
        "build"
        "explore"
        "hephaestus"
        "librarian"
        "metis"
        "momus"
        "multimodal-looker"
        "oracle"
        "plan"
        "prometheus"
        "sisyphus"
        "sisyphus-junior"
      ]
      (_: {
        model = "obdo/${defaultModel}";
        reasoning = "xhigh";
      });

  omoCategoryOverrides =
    lib.genAttrs
      [
        "visual-engineering"
        "ultrabrain"
        "deep"
        "artistry"
        "quick"
        "unspecified-low"
        "unspecified-high"
        "writing"
      ]
      (_: {
        model = "obdo/${defaultModel}";
        reasoning = "xhigh";
      });

  # OMO 5.x 的统一配置位于 ~/.omo；[opencode] 保存 OpenCode harness 专属覆盖。
  omoConfig = jsonFormat.generate "omo.json" {
    # 配置由 Home Manager 只读管理；声明已采用当前统一 reasoning 格式，避免启动时尝试原地迁移。
    _migrations = [ "2026-08-reasoning-unification" ];
    "[opencode]" = {
      auto_update = false;
      telemetry = false;
      agents = omoAgentOverrides;
      categories = omoCategoryOverrides;
    };
  };

  deepseekHarnessPatch = yamlFormat.generate "cordis.patch.yml" [
    {
      id = "agent-default-model";
      config = {
        provider = "deepseek-official";
        model = deepseekModel;
      };
    }
    {
      id = "llm-deepseek";
      config = {
        apiKeyEnv = "DEEPSEEK_API_KEY";
        baseURL = apiBaseUrl;
        reasoningEffort = "max";
      };
    }
    {
      id = "web";
      disabled = true;
    }
    {
      id = "web-search-deepseek";
      disabled = true;
    }
    {
      id = "tool-web";
      disabled = true;
    }
  ];
in
{
  home.packages = [
    pkgs.codex
    claudeWithPlugin
    dshWrapper
    ghWrapper
    kimiPackage
    ohMyOpenCodeWrapper
    ohMyClaudeCode
    omoWrapper
    omxWrapper
    opencodeWrapper
  ];

  home.file = {
    ".codex/config.toml".source = codexConfig;
    ".codex/AGENTS.md".source = "${aiTools}/share/oh-my-codex/AGENTS.md";
    ".codex/agents" = {
      source = "${aiTools}/share/oh-my-codex/agents";
      recursive = true;
    };
    ".codex/prompts" = {
      source = "${aiTools}/share/oh-my-codex/prompts";
      recursive = true;
    };
    ".codex/skills" = {
      source = "${aiTools}/share/oh-my-codex/skills";
      recursive = true;
    };
    ".codex/hooks.json".source = "${aiTools}/share/oh-my-codex/hooks.json";
    ".codex/.omx/native-agents.json".source = "${aiTools}/share/oh-my-codex/.omx/native-agents.json";

    ".dsh/cordis.patch.yml".source = deepseekHarnessPatch;
    ".omp/agent/models.yml".source = ompModels;
    ".omo/omo.json".source = omoConfig;
  };

  xdg.configFile = {
    "opencode/opencode.json".source = opencodeConfig;
    "opencode/tui.json".source = opencodeTuiConfig;
  };

  programs.omp = {
    enable = true;
    package = ompWrapper;
    settings = {
      modelRoles.default = "obdo/${defaultModel}";
      defaultThinkingLevel = "xhigh";
      marketplace.autoUpdate = "off";
      startup.quiet = true;
      tools.approvalMode = "write";
      web_search.enabled = false;
    };
  };

  # 社区封装会审计并修补官方 Electron 包；它与 CLI 共用 ~/.codex/config.toml。
  programs.codexDesktopLinux.enable = true;
  home.sessionVariables.CODEX_LINUX_DISABLE_USAGE_REPORTING = "1";
}
