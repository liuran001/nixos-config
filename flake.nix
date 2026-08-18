# 本机的 NixOS flake 入口。
# 构建系统：`sudo nixos-rebuild switch --flake /etc/nixos`
# 更新 nixpkgs 锁定版本：`nix flake update`（在 ~/nixos 目录下执行，然后重新构建）。
{
  description = "baka 的 NixOS 系统配置";

  inputs = {
    # 与安装时使用的 channel 保持一致；锁定版本记录在 flake.lock 中。
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs }: {
    # 属性名与主机名一致，nixos-rebuild 会自动选择它。
    nixosConfigurations."bakaPC-NixOS" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
    };
  };
}
