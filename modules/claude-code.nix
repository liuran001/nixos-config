# Claude Code 的策略层：Linux 上 CLI 读 /etc/claude-code/managed-settings.json，
# 它优先级最高且 CLI 从不写入，适合放不允许被交互设置覆盖的铁律。
# 用户自己的 ~/.claude/settings.json 仍由 CLI 维护，/config、/model 等照常可写，
# 所以主题、模型这类经常调的偏好不要搬进来。
{ pkgs, ... }:

let
  jsonFormat = pkgs.formats.json { };

  managedSettings = jsonFormat.generate "claude-code-managed-settings.json" {
    # 提交与 PR 不携带 AI 署名。commit/pr 为空串隐藏署名文本；Claude-Session
    # 尾注是独立开关 sessionUrl（默认 true，只在 web 与 Remote Control 会话
    # 里追加），已废弃的 includeCoAuthoredBy 管不到它。
    attribution = {
      commit = "";
      pr = "";
      sessionUrl = false;
    };
  };
in
{
  environment.etc."claude-code/managed-settings.json".source = managedSettings;
}
