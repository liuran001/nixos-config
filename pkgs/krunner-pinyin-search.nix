# KRunner 拼音搜索插件：在 Plasma 搜索框里用全拼、首字母或拼音汉字混输找应用。
# 上游没有发布 tag，因此按 commit 固定；拼音匹配代码（src/pinyinmatch.cpp）
# 已包含在仓库里，不需要额外的拼音库。
{
  cmake,
  extra-cmake-modules,
  fetchFromGitHub,
  kcoreaddons,
  ki18n,
  kio,
  kjobwidgets,
  krunner,
  kservice,
  lib,
  qtbase,
  stdenv,
  wrapQtAppsHook,
}:

stdenv.mkDerivation {
  pname = "krunner-pinyin-search";
  version = "0.1-unstable-2025-09-23";

  src = fetchFromGitHub {
    owner = "AOSC-Dev";
    repo = "krunner-pinyin-search";
    rev = "87598886467701cd8a97727149eedf45b9e1d60e";
    hash = "sha256-CxuuAGITB67UQrV8ZxtJcvfE6o0JCIOXaL9/tQn+/RQ=";
  };

  nativeBuildInputs = [
    cmake
    extra-cmake-modules
    # 只为让 CMake 找到 Qt 的构建配置；产物是插件，没有可执行文件需要包装。
    wrapQtAppsHook
  ];
  dontWrapQtApps = true;

  buildInputs = [
    kcoreaddons
    ki18n
    kio
    kjobwidgets
    krunner
    kservice
    qtbase
  ];

  meta = {
    description = "KRunner 插件，支持用拼音搜索应用程序";
    homepage = "https://github.com/AOSC-Dev/krunner-pinyin-search";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.linux;
  };
}
