# Project Sekai（世界计划）鼠标指针主题，移植自 AUR 的 pjsk-cursor-theme（v0.0.5）。
# 构建时从缤纷舞台官网下载官方指针资源（.ani/.cur），用 win2xcur 转成 X11 光标主题，
# 并生成 left_ptr 等标准光标别名。官网若更新 zip 内容会导致 hash 校验失败，
# 届时用 `nix store prefetch-file --json <url>` 重新计算并更新对应条目即可。
# 安装后在 系统设置 → 颜色与主题 → 光标 中选择 “PJSK ...” 主题并应用。
{
  stdenvNoCC,
  fetchurl,
  unzip,
  win2xcur,
  lib,
}:

let
  # 官网指针资源包；name 即解压目录名，用于推断主题名和动态/静态类型，不要改动命名格式。
  cursorZips = [
    {
      name = "Airi-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Airi%20Animated%20Cursor.zip";
      hash = "sha256-fMH6rDpX9YAKNfdSTjJp8OCOefZilkhodhnRd0HkeoA=";
    }
    {
      name = "Airi-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Airi%20Static%20Cursor.zip";
      hash = "sha256-Gm0atNC+FhXIIPlDC+CfxlBPCLldjWVx7TE1LKbZgRI=";
    }
    {
      name = "Akito-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Akito%20Animated%20Cursor.zip";
      hash = "sha256-jhs6J64JUiBbSf7/vRzhHtdUWJULEecM7CsSWgLsqc8=";
    }
    {
      name = "Akito-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Akito%20Static%20Cursor.zip";
      hash = "sha256-4F+meqdp01lXduDKLsOgQDxRt/v38YYtj/RHP28jRb0=";
    }
    {
      name = "An-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/An%20Animated%20Cursor.zip";
      hash = "sha256-OFxbl6S0s/5pLVAdw0TWq0jKf1Hg36J4WivGq09fKwI=";
    }
    {
      name = "An-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/An%20Static%20Cursor.zip";
      hash = "sha256-B4yRXvOjsAmDoFRjp/AhswWdLp+Z4305E/CAciVfLg8=";
    }
    {
      name = "ani-file-animation-WxS.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/ani%20file-animation%20WxS.zip";
      hash = "sha256-G59yntrW4jB/ysbjMCY+da/ctCcn2h7rOpteOFOx3UY=";
    }
    {
      name = "ani-file-animation-leoneed.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/ani%20file-animation-leoneed.zip";
      hash = "sha256-5HlCdQ5SZ2TCeMjD33FmkhZN+BJOT1Y/eHBvsgsAblk=";
    }
    {
      name = "ani-file-animation-MMJ.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/ani%20file-animation-MMJ.zip";
      hash = "sha256-AYOkEGiScmVtO+NOpe4xtbyn4408iRVXN6Bhdh/pNig=";
    }
    {
      name = "ani-file-animation-N25.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/ani%20file-animation-N25.zip";
      hash = "sha256-clGFuHrFMUV5Va/btiKctQBXVx5c6MGCkAs6Iw3G0Ig=";
    }
    {
      name = "ani-file-animation-VBS.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/ani%20file-animation-VBS.zip";
      hash = "sha256-oh2rj0oIPBXMWdi7gHNhqlb7VatQiVOfIjt32juAE5o=";
    }
    {
      name = "ani-file-animation-VirtualSinger.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/ani%20file-animation-VirtualSinger.zip";
      hash = "sha256-YUWi9VFoU3UkLMJjC5SB3jzkmXrcoLttj3w/D35Vrco=";
    }
    {
      name = "cur-file-static-leoneed.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/cur%20file-static-leoneed.zip";
      hash = "sha256-o/d8le0+4TnKvyPj3SgETQCZ30fhppgqvsr/uHa5dho=";
    }
    {
      name = "cur-file-static-MMJ.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/cur%20file-static-MMJ.zip";
      hash = "sha256-fsLPVuKDqxJjpZl27Ih3+6ybj8aEzVvIZpW4Wmu34v4=";
    }
    {
      name = "cur-file-static-N25.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/cur%20file-static-N25.zip";
      hash = "sha256-PJxBWW8klKDE/G77hIHJRSyy5p6W/ICmFMobaw3c3Ww=";
    }
    {
      name = "cur-file-static-VBS.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/cur%20file-static-VBS.zip";
      hash = "sha256-+Me8JuSK/4bA37l0Gin2s+0A2xe7PKQ1LR8y5SmI1Sc=";
    }
    {
      name = "cur-file-static-VirtualSinger.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/cur%20file-static-VirtualSinger.zip";
      hash = "sha256-s9+CVTaj+z2UKgbEq0+3z3ql+30S1Q2w2iGFR/FZRxE=";
    }
    {
      name = "cur-file-static-WxS.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/cur%20file-static-WxS.zip";
      hash = "sha256-eNJtX/dwOuVdXVeGOjDHxLWQ/UdCMcwuZE4DO2d9sbI=";
    }
    {
      name = "Emu-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Emu%20Animated%20Cursor.zip";
      hash = "sha256-soXY3NvTvKgDaYSyBh+6knUPew67eMw0qNhZUuWMC1w=";
    }
    {
      name = "Emu-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Emu%20Static%20Cursor.zip";
      hash = "sha256-dklRWCeEETvqHZuI5J1Jxv/A0YMb4vFeeM+CK99KuQg=";
    }
    {
      name = "Ena-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Ena%20Animated%20Cursor.zip";
      hash = "sha256-syuF/Rml118OX2knSXGUu5l8FDVHNy4nx9TFCujIQeY=";
    }
    {
      name = "Ena-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Ena%20Static%20Cursor.zip";
      hash = "sha256-cMhtOhpdF4/fpsVXnqx+tHyMS+rlk4pi7/FnlDnfZW8=";
    }
    {
      name = "Haruka-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Haruka%20Animated%20Cursor.zip";
      hash = "sha256-XQ09A4zMSjMcfQvmfh1Hqdm9pIsJlgLUUQZyyPz47sg=";
    }
    {
      name = "Haruka-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Haruka%20Static%20Cursor.zip";
      hash = "sha256-kziOAOCOXNVm+wB98fw6t898XSoMNOXyVmXfAdPn70Q=";
    }
    {
      name = "Honami-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Honami%20Animated%20Cursor.zip";
      hash = "sha256-hMOezdqCgDNgXJadYGElr6rw3tbJLX40/m6gYN74MCg=";
    }
    {
      name = "Honami-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Honami%20Static%20Cursor.zip";
      hash = "sha256-qxYIPkO7JoyX+CRP2K9smbNMP5i9UtZuH4X4BuQE5Qc=";
    }
    {
      name = "Ichika-Cursor-animation.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Ichika%20Cursor%20animation.zip";
      hash = "sha256-kpgJquTqHZPF0tfDU8WFE9aYJL6hp39RDryZiA/cz8k=";
    }
    {
      name = "Ichika-Cursor-static.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Ichika%20Cursor%20static.zip";
      hash = "sha256-1HhpPEjDRo0cgYNueaVKV0TaacNV8WqWq5I49xAPEGU=";
    }
    {
      name = "KAITO-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/KAITO%20Animated%20Cursor.zip";
      hash = "sha256-iyWiBfLEodBbbGSQKVB0910JjLLN93ilvDwEb7iRIzc=";
    }
    {
      name = "KAITO-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/KAITO%20Static%20Cursor.zip";
      hash = "sha256-/NlQwZtD2lCgPNbiEb8K9l0TD51ljvQqWNsYtGkRDfg=";
    }
    {
      name = "Kanade-Cursor-animation.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Kanade%20Cursor%20animation.zip";
      hash = "sha256-P1wABU88T/CClKmSHYifnT1F9R6CT/gygjZ9xS4STlY=";
    }
    {
      name = "Kanade-Cursor-static.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Kanade%20Cursor%20static.zip";
      hash = "sha256-zc4TPnj6uCoI/EZqAb74nBavmejNjUe3G3aWr5A/U+Y=";
    }
    {
      name = "Kohane-Cursor-animation.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Kohane%20Cursor%20animation.zip";
      hash = "sha256-xBTpWB/mLA4cz8OsljFAWaUfqGyfBBBNLWrHZUNrYAo=";
    }
    {
      name = "Kohane-Cursor-static.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Kohane%20Cursor%20static.zip";
      hash = "sha256-WjzxOZwKM6tk3D5oNA/r1xmdHt3Ldxco1jRByQeY8fc=";
    }
    {
      name = "Len-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Len%20Animated%20Cursor.zip";
      hash = "sha256-79y+6yBW4HVBzMNxQn8G9muQuvZWcN2h7s8SZH18Uv8=";
    }
    {
      name = "Len-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Len%20Static%20Cursor.zip";
      hash = "sha256-go3qCiZ+Ow+JkWlevPH/fZjG6LVNnxZtfPI+C6nQ3ZM=";
    }
    {
      name = "Luka-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Luka%20Animated%20Cursor.zip";
      hash = "sha256-qSxJcnJr1z4NwQ0U4aCLmP5rua4T/WCD8sKgTSoM5r4=";
    }
    {
      name = "Luka-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Luka%20Static%20Cursor.zip";
      hash = "sha256-L6vqrxnhDGIoclHPd5WWJ1KLVDIObcwvDR86V5/z+ec=";
    }
    {
      name = "Mafuyu-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Mafuyu%20Animated%20Cursor.zip";
      hash = "sha256-ywyWTponJe9cBm6x35NmTMaTeXS8+syRC9eB3unfYVI=";
    }
    {
      name = "Mafuyu-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Mafuyu%20Static%20Cursor.zip";
      hash = "sha256-JhK7t5a89AMyAJQeqT6w2JvGoYphQV9GZQf2vOBt26U=";
    }
    {
      name = "MEIKO-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/MEIKO%20Animated%20Cursor.zip";
      hash = "sha256-TL0Ie9M2yAbRlI6yjAy6Z2ZQeaxfLffUIvLOj5BqDxE=";
    }
    {
      name = "MEIKO-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/MEIKO%20Static%20Cursor.zip";
      hash = "sha256-sWjXBdvZSM41VT/HsAzRIWWMPbPFesxA+ammDH+Ri2Y=";
    }
    {
      name = "Minori-Cursor-animation.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Minori%20Cursor%20animation.zip";
      hash = "sha256-lDpcENbNIrRqNfiANhzSlO7C1M9SZbpuCauG3iRhwxs=";
    }
    {
      name = "Minori-Cursor-static.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Minori%20Cursor%20static.zip";
      hash = "sha256-xC1S8Ucuj7/PRsaQ1hgxgLiBUYL+ngpXRVyrtS99Qmg=";
    }
    {
      name = "Mizuki-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Mizuki%20Animated%20Cursor.zip";
      hash = "sha256-Bg+cco6yyp/F7/WuzL0rXhO+AudyZAqY10gn5dy/jkw=";
    }
    {
      name = "Mizuki-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Mizuki%20Static%20Cursor.zip";
      hash = "sha256-5JzMIrmovG0IKIbB9Vgbn2jOtcvA1jIQFxEHeRS0JqI=";
    }
    {
      name = "Nene-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Nene%20Animated%20Cursor.zip";
      hash = "sha256-iz3BNFElA2GhXB2i6W8juvkPEx84eYz6mR/X2EqLt5s=";
    }
    {
      name = "Nene-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Nene%20Static%20Cursor.zip";
      hash = "sha256-KWsI028S6Id2+Hex+S/8nhLPMNVcEO4n20OYmwWVQyo=";
    }
    {
      name = "Rin-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Rin%20Animated%20Cursor.zip";
      hash = "sha256-5a6orwN+Gxlr41o/foTnkS+NyojfJEeUI+oQH4lDNPQ=";
    }
    {
      name = "Rin-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Rin%20Static%20Cursor.zip";
      hash = "sha256-Jb7a7/T2gfbGczSPCrm1Fb7WjaDakS2nfYpy41c0gMI=";
    }
    {
      name = "Rui-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Rui%20Animated%20Cursor.zip";
      hash = "sha256-F1xUHIYg9EkzdtGuTfIlMe/w+sEjYKVQ6KILnS0z3S8=";
    }
    {
      name = "Rui-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Rui%20Static%20Cursor.zip";
      hash = "sha256-c9GRfYi4QGnLkx+hIus9nDeo2WPFB2Ec+dK5jltVA/s=";
    }
    {
      name = "Saki-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Saki%20Animated%20Cursor.zip";
      hash = "sha256-6BNs9mke18AP1y7/OKruCzCWNqD5gr74IWcsHaLr3Eg=";
    }
    {
      name = "Saki-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Saki%20Static%20Cursor.zip";
      hash = "sha256-s3+v66mkQKG04zPWqLZ8YaMbxJh/FWMpwlry3+eE4S8=";
    }
    {
      name = "Shiho-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Shiho%20Animated%20Cursor.zip";
      hash = "sha256-hU6W7krMtTG5l1y4r+zA8hSualDmQt/HKZecWioEsJo=";
    }
    {
      name = "Shiho-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Shiho%20Static%20Cursor.zip";
      hash = "sha256-BzscukzuC3ZTUXyCoIgqUuNkFUd74HpmtXFtYvplxEo=";
    }
    {
      name = "Shizuku-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Shizuku%20Animated%20Cursor.zip";
      hash = "sha256-RzXoQH46anKlKJDsEuRqyh+haVzkCF84fc8AWZ+IImA=";
    }
    {
      name = "Shizuku-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Shizuku%20Static%20Cursor.zip";
      hash = "sha256-0xB9zUzG1NXpkiUJyH/sHVmJmiauILeMD6Vj5q59DZ0=";
    }
    {
      name = "Toya-Animated-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Toya%20Animated%20Cursor.zip";
      hash = "sha256-dMluqqaw4eWGpszNLnQ6bK2vXnSvhzn2A9IcQ0GfQlA=";
    }
    {
      name = "Toya-Static-Cursor.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Toya%20Static%20Cursor.zip";
      hash = "sha256-3NaeO+ZbjB/slRvC1oaI97zqyLZlerjbbT0Ci3nfbng=";
    }
    {
      name = "Tsukasa-Cursor-animation.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Tsukasa%20Cursor%20animation.zip";
      hash = "sha256-y3/iYdU5NAHGBSykcRRQuygRxvLTPSFJRTtvhVZOwrY=";
    }
    {
      name = "Tsukasa-Cursor-static.zip";
      url = "https://colorfulstage.com/upload_images/media/Download/Tsukasa%20Cursor%20static.zip";
      hash = "sha256-9dCPAg8UX6VAtkpKcpKoyZotS+hKrY4+59JwTndIcCI=";
    }
  ];

in
stdenvNoCC.mkDerivation {
  pname = "pjsk-cursor-theme";
  version = "0.0.5";

  # 所有 zip 作为固定输出源；hash 已固定，构建全程无需联网。
  srcs = map (z: fetchurl { inherit (z) name url hash; }) cursorZips;
  dontUnpack = true;

  nativeBuildInputs = [
    unzip
    win2xcur # 把 Windows .ani/.cur 指针转成 X11 光标格式
  ];

  buildPhase = ''
    runHook preBuild

    # PJSK 指针名 → X11 光标名映射（沿用 AUR 脚本；Person/Pin 无对应标准名，原样保留）
    declare -A PJSK_TO_X_MAP=(
      ["Working"]="progress left_ptr_watch"
      ["Normal"]="default arrow top-left-arrow top_left_arrow left_ptr x-cursor X_cursor"
      ["Help"]="ask dnd-ask help question_arrow whats_this left_ptr_help"
      ["Busy"]="wait watch"
      ["Precision"]="crosshair cross diamond_cross cross_reverse tcross"
      ["Text"]="text xterm ibeam vertical-text"
      ["Handwriting"]="pencil"
      ["Unavailable"]="no-drop dnd-none circle not-allowed crossed_circle forbidden pirate"
      ["Vertical"]="col-resize sb_v_double_arrow split_v n-resize s-resize top_side ns-resize v_double_arrow size_ver top-tee top_tee double_arrow double-arrow up sb_up_arrow bottom-tee bottom_side bottom_tee sb_down_arrow down"
      ["Horizontal"]="ew-resize h_double_arrow size_hor left sb_left_arrow left-tee left_tee row-resize sb_h_double_arrow split_h w-resize e-resize left_side right_side right sb_right_arrow right-tee right_tee"
      ["Diagonal1"]="nw-resize top_left_corner ul_angle nwse-resize fd_double_arrow size_fdiag se-resize lr_angle bottom_right_corner"
      ["Diagonal2"]="ne-resize top_right_corner ur_angle nesw-resize bd_double_arrow size_bdiag sw-resize ll_angle bottom_left_corner"
      ["Move"]="cell plus all-scroll fleur size_all"
      ["Link"]="alias link dnd-link left-hand hand1 pointer hand2 grab grabbing pointing_hand openhand hand"
      ["Alternate"]="top-right-arrow right_ptr move dnd-move draft_large draft_small up-arrow up_arrow center_ptr"
    )

    names=(${lib.escapeShellArgs (map (z: z.name) cursorZips)})

    # 完整解包所有 zip；转换阶段只会读取其中的 .ani 或 .cur 文件。
    i=0
    for f in $srcs; do
      n="''${names[$i]}"
      d="extracted/''${n%.zip}"
      mkdir -p "$d"
      unzip -qo "$f" -d "$d"
      i=$((i + 1))
    done

    # 转换为 X11 光标，并按映射表生成标准别名
    for theme_dir in extracted/*/; do
      theme=$(basename "$theme_dir")
      mkdir -p "output/$theme"
      lc_theme=$(printf '%s' "$theme" | tr '[:upper:]' '[:lower:]')
      case "$lc_theme" in
        *ani*|*animation*) files=("$theme_dir"/*.ani) ;;
        *cur*|*static*|*cursor*) files=("$theme_dir"/*.cur) ;;
        *) echo "Unknown theme type: $theme" >&2; exit 1 ;;
      esac
      win2xcur "''${files[@]}" -o "output/$theme/"
      for src in output/"$theme"/*; do
        [ -f "$src" ] || continue
        name="''${src##*/}"
        aliases="''${PJSK_TO_X_MAP[$name]}"
        [ -z "$aliases" ] && continue
        # 每组别名保留一个实际文件，其余使用相对符号链接，避免把同一光标复制数十份。
        read -r primary _ <<< "$aliases"
        mv -- "$src" "output/$theme/$primary"
        for alias in $aliases; do
          [ "$alias" = "$primary" ] && continue
          ln -sfn "$primary" "output/$theme/$alias"
        done
      done
    done

    # 打包为 X11 图标主题目录（“PJSK <主题> Animated|Static”）
    for theme_dir in output/*/; do
      dir=$(basename "$theme_dir")
      lc_dir=$(printf '%s' "$dir" | tr '[:upper:]' '[:lower:]')
      case "$lc_dir" in
        *ani*|*animation*|*animated*) suffix="Animated" ;;
        *cur*|*cursor*|*static*) suffix="Static" ;;
        *) echo "Unknown theme type: $dir" >&2; exit 1 ;;
      esac
      base=$(printf '%s' "$dir" | awk -F'-' '{
        out=""
        for (i=1; i<=NF; i++) {
          t=tolower($i)
          if (t=="cur" || t=="cursor" || t=="file" || t=="static" || t=="ani" || t=="animation" || t=="animated") continue
          out = (out=="" ? $i : out "-" $i)
        }
        print out
      }')
      [ -n "$base" ] || base="$dir"
      dest="packaged/PJSK $base $suffix"
      mkdir -p "$dest/cursors"
      cp -a "$theme_dir"/. "$dest/cursors/"
      printf '[Icon Theme]\nName=PJSK %s %s\nComment=Project Sekai Cursors, From https://colorfulstage.com/media/download/\n' "$base" "$suffix" > "$dest/index.theme"
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/icons"
    cp -a packaged/. "$out/share/icons/"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Project Sekai mouse cursors as X icon themes";
    homepage = "https://colorfulstage.com/media/download/";
    license = licenses.unfree; # 素材版权归 SEGA / Colorful Palette 所有，仅供个人使用
  };
}
