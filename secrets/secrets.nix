# agenix 编辑规则；这里只包含公开的 SSH/age recipient，不包含任何明文秘密。
let
  # 日常解密身份：系统激活时由 root 读取 /home/baka/.ssh/id_ed25519 自动解密，
  # 对应 hosts/bakaPC-NixOS/secrets.nix 里的 age.identityPaths。
  baka = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDg6oLc5U6mO7Y8XdlvFSU8IMcBrjjlMfue6WoKWKW1A";

  # 灾难恢复身份：YubiKey PIV 槽位中的 age 密钥，只在上面那把私钥丢失时使用。
  # 插上 YubiKey 后依次执行（详见 README「密钥恢复」一节）：
  #   age-plugin-yubikey --generate --name nixos-recovery --touch-policy always
  #   age-plugin-yubikey --list
  # 把输出的 age1yubikey1... 整串填到下面，再从 secrets/ 目录运行 `agenix -r`
  # 将两份密文重新加密给两个收件人。
  #
  # 注意：不要把 YubiKey 写进 age.identityPaths。解密发生在系统激活期，
  # 那时无人可以按触摸键，开机会直接卡住。它只用于手工恢复。
  # 另外 age 不支持 FIDO2 形式的 sk-ssh-ed25519 密钥，必须走这里的 PIV 方案。
  yubikey = "age1yubikey1qw0eylfgr6xagvy4z8mt73q8jwgrvvdekx7u6jmrndpykthujm9q5dtld54";

  recipients =
    if yubikey == null then
      [ baka ]
    else
      [
        baka
        yubikey
      ];
in
{
  "github-token.age".publicKeys = recipients;
  "oapi-api-key.age".publicKeys = recipients;
  "context7-api-key.age".publicKeys = recipients;
  "tinyfish-api-key.age".publicKeys = recipients;
  "exa-api-key.age".publicKeys = recipients;
  "tavily-api-key.age".publicKeys = recipients;
  # pam_u2f 的凭据映射。内容是凭据句柄与公钥，本身不是机密（没有硬件私钥
  # 无法验证），但本仓库是公开的，加密存放可避免公开一个稳定的设备标识。
  "u2f-mappings.age".publicKeys = recipients;
}
