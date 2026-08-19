# KernelSU 的模块加载器：把 .ko 里未导出的符号先按 /proc/kallsyms 修补好，
# 再调用 init_module。kernelsu.ko 引用了 tasklist_lock、path_umount、
# __tracepoint_sys_enter 等十余个内核未 EXPORT_SYMBOL 的符号，普通
# insmod/modprobe 只会得到 ENOEXEC，因此加载它必须经过这个工具。
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "modloader";
  # v2.0.0 之后才补上 kernelsu feature，上游至今没有新 tag，只能跟 master 提交。
  version = "2.0.0-unstable-2026-03-27";

  src = fetchFromGitHub {
    owner = "shadichy";
    repo = "modloader";
    rev = "55f1be07eec0b0681d6bbb5a9d5edc67302fe4ed";
    hash = "sha256-MTfN2uDz8eWyznUsXiWiBE5Mzu59L00LjGGDG6HMjwE=";
  };

  cargoLock = {
    lockFile = "${finalAttrs.src}/Cargo.lock";
    # 上游依赖 Kernel-SU 维护的 rustix 分支（多了 init_module 相关封装）。
    outputHashes = {
      "rustix-0.38.34" = "sha256-XzuiOKEvVee6nN8EltOgWrC4sUGhLKkm7pdPqDKuDWY=";
    };
  };

  # kernelsu feature 会在加载完成后用 reboot/prctl 魔数回读驱动版本，
  # 加载失败时能直接给出可读的报错而不是静默成功。
  buildFeatures = [ "kernelsu" ];

  # 上游没有单元测试，cargo test 只会把 main 跑一遍，然后因为不是 root 而退出 1。
  doCheck = false;

  meta = {
    description = "按 kallsyms 修补未导出符号的 modprobe 替代品";
    homepage = "https://github.com/shadichy/modloader";
    license = lib.licenses.gpl2Only;
    mainProgram = "modloader";
    platforms = lib.platforms.linux;
  };
})
