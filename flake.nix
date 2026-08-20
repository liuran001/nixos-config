# 本机的 NixOS flake 入口。
# 构建系统：`nixos-rebuild switch --flake /etc/nixos --sudo`
# 更新 nixpkgs 锁定版本：`nix flake update`（在 ~/nixos 目录下执行，然后重新构建）。
{
  description = "baka 的 NixOS 系统配置";

  inputs = {
    # 家用桌面优先获取新内核、驱动与应用；flake.lock 保留当前可复现快照。
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home Manager 跟随主线，并共用同一份 nixpkgs，避免重复求值。
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # age 加密的声明式秘密管理；跟随上游更新并复用本仓库的 nixpkgs/Home Manager。
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Codex Desktop 的社区 Nix 封装；跟随上游 main。
    # flake.lock 仍保留可复现快照，运行 `nix flake update` 时再前进到最新提交。
    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Desktop 的社区 Debian 封装；复用本仓库的 nixpkgs。
    claude-desktop-debian = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Code 编排插件直接跟随上游源码；具体提交仍由 lock 文件记录。
    oh-my-claudecode = {
      url = "github:Yeachan-Heo/oh-my-claudecode";
      flake = false;
    };

    # ASUS 笔记本控制工具；使用上游 NixOS 子 Flake，并通过锁文件跟随 master 更新。
    g-helper-linux = {
      # git URL 不依赖 GitHub API 限流；更新时仍解析 master 的最新提交。
      url = "git+https://github.com/utajum/g-helper-linux.git?ref=master&dir=nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Oh My Pi 自带 Home Manager 模块；跟随上游并复用本仓库的 nixpkgs。
    omp = {
      url = "github:can1357/oh-my-pi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      agenix,
      codex-desktop-linux,
      claude-desktop-debian,
      g-helper-linux,
      oh-my-claudecode,
      omp,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;

      # 仓库自封装软件包的 overlay；系统闭包与 packages 输出共用同一份定义，
      # 因此 `nix build .#kimi-code` 构建出的就是系统里实际安装的那一个。
      bakaOverlay = import ./pkgs/overlay.nix { ohMyClaudeCodeSource = oh-my-claudecode; };
      bakaPkgs = import nixpkgs {
        inherit system;
        overlays = [
          bakaOverlay
          claude-desktop-debian.overlays.default
        ];
        # 与 modules/packages.nix 保持一致，否则 Edge、VS Code 等包无法单独构建。
        config.allowUnfree = true;
      };

      formatter = pkgs.nixfmt-tree.override {
        settings.formatter.nixfmt.excludes = [ "hosts/bakaPC-NixOS/hardware-configuration.nix" ];
      };
      nixSources = pkgs.lib.fileset.toSource {
        root = ./.;
        fileset = pkgs.lib.fileset.fileFilter (
          file: file.hasExt "nix" && file.name != "hardware-configuration.nix"
        ) ./.;
      };
      nixosConfiguration = nixpkgs.lib.nixosSystem {
        inherit system;
        # oh-my-claudecode 的源码不再透传给模块，它由 pkgs/overlay.nix 接线。
        specialArgs = { inherit codex-desktop-linux g-helper-linux omp; };
        modules = [
          {
            nixpkgs.overlays = [
              bakaOverlay
              claude-desktop-debian.overlays.default
            ];
          }
          ./hosts/bakaPC-NixOS
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          { environment.systemPackages = [ agenix.packages.${system}.default ]; }
        ];
      };
    in
    {
      # `nix fmt` 递归整理所有手写 Nix 文件；自动生成的硬件配置保持原样。
      formatter.${system} = formatter;

      # 单独构建仓库里的自封装包，例如升级版本后先 `nix build .#douyin` 验证，
      # 不必每次都重建整个系统闭包。
      packages.${system} = bakaPkgs.bakaPackages;

      # modules/ 下的功能模块按文件名导出，方便以后第二台主机直接引用。
      # 从目录读取而不是手写清单，新增模块无需在这里登记。
      # 注意 ghelper 模块需要调用方提供 g-helper-linux 这个 specialArg。
      nixosModules = lib.mapAttrs' (
        file: _type: lib.nameValuePair (lib.removeSuffix ".nix" file) (./modules + "/${file}")
      ) (lib.filterAttrs (_file: type: type == "regular") (builtins.readDir ./modules));

      # 属性名与主机名一致，nixos-rebuild 会自动选择它。
      nixosConfigurations."bakaPC-NixOS" = nixosConfiguration;

      # `nix flake check` 同时验证格式并构建完整系统闭包。
      checks.${system} = {
        formatting = pkgs.runCommand "check-nix-formatting" { nativeBuildInputs = [ formatter ]; } ''
          cp -r ${nixSources}/. source
          chmod -R u+w source
          cd source
          treefmt --tree-root . --ci
          touch "$out"
        '';
        system = nixosConfiguration.config.system.build.toplevel;
      };
    };
}
