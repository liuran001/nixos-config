# age 加密秘密：仓库只保存密文，激活时用 baka 的 SSH 私钥解密到 /run/agenix。
{
  age = {
    identityPaths = [ "/home/baka/.ssh/id_ed25519" ];
    secrets.github-token = {
      file = ../secrets/github-token.age;
      owner = "baka";
      group = "users";
      mode = "0400";
    };
    secrets.oapi-api-key = {
      file = ../secrets/oapi-api-key.age;
      owner = "baka";
      group = "users";
      mode = "0400";
    };
  };
}
