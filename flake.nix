# 本机的 NixOS flake 入口。
# 构建系统：`nixos-rebuild switch --flake /etc/nixos --sudo`
# 更新 nixpkgs 锁定版本：`nix flake update`（在 ~/nixos 目录下执行，然后重新构建）。
{
  description = "baka 的 NixOS 系统配置";

  inputs = {
    # 与安装时使用的 channel 保持一致；锁定版本记录在 flake.lock 中。
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # home-manager：管理用户级配置（~/.config 点文件等），版本与 nixpkgs 保持一致，
    # 并共用同一份 nixpkgs，避免重复求值。
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Codex Desktop 的社区 Nix 封装；固定提交以避免上游 main 变动造成不可复现构建。
    # 保留它自己的 nixpkgs 锁定版本，因为封装会审计并修补官方 Electron 二进制。
    codex-desktop-linux.url = "github:ilysenko/codex-desktop-linux/1875dc2eaab6f9448617d18d0eda58902edf0f1a";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      codex-desktop-linux,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
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
        specialArgs = { inherit codex-desktop-linux; };
        modules = [
          ./hosts/bakaPC-NixOS
          home-manager.nixosModules.home-manager
        ];
      };
    in
    {
      # `nix fmt` 递归整理所有手写 Nix 文件；自动生成的硬件配置保持原样。
      formatter.${system} = formatter;

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
