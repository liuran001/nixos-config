# 系统字体：中西文常用字体、Noto CJK、文泉驿、Emoji，以及 fontconfig 默认字体配置。
{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      noto-fonts # Noto 西文无衬线/衬线字体。
      noto-fonts-cjk-sans # 思源黑体（中日韩无衬线，含简中 SC）。
      noto-fonts-cjk-serif # 思源宋体（中日韩衬线，含简中 SC）。
      noto-fonts-color-emoji # 彩色 Emoji 字体。
      wqy_zenhei # 文泉驿正黑，部分老程序指定使用中文字体时的回退。
      wqy_microhei # 文泉驿微米黑。
      liberation_ttf # 与 Arial / Times New Roman / Courier New 度量兼容的自由字体。
      dejavu_fonts # DejaVu 通用字体，许多程序的默认等宽/西文字体。
      # WPS 自带字体，nixpkgs 的 wpsoffice-cn 把它们删掉了；其中 DejaVu Math
      # TeX Gyre 是公式编辑器排数学符号用的，缺了公式会变方框。见 pkgs/wps-office-fonts.nix。
      bakaPackages.wps-office-fonts
      # 补齐 Nerd Font 图标（分支、箭头、文件类型），供终端提示符 powerlevel10k
      # 和 eza --icons 使用；缺了它们只会显示成方框。见 home/baka/shell.nix。
      nerd-fonts.jetbrains-mono
    ];

    # 各字体族的默认优先级：西文在前，中文回退到思源黑体/宋体。
    fontconfig.defaultFonts = {
      sansSerif = [
        "Noto Sans"
        "Noto Sans CJK SC"
        "WenQuanYi Micro Hei"
      ];
      serif = [
        "Noto Serif"
        "Noto Serif CJK SC"
      ];
      monospace = [
        # 放在最前，让 alacritty、Konsole 等跟随 monospace 的程序直接拿到图标字体。
        "JetBrainsMono Nerd Font"
        "DejaVu Sans Mono"
        "Noto Sans Mono CJK SC"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
# 另外：从本机 Windows 分区复制的微软字体（微软雅黑、宋体、Arial、Consolas 等）
# 放在用户目录 ~/.local/share/fonts/windows/ 下，由 fontconfig 自动扫描，
# 不纳入 Nix 管理；如需重装，参考本文件或重新挂载 Windows 分区复制。
