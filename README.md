# NixOS 配置

`bakaPC-NixOS` 的单机 Flake 配置，包含 KDE Plasma、niri、Home Manager、
NVIDIA PRIME、蓝牙和 Btrfs 等设置。

## 目录

```text
.
├── hosts/
│   └── bakaPC-NixOS/       # 本机入口、硬件、启动、显卡、存储与显示器配置
├── home/
│   └── baka/               # baka 的 Home Manager 配置和 dotfiles
├── modules/                # 可复用于其他主机的 NixOS 功能模块
├── pkgs/                   # 尚未进入 nixpkgs 的本地软件包
├── flake.nix               # Flake 输入、主机输出、格式器与检查
└── flake.lock              # 锁定依赖版本
```

目录按职责划分：`hosts/` 只放与具体机器绑定的 UUID、PCI Bus ID、主机名和显示器布局；
`home/` 只放用户软件与配置；`modules/` 不反向引用某台主机；`pkgs/` 只定义 derivation。
当前没有引入 flake-parts、overlay 或多层 profiles。

`hosts/bakaPC-NixOS/hardware-configuration.nix` 由安装工具生成，但仍需纳入 Git，构建时不会自动重建。
需要重新探测硬件时，先输出到临时文件并检查差异，避免覆盖人为模块：

```bash
nixos-generate-config --show-hardware-config > /tmp/hardware-configuration.nix
diff -u hosts/bakaPC-NixOS/hardware-configuration.nix /tmp/hardware-configuration.nix
```

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
