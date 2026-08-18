# NixOS 配置

`bakaPC-NixOS` 的单机 Flake 配置，包含 KDE Plasma、niri、Home Manager、
NVIDIA PRIME、蓝牙和 Btrfs 等设置。

## 目录

- `configuration.nix`：系统入口与人为选择的文件系统策略。
- `hardware-configuration.nix`：安装时自动生成的本机硬件与分区信息。
- `modules/`：按功能拆分的系统、桌面和用户配置。
- `modules/dotfiles/`：由 Home Manager 管理的用户配置文件。
- `pkgs/`：尚未进入 nixpkgs 的本地软件包。

当前只有一台主机，`hardware-configuration.nix` 放在根目录并纳入 Git 是标准且直观的布局。
它不会在每次构建时自动生成；只有手动运行 `nixos-generate-config` 才可能覆盖它。
如果以后管理多台机器，再把主机入口和硬件配置一起迁到 `hosts/<hostname>/`。

## 修改与验证

在仓库目录中依次运行：

```bash
# 检查格式；去掉 -- --ci 可直接修正格式
nix fmt -- --ci

# 快速求值所有 flake 输出，不执行构建
nix flake check --no-build --no-write-lock-file --show-trace

# 完整检查：格式检查 + 系统闭包构建
nix flake check --no-write-lock-file --show-trace
```

临时激活配置，不写入下次启动项：

```bash
nixos-rebuild test --flake /etc/nixos --sudo
```

确认正常后永久切换：

```bash
nixos-rebuild switch --flake /etc/nixos --sudo
```

涉及内核或 NVIDIA 驱动更新时，建议先只写入下次启动项并重启：

```bash
nixos-rebuild boot --flake /etc/nixos --sudo
```

Bash 别名 `nrt`、`nrb`、`nrs` 分别对应上述 test、boot、switch 命令。

## 更新与回退

```bash
nix flake update
git diff -- flake.lock
nix flake check --no-write-lock-file --show-trace
```

更新通过后再 test、boot 或 switch。当前系统异常时可运行
`nixos-rebuild switch --rollback --sudo`；无法进入桌面时，从 GRUB 选择较早的 NixOS 代际。

每周自动清理 30 天前的旧代际，因此重要回退点仍应通过 Git commit 保存。
不要把 Wi-Fi 密码、API token、私钥或密码哈希明文提交到仓库；需要声明秘密时再引入
agenix 或 sops-nix。
