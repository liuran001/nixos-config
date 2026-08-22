# YubiKey 免密验证（FIDO2 / pam_u2f）：覆盖 sudo、图形提权、登录与锁屏。
#
# 凭据由 pamu2fcfg 在本机注册，策略为 +presence：只要求物理触摸，不要求
# FIDO2 PIN。这意味着钥匙插在机器上时，任何能碰到键盘的人都能提权和登录——
# 相当于把凭据从「知道密码」换成了「物理在场」。离开时应拔下钥匙。
{ config, pkgs, ... }:

let
  sudoYubikeyNotification = pkgs.writeShellScript "sudo-yubikey-notification" ''
    # pam_exec runs this as root; all notification failures are intentionally ignored.
    if [ "''${PAM_TYPE:-}" != auth ]; then
      exit 0
    fi

    requester="''${PAM_RUSER:-}"
    if [ -z "$requester" ] || [ "$requester" = root ]; then
      requester="''${SUDO_USER:-}"
    fi
    if [ -z "$requester" ] || [ "$requester" = root ]; then
      exit 0
    fi

    uid="$(${pkgs.coreutils}/bin/id -u -- "$requester" 2>/dev/null)" || exit 0
    case "$uid" in
      *[!0-9]*) exit 0 ;;
    esac

    runtime_dir="/run/user/$uid"
    bus="$runtime_dir/bus"
    [ -S "$bus" ] || exit 0

    ${pkgs.util-linux}/bin/runuser --user "$requester" -- \
      ${pkgs.coreutils}/bin/env \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
        XDG_RUNTIME_DIR="$runtime_dir" \
        ${pkgs.libnotify}/bin/notify-send -t 5000 \
          "sudo：请触摸 YubiKey" "sudo 正在等待 YubiKey 验证" \
      >/dev/null 2>&1 || true

    exit 0
  '';
in

{
  security.pam.u2f = {
    enable = true;

    # sufficient：验证通过即放行，失败则继续走密码。
    # 不用 required：那会让「没插钥匙」变成无法登录，映射文件一旦出问题就把
    # 自己锁在系统外；agenix 解密失败时也能靠密码进得去。
    control = "sufficient";

    settings = {
      # 映射由 agenix 解密到 /run/agenix（见 secrets.nix），不放明文进公开仓库。
      authfile = config.age.secrets.u2f-mappings.path;
      # 提示「请触摸」，否则终端会静默等待，看起来像卡死。
      cue = true;
      # 必须与注册时 pamu2fcfg 的 -o/-i 完全一致，显式固定而不依赖主机名解析。
      origin = "pam://bakaPC-NixOS";
      appid = "pam://bakaPC-NixOS";
    };
  };

  # security.pam.u2f.enable 会成为所有 PAM 服务的默认值，因此 sudo、polkit-1、
  # sddm、kde（Plasma 锁屏）、login、swaylock 都已自动覆盖，无需逐个声明。
  # 但修改凭据本身的服务不接受「摸一下」代替「知道当前密码」。
  security.pam.services = {
    passwd.u2f.enable = false;
    chpasswd.u2f.enable = false;
    chsh.u2f.enable = false;

    sudo.rules.auth.sudo-yubikey-notification = {
      # 在内置 u2f 规则前提示用户；optional 不影响认证结果。
      order = config.security.pam.services.sudo.rules.auth.u2f.order - 10;
      control = "optional";
      modulePath = "${pkgs.linux-pam}/lib/security/pam_exec.so";
      args = [
        "quiet"
        "${sudoYubikeyNotification}"
      ];
    };

    # KWallet 免弹窗解锁。pam_kwallet5 默认在 auth 阶段截获登录密码、
    # session 阶段用它解锁 kdewallet；u2f 登录不经过密码（sufficient
    # 直接短路，kwallet 连 auth 阶段都不会执行），session 阶段没有口令
    # 可用便整体跳过。forceRun 让 session 阶段无条件执行并以空口令解锁，
    # 配合空密码的 kdewallet 即不再弹窗。
    # 前置条件：kwalletmanager → kdewallet → 修改密码 → 留空。
    # 权衡：本机无全盘加密，钱包文件本就只受文件系统权限保护，空密码与
    # +presence 模型一致；代价是任何以 baka 运行的本地进程都能静默读取
    # 钱包全部内容。挂在 login 上：sddm 的 auth/session 分别 substack、
    # include login，TTY 登录也一并生效。
    login.kwallet = {
      enable = true;
      forceRun = true;
    };
  };
}
