# NixOS 配置

`bakaPC-NixOS` 的单机 Flake 配置，包含 KDE Plasma、niri、Home Manager、
NVIDIA PRIME、蓝牙、Btrfs、Waydroid 和 AI 开发工具等设置。

## 目录

```text
.
├── hosts/
│   └── bakaPC-NixOS/       # 本机入口、硬件、启动、显卡、存储与显示器配置
├── home/
│   └── baka/               # baka 的 Home Manager 配置和 dotfiles
├── modules/                # 可复用于其他主机的 NixOS 功能模块
├── pkgs/                   # 尚未进入 nixpkgs 的本地软件包
├── secrets/                # agenix 密文与公开 recipient 规则
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

## AI 工具与密钥

AI 配置集中在 [`home/baka/ai.nix`](home/baka/ai.nix)，默认通过
`https://oapi.obdo.cc/v1` 使用 `gpt-5.6-sol`；DeepSeek Harness 单独使用
`deepseek-v4-pro`。当前提供以下入口：

- Codex CLI、Codex Desktop 与 Oh My Codex（`omx`）；
- Claude Code 与 Oh My ClaudeCode（`claude`、`omc`）；
- OpenCode 与 Oh My OpenCode（`opencode`、`oh-my-opencode`、`omo-agent-toolkit`）；
- Pi 与 Oh My Pi（`pi`、`omp`）；
- DeepSeek Harness（`dsh`）和 Kimi Code。

Codex 已启用原生 subagent v2，主代理与子代理默认均为 `gpt-5.6-sol`、
`ultra` 推理强度。当前还设置了 `approval_policy = "never"` 和
`sandbox_mode = "danger-full-access"`：Codex 可以在 baka 用户权限范围内直接读写任意路径、
执行程序和访问网络，并且不会逐次请求确认。不要在不可信仓库或含有未知指令的文件中启动；
需要收紧时，将其改为 `on-request` 与 `workspace-write` 后重新部署。

API key 与 GitHub token 由 [`agenix`](hosts/bakaPC-NixOS/secrets.nix) 管理。仓库只保存 `.age` 密文，
激活时以 baka、`0400` 权限解密到：

```text
/run/agenix/oapi-api-key
/run/agenix/github-token
```

各 AI 配置或包装器只在目标进程启动时读取 OAPI key，不把它写入 Nix store 或全局会话环境。
首次部署前确认 `/home/baka/.ssh/id_ed25519` 对应
[`secrets/secrets.nix`](secrets/secrets.nix) 中的 recipient，然后从 `secrets/` 目录编辑密文：

```bash
cd secrets
agenix -e oapi-api-key.age
agenix -e github-token.age

# recipient 变化后重加密全部秘密
agenix -r
```

编辑完成后正常运行 `nixos-rebuild test` 或 `switch`。不要把编辑器临时文件、解密结果、
环境变量转储或命令输出提交到 Git。

GitHub token 只注入 `gh`，用于 GitHub API 和 CLI 认证；Git 拉取与推送仍走 SSH，
不使用该 token。令牌应采用最小权限，并在离开可信加密通道、权限变更或设备丢失后立即撤销轮换。
初始令牌曾通过交互渠道传递，应视为已经暴露：部署完成后在 GitHub 撤销旧令牌，生成新令牌，
再用 `agenix -e github-token.age` 更新密文。可用 `gh auth status` 验证身份，不要打印令牌本身。

## Waydroid、GMS 与 KernelSU

[`modules/virtualisation.nix`](modules/virtualisation.nix) 启用了 Waydroid，并让
`waydroid-gapps-init.service` 在容器首次启动前执行 `waydroid init -s GAPPS`。
第一次部署需要稳定网络下载较大的 Android GAPPS 镜像，最长等待 30 分钟；可用以下命令观察：

```bash
systemctl status waydroid-gapps-init.service
journalctl -u waydroid-gapps-init.service -f
```

GAPPS 镜像包含 Google Play 服务（GMS）和 Play 商店。完整的现有镜像与用户数据会被保留，
不会在后续重建中自动覆盖。初始化脚本会识别下载中断留下的不完整状态，可直接重试而无需
使用会重置现有安装的 `waydroid init -f`：

```bash
sudo systemctl restart waydroid-gapps-init.service
sudo systemctl restart waydroid-container.service
```

Waydroid 属于非认证 Android 设备。Play 商店若提示“设备未通过 Play 保护机制认证”，需要取得
该实例的 Google Services Framework Android ID，并在 Google 的
[未认证设备登记页](https://www.google.com/android/uncertified/)登记：

```bash
sudo waydroid shell -- sh -c "sqlite3 /data/data/*/*/gservices.db 'select value from main where name = \"android_id\";'"
waydroid session stop
waydroid show-full-ui
```

登记后通常需要等待几分钟再重启会话；命令来自
[Waydroid 官方认证说明](https://docs.waydro.id/faq/google-play-certification)。登记只能处理设备认证提示，
不保证 Play Integrity、DRM、银行或游戏反作弊检查通过。

KernelSU 当前未启用。Waydroid 共享宿主 NixOS 内核，并没有可单独替换的 Android 内核；
启用 KernelSU 必须给宿主内核加入实验性 root 补丁，会扩大整台主机的攻击面，且当前
x86_64/新内核组合存在兼容性与稳定性风险。本仓库不会把未经验证的宿主内核补丁标注成
“KernelSU 支持”；如需实验，应使用可回退的独立测试内核或虚拟机。

## KDE 触摸板

内置触摸板的自然滚动位于 [`home/baka/kde.nix`](home/baka/kde.nix)，由 Home Manager
激活项 `kdeTouchpadNaturalScroll` 精确写入该设备的 KWin/libinput 配置，不会反转外接鼠标滚轮。
更换触摸板或设备 ID 变化后，需要同步更新文件中的设备组。

## 更新与回退

```bash
nix flake update
git diff -- flake.lock
nix flake check --no-write-lock-file --show-trace
```

更新通过后再 test、boot 或 switch。当前系统异常时可运行
`nixos-rebuild switch --rollback --sudo`；无法进入桌面时，从 GRUB 选择较早的 NixOS 代际。

每周自动清理 30 天前的旧代际，因此重要回退点仍应通过 Git commit 保存。
不要把 Wi-Fi 密码、API token、私钥、密码哈希或任何解密后的 agenix 内容提交到仓库。
