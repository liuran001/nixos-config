# KernelSU 的 Waydroid 分支，编译成宿主内核的外部模块。
#
# Waydroid 是 LXC 容器，用的就是宿主内核，所以给容器里的 Android 提供 root
# 只能把 KernelSU 装进宿主内核。上游 tiann/KernelSU 从 v1.0 起只支持 GKI，
# supechicken 的 waydroid 分支补上了 CONFIG_KSU_NON_ANDROID：去掉 PID=1 检查，
# 改用 sched_process_exec tracepoint 认出容器里的 /system/bin/init，
# 并在这个 init 退出后关掉 tracepoint，避免宿主进程留在 hook 路径上。
#
# 模块引用了 tasklist_lock、path_umount、__tracepoint_sys_enter 等未导出符号，
# 因此用 KBUILD_MODPOST_WARN=1 放行 modpost，加载时必须走 modloader。
{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "kernelsu-waydroid";
  version = "3.1.0-2386";

  src = fetchFromGitHub {
    owner = "supechicken";
    repo = "KernelSU";
    rev = "63bb8f7bbd9a1927c2532323777563be327afa81";
    hash = "sha256-JqaK55hQ5Wc+2hGr7a/YM90o2KNZ1I9kIDonxh7cohM=";
  };

  patches = [ ./hex-include.patch ];

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "M=$(PWD)/kernel"
    "modules"
    "CONFIG_KSU=m"
    # 在非 Android 宿主上运行所必需；同时依赖 CONFIG_KALLSYMS。
    "CONFIG_KSU_NON_ANDROID=y"
    # 宿主的 SELinux 策略不是 Android 那套，打开只会让模块去改错策略。
    "CONFIG_KSU_SELINUX=n"
    # 安全模式靠音量下键触发，x86 桌面没有这个键，留着也没用。
    "CONFIG_KSU_HANDLE_INPUT_EVENTS=n"
    # 允许 modpost 只警告未解析符号，交给 modloader 在加载时按 kallsyms 修补。
    "KBUILD_MODPOST_WARN=1"
    # 版本号 = 30000 + 提交计数，上游 Kbuild 本来用 git 算，源码 tarball 里没有 .git。
    "KSU_GIT_VERSION=2386"
  ];

  installPhase = ''
    runHook preInstall
    install -Dm444 kernel/kernelsu.ko \
      "$out/lib/modules/${kernel.modDirVersion}/extra/kernelsu.ko"
    runHook postInstall
  '';

  meta = {
    description = "面向 Waydroid 的 KernelSU 内核模块";
    homepage = "https://github.com/supechicken/KernelSU";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    broken = !(lib.versionAtLeast kernel.version "5.10");
  };
})
