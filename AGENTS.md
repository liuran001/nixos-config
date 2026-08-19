# AGENTS.md

## Git 提交约定

- 提交信息用中文、semantic 前缀（`feat:` / `fix:` / `chore:` / `docs:` / `style:`）。
- **不要**添加任何 agent 署名尾注：不写 `Ultraworked with ...` 段落，不写
  `Co-authored-by: ...` trailer（用户明确要求，2026-08）。
- 明文秘密（API key、token、私钥）绝不入库；密钥走 agenix 密文 + `/run/agenix` 运行时注入。
