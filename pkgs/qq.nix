# 腾讯官方 Linux QQ：在 nixpkgs 的封装基础上固定当前仍可下载的 x86_64 发布包。
{
  fetchurl,
  qq,
}:

qq.overrideAttrs (_oldAttrs: rec {
  version = "3.2.32-2026-08-12";

  src = fetchurl {
    url = "https://qqdl.gtimg.cn/qqfile/QQNT/9.9.33/release/3f89efc5/QQ_3.2.32_260812_amd64_01.deb";
    hash = "sha256-0IXdiTlyJQYeufGUMI9ogSmBjtRFd36XpKChbhPXsOg=";
  };
})
