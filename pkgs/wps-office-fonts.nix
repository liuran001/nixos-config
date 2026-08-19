# WPS Office 自带的四款字体。
#
# nixpkgs 的 wpsoffice-cn 在 unpackPhase 里 `rm -rf usr/share/{fonts,locale,templates}`，
# 把 deb 里带的字体一并删掉了，其中 DejaVu Math TeX Gyre 是公式编辑器排版数学
# 符号用的，缺了会显示成方框。这里直接复用它已经下载好的 deb（src 是固定输出
# 哈希，store 里已有，不会重新走一遍 CDN 签名下载），只把字体取出来。
#
# 另外三款（GWZT-EN、汉仪叶叶相思体简、汉仪中圆B5）是艺术字模板用的中英文字体，
# 一并装上，省得模板里挑到字体就变方框。
#
# deb 里还有 etc/fonts/conf.d/40-wps-office.conf，作用是把 SimSun / 微软雅黑
# 回退到方正与文泉驿；本机 modules/fonts.nix 已有文泉驿，Windows 分区复制来的
# 宋体和雅黑也在 ~/.local/share/fonts/windows/，fontconfig 能直接匹配到真字体，
# 所以这份回退配置没有意义，不装。
{
  binutils,
  lib,
  stdenvNoCC,
  wpsoffice-cn,
}:

stdenvNoCC.mkDerivation {
  pname = "wps-office-fonts";
  inherit (wpsoffice-cn) version src;

  # deb 是 ar 归档，需要 binutils 的 ar 拆开；stdenvNoCC 不自带。
  nativeBuildInputs = [ binutils ];

  dontBuild = true;

  # 只解字体那一个目录，不用把几百兆的 office6 铺开。
  unpackPhase = ''
    runHook preUnpack

    ar x "$src"
    tar -xf data.tar.xz ./usr/share/fonts/wps-office

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -Dm444 -t "$out/share/fonts/truetype/wps-office" \
      usr/share/fonts/wps-office/*.ttf

    runHook postInstall
  '';

  meta = {
    description = "WPS Office 自带字体，含公式用的 DejaVu Math TeX Gyre";
    homepage = "https://linux.wps.cn";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
