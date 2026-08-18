# agenix 编辑规则；这里只包含公开的 SSH recipient，不包含任何明文秘密。
let
  baka = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDg6oLc5U6mO7Y8XdlvFSU8IMcBrjjlMfue6WoKWKW1A";
in
{
  "oapi-api-key.age".publicKeys = [ baka ];
}
