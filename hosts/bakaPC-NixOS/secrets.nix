# 本机 age 秘密：使用 baka 的 SSH 私钥，在激活时解密到 /run/agenix。
{ pkgs, ... }:

{
  age = {
    # 只列出无需交互的身份。YubiKey 属于恢复用途，绝不能写进这里：
    # 解密发生在系统激活期，那时没有人能按触摸键，开机会直接卡住。
    identityPaths = [ "/home/baka/.ssh/id_ed25519" ];
    secrets.github-token = {
      file = ../../secrets/github-token.age;
      owner = "baka";
      group = "users";
      mode = "0400";
    };
    secrets.oapi-api-key = {
      file = ../../secrets/oapi-api-key.age;
      owner = "baka";
      group = "users";
      mode = "0400";
    };
  };

  # 第二收件人使用 YubiKey 的 PIV 槽位（见 secrets/secrets.nix）。
  # agenix 0.15 内部调用上游 age，而 age 会在 PATH 中查找 age-plugin-* 可执行文件，
  # 因此插件必须装进系统环境，agenix 才能加密给 age1yubikey1... 收件人。
  environment.systemPackages = with pkgs; [
    # agenix 自带 age，但恢复流程要直接调用它，因此单独装一份到系统环境。
    age
    age-plugin-yubikey # age 的 YubiKey PIV 插件，提供 --generate/--list/--identity
    yubikey-manager # ykman，用于查看槽位、设置 PIN/PUK
  ];

  # PIV 走 PC/SC 智能卡接口，没有 pcscd 时插件读不到 YubiKey。
  services.pcscd.enable = true;
  # YubiKey 的 udev 规则，让普通用户无需 root 也能访问设备。
  services.udev.packages = [ pkgs.yubikey-personalization ];
}
