# 本机的 NixOS flake 入口。
# 构建系统：`sudo nixos-rebuild switch --flake /etc/nixos`
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
  };

  outputs = { self, nixpkgs, home-manager }: {
    # 属性名与主机名一致，nixos-rebuild 会自动选择它。
    nixosConfigurations."bakaPC-NixOS" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
      ];
    };
  };
}
