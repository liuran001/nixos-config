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
  librarianModel = "gemini-3.7-flash";
  deepseekModel = "deepseek-v4-pro";
  homeDirectory = "/home/baka";
  codexHome = "${homeDirectory}/.codex";
  oapiSecretFile = "/run/agenix/oapi-api-key";
  githubSecretFile = "/run/agenix/github-token";
  context7SecretFile = "/run/agenix/context7-api-key";
  tinyfishSecretFile = "/run/agenix/tinyfish-api-key";
  exaSecretFile = "/run/agenix/exa-api-key";
  tavilySecretFile = "/run/agenix/tavily-api-key";

  # MCP 服务的密钥文件表，包装器按 变量名 = 文件 注入进程环境；
  # 新增服务只需在这里和各 harness 的 MCP 服务器表各加一行。
  mcpSecretFiles = {
    CONTEXT7_API_KEY = context7SecretFile;
    TINYFISH_API_KEY = tinyfishSecretFile;
    EXA_API_KEY = exaSecretFile;
    TAVILY_API_KEY = tavilySecretFile;
  };

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
  ohMyOpenCodeSlimRoot = "${aiTools}/lib/node_modules/nixos-ai-tools/node_modules/oh-my-opencode-slim";
  ohMyOpenCodeSlimPlugin = "file://${ohMyOpenCodeSlimRoot}";
  # 复用 Claude Code 官方登录的 OAuth 凭据，为 OpenCode 提供 anthropic provider。
  opencodeClaudeAuthPlugin = "file://${pkgs.bakaPackages.opencode-claude-auth}";
  # 启动时从 /v1/models 动态发现模型列表，替代写死的 models 表。
  opencodeModelsDiscoveryPlugin = "file://${pkgs.bakaPackages.opencode-models-discovery}";

  jsonFormat = pkgs.formats.json { };
  tomlFormat = pkgs.formats.toml { };
  yamlFormat = pkgs.formats.yaml { };

  # 密钥只在目标进程启动时读取，不进入 Nix store 或全局会话环境。
  # readSecret 生成一段 shell：读取一个 agenix 明文文件并导出到一组环境变量，
  # 读取失败直接退出。供 mkSecretWrapper 与散装的 writeShellApplication 复用。
  readSecret = name: file: variables: ''
    secret_file=${lib.escapeShellArg file}
    if [[ ! -r "$secret_file" ]]; then
      printf '%s\n' ${lib.escapeShellArg "${name}: 无法读取 agenix 运行时密钥"} >&2
      exit 1
    fi

    secret_value="$(<"$secret_file")"
    if [[ -z "$secret_value" ]]; then
      printf '%s\n' ${lib.escapeShellArg "${name}: agenix 运行时密钥为空"} >&2
      exit 1
    fi

    ${lib.concatMapStringsSep "\n" (variable: ''export ${variable}="$secret_value"'') variables}
    unset secret_value
  '';

  # secretFile/secretVariables 是主密钥；extraSecrets 以 变量名 = 密钥文件
  # 的形式追加任意数量的次要密钥，读取失败同样直接退出。
  mkSecretWrapper =
    {
      name,
      executable,
      secretFile,
      secretVariables,
      extraSecrets ? { },
      environment ? { },
      arguments ? [ ],
    }:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        ${readSecret name secretFile secretVariables}
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (variable: file: readSecret name file [ variable ]) extraSecrets
        )}
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
  # API 密钥、端点或模型环境变量。MCP 密钥只用于 MCP 服务器认证。
  claudeWithPlugin = pkgs.writeShellApplication {
    name = "claude";
    text = ''
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (variable: file: readSecret "claude" file [ variable ]) mcpSecretFiles
      )}

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
    extraSecrets = mcpSecretFiles;
    environment = {
      DO_NOT_TRACK = "1";
      # OMO Slim 默认把专家任务派给后台子代理，这在 opencode 里还是实验特性，
      # 未开启时 orchestrator 无法派活（官方安装器把它写进 shell rc）。
      OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true";
    };
  };

  # 插件本体由 opencode 加载；这个 CLI 只用于 `oh-my-opencode-slim doctor`
  # 这类只读诊断，配置仍由下面的 ohMyOpenCodeSlimConfig 声明式生成。
  ohMyOpenCodeSlimWrapper = mkSecretWrapper {
    name = "oh-my-opencode-slim";
    executable = "${aiTools}/bin/oh-my-opencode-slim";
    secretFile = oapiSecretFile;
    secretVariables = [ "OPENAI_API_KEY" ];
    extraSecrets = mcpSecretFiles;
  };

  ompWrapper = mkSecretWrapper {
    name = "omp";
    executable = "${ompPackage}/bin/omp";
    secretFile = oapiSecretFile;
    secretVariables = [ "OPENAI_API_KEY" ];
    extraSecrets = mcpSecretFiles;
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
    extraSecrets = mcpSecretFiles;
    environment.OMX_AUTO_UPDATE = "0";
  };

  # OpenChamber 是 OpenCode 的图形前端，自己 fork 一个 opencode 服务端进程：
  # 桌面版固定用 AppImage 里自带的 resources/opencode-cli/opencode，Web CLI 按
  # settings.opencodeBinary 或 PATH 解析。这个子进程只继承前端自身的环境，而从
  # Plasma 菜单或普通 shell 启动时那里没有 agenix 密钥，于是 opencode.json 里的
  # {env:OPENAI_API_KEY} 和各 MCP 的 {env:*} 全部展开成空值：obdo 的模型发现被
  # /v1/models 判 401（界面上一个模型都没有），远程 MCP 也因空 Bearer 认证失败。
  # 因此这里和 opencode 一样用包装器注入，再由前端传给它 fork 的 opencode。
  openchamberDesktopPackage = pkgs.bakaPackages.openchamber-desktop;

  openchamberDesktopSecrets = mkSecretWrapper {
    name = "openchamber-desktop";
    executable = lib.getExe openchamberDesktopPackage;
    secretFile = oapiSecretFile;
    secretVariables = [ "OPENAI_API_KEY" ];
    extraSecrets = mcpSecretFiles;
    environment.OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true";
  };

  # .desktop 里的 Exec=openchamber-desktop 按 PATH 解析，所以 profile 里的
  # bin/openchamber-desktop 必须是包装器；菜单项与图标仍取自原包，两者整体安装
  # 会在同名文件上冲突，只能重新组装。
  openchamberDesktop = pkgs.runCommand "openchamber-desktop-wrapped" { } ''
    mkdir -p "$out/bin"
    ln -s ${openchamberDesktopSecrets}/bin/openchamber-desktop "$out/bin/openchamber-desktop"
    cp -r --no-preserve=mode ${openchamberDesktopPackage}/share "$out/share"
  '';

  openchamberWrapper = mkSecretWrapper {
    name = "openchamber";
    executable = lib.getExe pkgs.bakaPackages.openchamber-web;
    secretFile = oapiSecretFile;
    secretVariables = [ "OPENAI_API_KEY" ];
    extraSecrets = mcpSecretFiles;
    environment = {
      OPENCHAMBER_HOST = "0.0.0.0";
      OPENCHAMBER_ALLOW_UNAUTHENTICATED_LAN = "true";
      OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true";
    };
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

  # Codex 的模型提供方走 config.toml 的 auth.command 自读取，不需要 OPENAI_API_KEY；
  # 包装器只注入 MCP 认证用的环境变量（bearer_token_env_var/env_http_headers 引用）。
  codexWrapper = mkSecretWrapper {
    name = "codex";
    executable = lib.getExe pkgs.codex;
    secretFile = context7SecretFile;
    secretVariables = [ "CONTEXT7_API_KEY" ];
    extraSecrets = builtins.removeAttrs mcpSecretFiles [ "CONTEXT7_API_KEY" ];
  };

  # Kimi Code 同理：官方账号登录，包装器只补 MCP 用的环境变量。
  kimiWrapper = mkSecretWrapper {
    name = "kimi";
    executable = lib.getExe kimiPackage;
    secretFile = context7SecretFile;
    secretVariables = [ "CONTEXT7_API_KEY" ];
    extraSecrets = builtins.removeAttrs mcpSecretFiles [ "CONTEXT7_API_KEY" ];
  };

  # MCP 服务器定义：harness 之间只是占位符语法不同，共用同一组 URL 与
  # 环境变量引用，明文不落盘。
  context7McpUrl = "https://mcp.context7.com/mcp";
  context7McpAuthHeader = "Bearer \${CONTEXT7_API_KEY}";
  tinyfishMcpUrl = "https://agent.tinyfish.ai/mcp";
  exaMcpUrl = "https://mcp.exa.ai/mcp";
  tavilyMcpUrl = "https://mcp.tavily.com/mcp";

  # ${VAR} 展开语法的服务器表，omp 与 kimi 的 mcp.json 共用；
  # tinyfish 用 X-API-Key 头，其余用 Bearer。
  dollarMcpServers = {
    context7 = {
      type = "http";
      url = context7McpUrl;
      headers.Authorization = context7McpAuthHeader;
    };
    tinyfish = {
      type = "http";
      url = tinyfishMcpUrl;
      headers."X-API-Key" = "\${TINYFISH_API_KEY}";
    };
    exa = {
      type = "http";
      url = exaMcpUrl;
      headers.Authorization = "Bearer \${EXA_API_KEY}";
    };
    tavily = {
      type = "http";
      url = tavilyMcpUrl;
      headers.Authorization = "Bearer \${TAVILY_API_KEY}";
    };
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

    # 远程 MCP 服务器；codex 从环境变量取认证值（Bearer 用 bearer_token_env_var，
    # 自定义头用 env_http_headers），明文不进 config.toml。
    mcp_servers = {
      context7 = {
        url = context7McpUrl;
        bearer_token_env_var = "CONTEXT7_API_KEY";
      };
      tinyfish = {
        url = tinyfishMcpUrl;
        env_http_headers."X-API-Key" = "TINYFISH_API_KEY";
      };
      exa = {
        url = exaMcpUrl;
        bearer_token_env_var = "EXA_API_KEY";
      };
      tavily = {
        url = tavilyMcpUrl;
        bearer_token_env_var = "TAVILY_API_KEY";
      };
    };

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

  # OMP 原生 MCP 支持：~/.omp/agent/mcp.json，type 必须是 http，
  # ${VAR} 在连接时从进程环境展开。
  ompMcp = jsonFormat.generate "omp-mcp.json" {
    mcpServers = dollarMcpServers;
  };

  # Kimi Code 的用户级 MCP 配置。注意 kimi 的 mcp.json 不做 ${VAR} 展开
  # （会把字面量发出去导致 401），静态 Bearer 一律用 bearerTokenEnvVar
  # 引用环境变量；tinyfish 的 API key 同样接受 Bearer 形式。
  kimiMcp = jsonFormat.generate "kimi-mcp.json" {
    mcpServers = {
      context7 = {
        url = context7McpUrl;
        bearerTokenEnvVar = "CONTEXT7_API_KEY";
      };
      tinyfish = {
        url = tinyfishMcpUrl;
        bearerTokenEnvVar = "TINYFISH_API_KEY";
      };
      exa = {
        url = exaMcpUrl;
        bearerTokenEnvVar = "EXA_API_KEY";
      };
      tavily = {
        url = tavilyMcpUrl;
        bearerTokenEnvVar = "TAVILY_API_KEY";
      };
    };
  };

  # gpt-5.3 及以上的 OpenAI 模型上游只接受 responses 协议；obdo 网关为这些
  # 模型配有 responses 渠道，因此按模型覆盖回 @ai-sdk/openai（其余模型仍走
  # provider 默认的 chat/completions）。网关日后新增 gpt-5.x 时需要在这里补充。
  obdoResponsesModels = [
    "gpt-5.3-codex"
    "gpt-5.4"
    "gpt-5.4-mini"
    "gpt-5.5"
    "gpt-5.5-mini"
    "gpt-5.6-luna"
    "gpt-5.6-mini"
    "gpt-5.6-sol"
    "gpt-5.6-terra"
  ];

  # Anthropic 模型上游只接受 messages 协议；obdo 网关的 /v1/messages 端点
  # （与 apiBaseUrl 同前缀，接受 Bearer 与 x-api-key 两种鉴权）已为这些模型
  # 配好渠道，因此按模型覆盖成 @ai-sdk/anthropic。网关日后新增 claude 模型
  # 时需要在这里补充：opencode 的模型覆盖只认精确 id，没有前缀匹配。
  obdoMessagesModels = [
    "claude-fable-5"
    "claude-opus-4-6"
    "claude-opus-4-6-thinking"
    "claude-opus-4-8"
    "claude-opus-4.6"
    "claude-opus-4.8"
    "claude-opus-5"
    "claude-sonnet-4-6"
    "claude-sonnet-4.6"
  ];

  opencodeConfig = jsonFormat.generate "opencode.json" {
    model = "obdo/${defaultModel}";
    autoupdate = false;
    share = "disabled";
    plugin = [
      ohMyOpenCodeSlimPlugin
      opencodeClaudeAuthPlugin
      opencodeModelsDiscoveryPlugin
    ];
    # opencode 内置的 explore/general 与 OMO Slim 的 explorer 职责重复，
    # 官方安装器同样会关掉它们。
    agent = {
      explore.disable = true;
      general.disable = true;
    };
    # 远程 MCP 服务器，opencode 内所有 agent 共用；key 由包装器运行时注入，
    # 配置里只放 {env:} 占位符，明文不落 Nix store。
    mcp = {
      context7 = {
        type = "remote";
        url = context7McpUrl;
        headers.Authorization = "Bearer {env:CONTEXT7_API_KEY}";
      };
      tinyfish = {
        type = "remote";
        url = tinyfishMcpUrl;
        headers."X-API-Key" = "{env:TINYFISH_API_KEY}";
      };
      exa = {
        type = "remote";
        url = exaMcpUrl;
        headers.Authorization = "Bearer {env:EXA_API_KEY}";
      };
      tavily = {
        type = "remote";
        url = tavilyMcpUrl;
        headers.Authorization = "Bearer {env:TAVILY_API_KEY}";
      };
    };
    provider.obdo = {
      name = "Baka API";
      # 这个网关本质上是 chat/completions 网关：/v1/responses 只有少数模型
      # （如 gpt-5.6-sol）配有渠道，gemini 系等模型走 responses 会报
      # 「分组 auto 下模型 X 的可用渠道不存在」。AI SDK v5 的 @ai-sdk/openai
      # 默认走 responses API，所以改用 @ai-sdk/openai-compatible，让所有模型
      # 统一走 chat/completions；将来若有模型必须 responses/messages，可在
      # provider.obdo.models.<id>.provider.npm 单独覆盖成 @ai-sdk/openai 或
      # @ai-sdk/anthropic。
      npm = "@ai-sdk/openai-compatible";
      options = {
        baseURL = apiBaseUrl;
        apiKey = "{env:OPENAI_API_KEY}";
        # createOpenAICompatible 要求 name 参数。
        name = "bakaapi";
        # 模型列表由 opencode-models-discovery 插件从该端点动态发现，
        # 不再写死；enabled 同时是对该 provider 的强制发现开关。
        modelsDiscovery = {
          enabled = true;
          # /v1/models 只返回模型 id，不带上下文窗口等元数据，界面里的上下文
          # 长度会全部显示成 0。obdo 网关的元数据接口要面板 token，拿不到，
          # 因此改由 models.dev 按模型名补齐 limit/reasoning/modalities。
          # models.dev 未收录的模型保持原样，不会被过滤掉。
          modelInfoFormat = "models.dev";
        };
      };
      # 见上方 obdoResponsesModels / obdoMessagesModels 注释：这些模型分别
      # 覆盖成 responses 与 messages 协议。发现插件的 mergeModelOverride 是
      # 深合并，这里只写 provider.npm，不会丢发现来的
      # limit/reasoning/modalities 元数据。
      models =
        lib.genAttrs obdoResponsesModels (_: {
          provider.npm = "@ai-sdk/openai";
        })
        // lib.genAttrs obdoMessagesModels (_: {
          provider.npm = "@ai-sdk/anthropic";
        });
    };
  };

  opencodeTuiConfig = jsonFormat.generate "opencode-tui.json" {
    plugin = [
      ohMyOpenCodeSlimPlugin
      opencodeModelsDiscoveryPlugin
    ];
  };

  # OMO Slim 的配置读自 ~/.config/opencode/oh-my-opencode-slim.json，按 preset
  # 组织每个 agent 的模型和思考强度；agent 名取自插件内置的 orchestrator 与专家。
  ohMyOpenCodeSlimConfig = jsonFormat.generate "oh-my-opencode-slim.json" {
    # 包由 Nix 固定、配置由 Home Manager 只读管理，自更新只会失败。
    autoUpdate = false;
    # 插件内置的 context7 以 CONTEXT7_API_KEY 作请求头名，且与 opencode.json 里
    # 走 Bearer 认证的同名服务重复；统一用后者，只留免费的 gh_grep。
    disabled_mcps = [ "context7" ];
    preset = "obdo";
    presets.obdo =
      (lib.genAttrs
        [
          "orchestrator"
          "oracle"
          "explorer"
          "designer"
          "fixer"
        ]
        (_: {
          model = "obdo/${defaultModel}";
          variant = "xhigh";
        })
      )
      // {
        # 文档检索交给便宜的长上下文模型，并放开全部检索类 MCP
        # （默认只有 context7 与 gh_grep）。
        librarian = {
          model = "obdo/${librarianModel}";
          variant = "xhigh";
          mcps = [ "*" ];
        };
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
    claudeWithPlugin
    codexWrapper
    dshWrapper
    ghWrapper
    kimiWrapper
    ohMyClaudeCode
    ohMyOpenCodeSlimWrapper
    omxWrapper
    openchamberDesktop
    openchamberWrapper
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
    ".kimi-code/mcp.json".source = kimiMcp;
    ".omp/agent/mcp.json".source = ompMcp;
    ".omp/agent/models.yml".source = ompModels;
  };

  xdg.configFile = {
    "opencode/opencode.json".source = opencodeConfig;
    "opencode/tui.json".source = opencodeTuiConfig;
    "opencode/oh-my-opencode-slim.json".source = ohMyOpenCodeSlimConfig;
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
