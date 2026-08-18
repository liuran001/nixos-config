# baka 的 AI 编程工具：配置、插件与运行时密钥注入集中在此文件。
{
  lib,
  omp,
  pkgs,
  ...
}:

let
  apiBaseUrl = "https://oapi.obdo.cc/v1";
  apiRootUrl = "https://oapi.obdo.cc";
  defaultModel = "gpt-5.6-sol";
  deepseekModel = "deepseek-v4-pro";
  homeDirectory = "/home/baka";
  codexHome = "${homeDirectory}/.codex";
  oapiSecretFile = "/run/agenix/oapi-api-key";
  githubSecretFile = "/run/agenix/github-token";

  aiTools = pkgs.callPackage ../../pkgs/ai-tools.nix { };
  kimiPackage = pkgs.callPackage ../../pkgs/kimi-code.nix { };
  ohMyClaudeCode = pkgs.callPackage ../../pkgs/oh-my-claudecode.nix { };
  ompPackage = omp.packages.${pkgs.stdenv.hostPlatform.system}.default;
  ohMyOpenCodeRoot = "${aiTools}/lib/node_modules/nixos-ai-tools/node_modules/oh-my-opencode";
  ohMyOpenCodePlugin = "file://${ohMyOpenCodeRoot}";

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

  claudeEnvironment = {
    ANTHROPIC_BASE_URL = apiRootUrl;
    ANTHROPIC_MODEL = defaultModel;
    ANTHROPIC_DEFAULT_FABLE_MODEL = defaultModel;
    ANTHROPIC_DEFAULT_HAIKU_MODEL = defaultModel;
    ANTHROPIC_DEFAULT_OPUS_MODEL = defaultModel;
    ANTHROPIC_DEFAULT_SONNET_MODEL = defaultModel;
    ANTHROPIC_SMALL_FAST_MODEL = defaultModel;
    CLAUDE_CODE_SUBAGENT_MODEL = defaultModel;
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
    DISABLE_AUTOUPDATER = "1";
    DISABLE_TELEMETRY = "1";
    DISABLE_UPDATES = "1";
  };

  claudeWrapper = mkSecretWrapper {
    name = "claude";
    executable = lib.getExe pkgs.claude-code;
    secretFile = oapiSecretFile;
    secretVariables = [ "ANTHROPIC_AUTH_TOKEN" ];
    environment = claudeEnvironment;
    arguments = [
      "--plugin-dir"
      "${ohMyClaudeCode}/share/oh-my-claudecode"
    ];
  };

  omcWrapper = mkSecretWrapper {
    name = "omc";
    executable = lib.getExe ohMyClaudeCode;
    secretFile = oapiSecretFile;
    secretVariables = [ "ANTHROPIC_AUTH_TOKEN" ];
    environment = claudeEnvironment;
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

  piWrapper = mkSecretWrapper {
    name = "pi";
    executable = lib.getExe pkgs.pi-coding-agent;
    secretFile = oapiSecretFile;
    secretVariables = [ "OPENAI_API_KEY" ];
    environment = {
      PI_SKIP_VERSION_CHECK = "1";
      PI_TELEMETRY = "0";
    };
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

  kimiWrapper = mkSecretWrapper {
    name = "kimi";
    executable = lib.getExe kimiPackage;
    secretFile = oapiSecretFile;
    secretVariables = [ "KIMI_MODEL_API_KEY" ];
    environment = {
      KIMI_MODEL_NAME = defaultModel;
      KIMI_MODEL_PROVIDER_TYPE = "openai";
      KIMI_MODEL_BASE_URL = apiBaseUrl;
      KIMI_MODEL_MAX_CONTEXT_SIZE = "1048576";
      KIMI_MODEL_CAPABILITIES = "thinking,image_in,tool_use";
      KIMI_MODEL_DISPLAY_NAME = "GPT-5.6 Sol";
      KIMI_DISABLE_TELEMETRY = "1";
      KIMI_CODE_NO_AUTO_UPDATE = "1";
    };
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

    developer_instructions = ''
      Oh My Codex 已安装。以 ~/.codex/AGENTS.md 为编排入口，按其中规则使用
      ~/.codex/agents、~/.codex/prompts 与 ~/.codex/skills；适合并行的独立任务优先使用原生 subagent。
    '';
    notify = [
      "${lib.getExe pkgs.nodejs_24}"
      "${aiTools}/lib/node_modules/nixos-ai-tools/node_modules/oh-my-codex/dist/scripts/notify-hook.js"
    ];

    model_providers.obdo = {
      name = "OBDO OpenAI-compatible API";
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

  piModels = jsonFormat.generate "pi-models.json" {
    providers.obdo = {
      baseUrl = apiBaseUrl;
      api = "openai-responses";
      apiKey = "OPENAI_API_KEY";
      models = [
        {
          id = defaultModel;
          name = "GPT-5.6 Sol";
          reasoning = true;
        }
      ];
    };
  };

  piSettings = jsonFormat.generate "pi-settings.json" {
    defaultProvider = "obdo";
    defaultModel = defaultModel;
    defaultThinkingLevel = "xhigh";
    enableInstallTelemetry = false;
  };

  ompModels = yamlFormat.generate "omp-models.yml" {
    providers.obdo = {
      baseUrl = apiBaseUrl;
      api = "openai-responses";
      apiKey = "OPENAI_API_KEY";
      models = [
        {
          id = defaultModel;
          name = "GPT-5.6 Sol";
          reasoning = true;
        }
      ];
    };
  };

  opencodeConfig = jsonFormat.generate "opencode.json" {
    model = "obdo/${defaultModel}";
    autoupdate = false;
    share = "disabled";
    plugin = [ ohMyOpenCodePlugin ];
    provider.obdo = {
      name = "OBDO OpenAI-compatible API";
      npm = "@ai-sdk/openai";
      options = {
        baseURL = apiBaseUrl;
        apiKey = "{env:OPENAI_API_KEY}";
      };
      models.${defaultModel}.name = "GPT-5.6 Sol";
    };
  };

  opencodeTuiConfig = jsonFormat.generate "opencode-tui.json" {
    plugin = [ ohMyOpenCodePlugin ];
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
    claudeWrapper
    dshWrapper
    ghWrapper
    kimiWrapper
    ohMyOpenCodeWrapper
    omcWrapper
    omoWrapper
    omxWrapper
    opencodeWrapper
    piWrapper
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
    ".pi/agent/models.json".source = piModels;
    ".pi/agent/settings.json".source = piSettings;
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
