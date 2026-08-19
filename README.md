# NixOS 配置

`bakaPC-NixOS` 的单机 Flake 配置，系统跟随 `nixos-unstable`，Home Manager
跟随主线；包含 KDE Plasma、niri、NVIDIA PRIME、蓝牙、Btrfs、Waydroid、
G-Helper 和 AI 开发工具等设置。

## 目录

```text
.
├── hosts/
│   └── bakaPC-NixOS/       # 本机入口、硬件、启动、显卡、电源、存储与显示器配置
├── home/
│   └── baka/               # baka 的 Home Manager 配置和 dotfiles
├── modules/                # 可复用于其他主机的 NixOS 功能模块
├── pkgs/                   # 外部发行包和需要本地适配的软件
│   ├── overlay.nix          # 把上述包挂到 pkgs.bakaPackages 命名空间
│   └── ghelper/             # G-Helper 包装、NixOS 适配和安全补丁
├── secrets/                # agenix 密文与公开 recipient 规则
├── flake.nix               # Flake 输入、主机输出、格式器与检查
└── flake.lock              # 锁定依赖版本
```

目录按职责划分：`hosts/` 只放与具体机器绑定的 UUID、PCI Bus ID、主机名、显示器布局和
`system.stateVersion`；`home/` 只放用户软件与配置；`modules/` 不反向引用某台主机，
其中的用户组由主机的 `users.nix` 决定成员；`pkgs/` 只定义 derivation。
当前没有引入 flake-parts 或多层 profiles。

[`pkgs/overlay.nix`](pkgs/overlay.nix) 是唯一的 overlay，把仓库自封装的包统一挂到
`pkgs.bakaPackages` 下，供 NixOS 模块、Home Manager 和 flake 的 `packages` 输出共用同一份
定义。用命名空间而不是覆盖 nixpkgs 顶层属性，是因为 `pkgs/bilibili.nix` 这类包本身就以
nixpkgs 的同名包为输入，直接覆盖会造成无限递归。`pkgs/ghelper` 不在 overlay 里，
它需要 `config.hardware.nvidia.package`，只能在模块内 `callPackage`。

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

# 只构建单个自封装包，用于升级版本或改 hash 后先行验证
nix build .#kimi-code
nix flake show   # 列出全部可单独构建的包
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

AI 配置集中在 [`home/baka/ai.nix`](home/baka/ai.nix)。Codex、OpenCode、Pi
及其编排工具默认通过 `https://oapi.obdo.cc/v1` 使用 `gpt-5.6-sol`；
DeepSeek Harness 单独使用 `deepseek-v4-pro`。Claude Code 与 Kimi Code 不使用
这个第三方端点或密钥，保留各自官方账号登录。当前提供以下入口：

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

需要 OAPI 的配置或包装器只在目标进程启动时读取密钥，不把它写入 Nix store 或全局会话环境；
Claude 与 Kimi 不读取该密钥。
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

### 密钥恢复（YubiKey）

`/home/baka/.ssh/id_ed25519` 是唯一能自动解密的身份。它一旦丢失，仓库里的 `.age`
密文将永久无法解密，因此 [`secrets/secrets.nix`](secrets/secrets.nix) 预留了第二收件人：
YubiKey PIV 槽位中的 age 密钥。插上 YubiKey 后执行：

```bash
# 在 PIV 槽位生成 age 密钥，每次解密都要求触摸
age-plugin-yubikey --generate --name nixos-recovery --touch-policy always

# 取回 age1yubikey1... 收件人字符串
age-plugin-yubikey --list
```

把输出填进 `secrets/secrets.nix` 的 `yubikey`，再重新加密并提交：

```bash
cd secrets
agenix -r
```

日后恢复时，导出身份文件再直接用 age 解密：

```bash
age-plugin-yubikey --identity > /run/user/1000/yubikey-identity.txt
age -d -i /run/user/1000/yubikey-identity.txt secrets/oapi-api-key.age
```

几点约束：

- **不要**把 YubiKey 写进 `age.identityPaths`。解密发生在系统激活期，
  那时没有人能按触摸键，开机会直接卡住；它只用于手工恢复。
- age 不支持 FIDO2 形式的 `sk-ssh-ed25519` 密钥，必须走 PIV 方案。
- PIV 依赖 PC/SC，`services.pcscd` 已在 [`hosts/bakaPC-NixOS/secrets.nix`](hosts/bakaPC-NixOS/secrets.nix) 中启用。
- agenix 内部调用上游 `age`，它按 PATH 查找 `age-plugin-*`，因此插件装在系统环境里。
- baka 的 SSH 私钥仍应离线备份一份；两个收件人同时丢失依然不可恢复。

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

## 显卡与电源

本机是 Intel 核显加 NVIDIA 独显的混合显卡笔记本，桌面由核显渲染，
需要独显的程序用 `nvidia-offload` 启动。两侧各自负责：

- [`graphics.nix`](hosts/bakaPC-NixOS/graphics.nix) 提供核显的 VA-API 栈
  （`intel-media-driver`、`vpl-gpu-rt`），并把 `LIBVA_DRIVER_NAME` 固定为 `iHD`。
  少了它浏览器和播放器只能软解视频，CPU 占用与耗电明显升高。
  用 `vainfo` 确认能列出 H.264/HEVC/AV1 的 profile。
- [`nvidia.nix`](hosts/bakaPC-NixOS/nvidia.nix) 除挂起/唤醒电源管理外还开启了
  `powerManagement.finegrained`，独显空闲时整卡进入 D3cold。
  用 `cat /sys/bus/pci/devices/0000:02:00.0/power/runtime_status` 检查，
  空闲时应为 `suspended`；只开 `powerManagement.enable` 时它会长期停在 `active`。

风扇曲线、功耗上限（PPT）、MUX 和性能档由 G-Helper 独占，
`power-profiles-daemon` 已关闭，原因见下一节。

## KDE 触摸板

内置触摸板的自然滚动位于 [`home/baka/kde.nix`](home/baka/kde.nix)，由 Home Manager
激活项 `kdeTouchpadNaturalScroll` 精确写入该设备的 KWin/libinput 配置，不会反转外接鼠标滚轮。
更换触摸板或设备 ID 变化后，需要同步更新文件中的设备组。

## 截图与 OCR

Plasma 默认的 Spectacle 已替换为带 Tesseract OCR 的构建，支持英文、简体中文、繁体中文、
日语横排和日语竖排（`eng`、`chi_sim`、`chi_tra`、`jpn`、`jpn_vert`）。系统也提供
`tesseract` 命令行工具；Flameshot 及其 Home Manager 配置已移除。日语只用于图片文字识别，
不会给 Fcitx 添加日文输入法，也不会改变系统或 KDE 的界面语言。

## 微信

微信官方 Linux 版以 AppImage 分发，运行在 XWayland 上，内部有两套渲染进程，
输入法通道不同，[`pkgs/wechat.nix`](pkgs/wechat.nix) 在 nixpkgs 的包之上把两条都补齐：

- **主窗口**是静态链接 Qt 5 的 CEF 应用，已把 fcitx5-qt 的输入上下文编译进去
  （二进制里有 `QPlatformInputContextFactoryInterface.5.1` 和构建路径
  `third_party/fcitx-qt5/`），通过 DBus 的 `org.fcitx.Fcitx5` 通信，
  只需要 `QT_IM_MODULE=fcitx` 把它选中。
- **小程序与内置浏览器**是独立的 Chromium 进程 `RadiumWMPF/WeChatAppEx`，
  走 GTK 输入法通道。它只实现 `zwp_text_input_v1`，而 KWin 只提供 v2/v3，
  拿不到 Wayland 原生输入法；而 AppImage 的 FHS 环境里没有 fcitx5 的 immodule，
  GTK 3 又只认 `immodules.cache`。因此构建期用 `gtk-query-immodules-3.0` 生成
  一份只含 fcitx5 的缓存，用 `GTK_IM_MODULE_FILE` 指给微信，GTK 4 则用 `GTK_PATH`。
  bwrap 绑定了整个 `/nix`，store 路径在沙箱内可直接访问；fcitx5-gtk 与 FHS 环境里的
  GTK 3 来自同一份 nixpkgs，ABI 一致。

[`modules/i18n.nix`](modules/i18n.nix) 用 Wayland 原生前端、有意不设全局
`QT_IM_MODULE` 与 `GTK_IM_MODULE`（避免干扰原生 Wayland 程序），
所以这些变量只对微信生效。修改后需要从托盘完整退出微信再重新打开。

微信自带截图在 1.25 倍缩放下会整体向左上偏移：它按 X11 根窗口坐标取图，
而 KWin 给 XWayland 设的是 `Scale=1.25`（X11 程序自行缩放），微信没有正确处理这个倍率。
它只编译了 xcb 平台插件，无法改走原生 Wayland，因此这个偏移无法从 NixOS 侧消除。
两个可行方向：

- 用系统的 Spectacle 截图（已配置 OCR），复制到剪贴板后粘进微信，行为完全正常。
- 或在「系统设置 → 显示和监视器 → 旧版应用程序 (X11)」改为由系统缩放
  （即 `kwinrc` 的 `[Xwayland] Scale=1`）。这样几何关系一致，截图正确，
  但所有 XWayland 程序都会被 KWin 放大而略微模糊，IDEA、Android Studio 也受影响。

## 抖音

[`pkgs/douyin.nix`](pkgs/douyin.nix) 打包的是第三方 Electron 壳，不是官方客户端。
除了修正上游硬编码的 `/opt` 自启动路径，还修了一处上游逻辑 bug：
`dy.js` 的 `setWindowOpenHandler` 默认分支返回 `action: 'deny'`，却同时给出
`overrideBrowserWindowOptions`，而后者只在 `'allow'` 时生效。结果所有没被前面特判的
`window.open` 都被静默拦掉，表现为「设置」等弹窗页面点了没反应。
补丁只改这一处（`overrideBrowserWindowOptions` 全文仅出现一次），
其余三类 deny 分支（`bytedance://` 协议、跳外部浏览器、主窗口内加载）保持原样，
并在构建期前后各校验一次，上游改版导致补丁失效时构建会直接失败。

注意上游给弹窗设的 `webPreferences` 是 `nodeIntegration: true`、
`contextIsolation: false`、`webSecurity: false`，与主窗口同样宽松；
放开弹窗等于把这套设置也应用到弹出的页面上。

## G-Helper

[`pkgs/ghelper/default.nix`](pkgs/ghelper/default.nix) 负责包装 G-Helper 上游 `master` 的源码，
具体提交由 `flake.lock` 记录；[`modules/ghelper.nix`](modules/ghelper.nix) 只负责 NixOS 系统
集成。没有导入上游 NixOS 模块中的 `NOPASSWD` sudo 规则，也没有采用把设备节点
设为 `0666` 的宽松规则：风扇、功耗、充电阈值和 ASUS 外设节点只允许 `root`、当前 seat 或
`ghelper` 组访问；GPU helper 需要时通过 Polkit 交互认证。

本机 FX608LM 的 ASUS WMI、MUX、Dynamic Boost、CPU/GPU 功耗限制和两组 8 点风扇曲线均可由
当前内核暴露给 G-Helper。首次部署后需要注销并重新登录，让新增的 `ghelper`、`input` 组生效，
然后从应用菜单启动 G-Helper。NVIDIA PRIME 的显示路径和驱动仍由 NixOS 管理；G-Helper 仅使用
ASUS WMI 后端，不创建 modprobe 黑名单或额外 udev 规则。经 Polkit 确认的 GPU 模式保存在
`/var/lib/ghelper-nixos`，由 `ghelper-apply-state` 在开机时校验 MUX、设备占用和驱动状态后安全恢复；
不满足条件时保留待处理状态而不会强制关闭独显。
`services.power-profiles-daemon` 已在 [`modules/ghelper.nix`](modules/ghelper.nix) 中关闭。
G-Helper 直接写 `platform_profile`、`intel_pstate/no_turbo` 和 CPU 的
`energy_performance_preference`，而 PPD 也在管这三者：两边都写同一批 sysfs 节点，
谁后写谁生效，表现为在 G-Helper 里选好的性能档会被 KDE 电源部件悄悄改回去。
代价是 KDE 电源管理里的三档性能切换会消失，改由 G-Helper 界面控制。
若想反过来让 PPD 主管，删除该选项，并从 `setHardwarePermissions` 里去掉上面三类节点。

G-Helper 的 NixOS 内置更新和系统文件修复入口也在构建阶段禁用，避免它下载并以 root
执行上游安装脚本，或另行写入 udev/sudoers 配置；软件与系统集成只通过本仓库的
`flake.lock` 和 NixOS 重建更新。

## 更新与回退

系统、驱动和 nixpkgs 内的软件跟随 `nixos-unstable`，Home Manager、G-Helper、
Oh My Pi 与 Oh My ClaudeCode 等输入跟随各自上游分支。`flake.lock` 不是禁止更新的版本钉死，
而是一次可验证、可回退的依赖快照；每次执行更新命令时会整体前进到当时的最新提交：

```bash
nix flake update
git diff -- flake.lock
nix flake check --no-write-lock-file --show-trace
```

QQ 等已由 nixpkgs 维护的软件直接使用滚动包。`.deb`、AppImage、官方二进制和 npm 依赖仍必须
保留版本、hash 或 lockfile，否则 Nix 无法验证下载内容；这些固定值在上游发布新版本时随配置
一起更新。应用内自更新保持关闭，因为 Nix store 只读，绕过 Nix 更新会产生两套相互冲突的安装。
`system.stateVersion` 与 `home.stateVersion` 只控制数据迁移兼容性，不代表软件版本，不随滚动频道修改。

`nix build`、`nixos-rebuild build` 生成的 `result`/`result-*` 只是指向 Nix store 的临时符号链接，
已由 `.gitignore` 排除，不需要放进仓库。

更新通过后再 test、boot 或 switch。当前系统异常时可运行
`nixos-rebuild switch --rollback --sudo`；无法进入桌面时，从 GRUB 选择较早的 NixOS 代际。

`/boot` 是 500 MiB 的 ESP，每个代际的内核加 initrd 约 58 MiB，因此 GRUB 菜单只保留
最近 5 个代际（`boot.loader.grub.configurationLimit`）。旧代际本身仍在 store 里，
用 `nixos-rebuild switch --rollback` 或 `nix profile history` 仍可回退，只是不出现在启动菜单。
调高这个上限前先看 `df -h /boot`，否则内核升级会在拷贝阶段撞上 ENOSPC。

系统由代际回滚保护，`/home` 由 snapper 的时间线快照保护（见
[`storage.nix`](hosts/bakaPC-NixOS/storage.nix)），可用 `snapper -c home list` 查看、
`snapper -c home undochange <前>..<后> <路径>` 回滚。快照与系统同盘，不能代替异地备份。

每周自动清理 30 天前的旧代际，因此重要回退点仍应通过 Git commit 保存。
不要把 Wi-Fi 密码、API token、私钥、密码哈希或任何解密后的 agenix 内容提交到仓库。
