# G-Helper 的 NixOS 包装：修补上游程序并提供受限的 GPU 状态 helper。
{
  g-helper-linux,
  lib,
  nvidiaPackage,
  pkgs,
}:

let
  upstreamPackages = g-helper-linux.packages.${pkgs.stdenv.hostPlatform.system};
  # NixOS 上的软件与系统集成都由 Flake 统一管理。上游内置更新会下载 master
  # 分支的 install.sh 并通过 pkexec 以 root 执行，内置“修复”还可能写入自己的
  # udev/sudoers 配置；因此隐藏这些入口，并在实际执行路径做防御性短路。
  # 版本检查、发行说明、BIOS 与驱动检查仍然保留。
  ghelper = upstreamPackages.ghelper.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ./nixos-safety.patch ];
    preBuild = (oldAttrs.preBuild or "") + ''
      # Keep the embedded recovery copy identical to the audited NixOS helper.
      rm -f vendor/gpu-helper/gpu-helper
      cp --no-preserve=mode,ownership ${gpuHelper}/bin/gpu-helper vendor/gpu-helper/gpu-helper
    '';
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace src/UI/Views/UpdatesWindow.axaml.cs \
        --replace-fail \
          'btnRow.Children.Add(btnUpdate);' \
          'if (!Platform.Linux.NixOS.IsNixOS) btnRow.Children.Add(btnUpdate);' \
        --replace-fail \
          'primaryRow.Children.Add(btnUpdate);' \
          'if (!Platform.Linux.NixOS.IsNixOS) primaryRow.Children.Add(btnUpdate);' \
        --replace-fail \
          'await RunNixOSUpdate(btn);' \
          'await Task.CompletedTask;' \
        --replace-fail \
          'buttonSysFilesUninstall.IsVisible = !Platform.Linux.NixOS.IsNixOS;' \
          'buttonSysFilesUninstall.IsVisible = !Platform.Linux.NixOS.IsNixOS;
        buttonSysFilesFix.IsVisible = !Platform.Linux.NixOS.IsNixOS;'

      substituteInPlace src/Install/Installer.cs \
        --replace-fail \
          'if (onRepair != null && IsRepairable(r))' \
          'if (onRepair != null && IsRepairable(r) && !Platform.Linux.NixOS.IsNixOS)' \
        --replace-fail \
          ' NOPASSWD: ' \
          ' PASSWD: ' \
        --replace-fail \
          '_lastAuthHint = null;' \
          'if (Platform.Linux.NixOS.IsNixOS)
            return (false, 0, false);

        _lastAuthHint = null;'

      # Never resolve a privileged executable from the desktop session's PATH:
      # a user-controlled ~/bin entry would otherwise be handed directly to
      # pkexec.  Pin both helpers to their immutable Nix store outputs instead.
      substituteInPlace src/Platform/Linux/NixOS.cs \
        --replace-fail \
          'return WhichCached("gpu-helper", ref _gpuHelper);' \
          'return "${gpuHelper}/bin/gpu-helper";' \
        --replace-fail \
          'return WhichCached("gpu-block-helper.sh", ref _gpuBlockHelper);' \
          'return "${gpuStateHelper}/bin/gpu-block-helper.sh";' \
        --replace-fail \
          '&& (Directory.Exists("/sys/module/i2c_dev") || Directory.Exists("/sys/module/i2c-dev"))' \
          "" \
        --replace-fail \
          'string script = Path.Combine(Path.GetTempPath(), $"ghelper-install-{Guid.NewGuid():N}.sh");' \
          'if (IsNixOS)
            return (false, "G-Helper updates are managed declaratively by NixOS");

        string script = Path.Combine(Path.GetTempPath(), $"ghelper-install-{Guid.NewGuid():N}.sh");'

      # The upstream integrity panel expects its own NOPASSWD/FHS integration.
      # This module deliberately uses interactive Polkit and declarative udev /
      # systemd units, so report those entries accurately and make the root CLI
      # installer refuse all direct system-file mutations on NixOS.
      substituteInPlace src/Install/Installer.cs \
        --replace-fail \
          'File.Exists(Platform.Linux.NixOS.UdevRulePath)' \
          'true' \
        --replace-fail \
          'return ProbeSudoers();' \
          'return FileState.NotApplicable;' \
        --replace-fail \
          'if (args.Length < 2 || string.IsNullOrWhiteSpace(args[1]))' \
          'if (Platform.Linux.NixOS.IsNixOS)
        {
            Console.Error.WriteLine("G-Helper system files are managed declaratively by NixOS");
            return 1;
        }

        if (args.Length < 2 || string.IsNullOrWhiteSpace(args[1]))'

      substituteInPlace src/Cli/ResourceExtractorCli.cs \
        --replace-fail \
          'if (args.Length != 2)' \
          'if (GHelper.Linux.Platform.Linux.NixOS.IsNixOS)
        {
            Console.Error.WriteLine("G-Helper helpers are managed declaratively by NixOS");
            return 1;
        }

        if (args.Length != 2)'
    '';
  });
  gpuHelperPath = lib.makeBinPath [
    nvidiaPackage.bin
    pkgs.coreutils
    pkgs.kmod
    pkgs.systemd
    pkgs.util-linux
  ];
  nvidiaManagementLibrary = "${nvidiaPackage.out}/lib/libnvidia-ml.so.1";

  # 上游 helper 强制使用传统 FHS PATH，并按裸文件名 dlopen NVML；两者在 NixOS
  # 上都找不到。只修正运行时路径，不改变它对参数的白名单校验。
  gpuHelper = upstreamPackages.gpu-helper.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace gpu-helper.c \
        --replace-fail \
          'setenv("PATH", "/usr/sbin:/usr/bin:/sbin:/bin", 1);' \
          'setenv("PATH", "${gpuHelperPath}", 1);'
      substituteInPlace nvidia_ops.c \
        --replace-fail '"libnvidia-ml.so.1"' '"${nvidiaManagementLibrary}"'

      # The upstream kill dispatcher stopped services only for verified GPU
      # holders, but still signalled every supplied PID unconditionally.  Keep
      # the privileged helper scoped to actual GPU holders.
      substituteInPlace process_ops.c \
        --replace-fail \
          'stop_service(pid);' \
          'if (!is_holder(pid)) { continue; } stop_service(pid);'
    '';
  });

  # 上游同名脚本会修改 /etc/modprobe.d、udev 规则和 sudoers。NixOS 版本只
  # 接受固定枚举，并把可持久状态原子写入 root 管理的 /var/lib 目录。
  gpuStateHelper = pkgs.writeShellApplication {
    name = "gpu-block-helper.sh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      state_dir=/var/lib/ghelper-nixos

      usage() {
        echo "usage: gpu-block-helper.sh {write|persist|unpersist|set-backend|clean|mem-sleep} ..." >&2
        exit 2
      }

      if (( EUID != 0 )); then
        echo "gpu-block-helper.sh: root privileges are required" >&2
        exit 1
      fi

      ensure_state_dir() {
        if [[ -L "$state_dir" ]]; then
          echo "gpu-block-helper.sh: refusing symlink state directory" >&2
          exit 1
        fi
        install -d -o root -g root -m 0755 -- "$state_dir"
        if [[ $(stat -c '%u:%g' -- "$state_dir") != 0:0 ]]; then
          echo "gpu-block-helper.sh: unsafe state directory owner" >&2
          exit 1
        fi
      }

      atomic_write() {
        local state_name=$1
        local state_value=$2
        local temporary
        temporary=$(mktemp "$state_dir/.state.XXXXXX")
        trap 'rm -f -- "$temporary"' RETURN
        printf '%s\n' "$state_value" > "$temporary"
        chown root:root -- "$temporary"
        chmod 0644 -- "$temporary"
        mv -fT -- "$temporary" "$state_dir/$state_name"
        trap - RETURN
      }

      (( $# > 0 )) || usage
      case $1 in
        write)
          (( $# == 3 )) || usage
          case $2 in
            eco | standard | optimized | ultimate) ;;
            *) usage ;;
          esac
          [[ $3 == asus-wmi ]] || {
            echo "gpu-block-helper.sh: the PCI backend is unsupported on NixOS" >&2
            exit 2
          }
          ensure_state_dir
          atomic_write backend asus-wmi
          atomic_write pending-gpu-mode "$2"
          ;;
        persist)
          (( $# == 2 )) || usage
          [[ $2 == eco ]] || usage
          ensure_state_dir
          atomic_write backend asus-wmi
          atomic_write persistent-gpu-mode eco
          ;;
        unpersist)
          (( $# == 1 )) || usage
          ensure_state_dir
          rm -f -- "$state_dir/persistent-gpu-mode"
          ;;
        set-backend)
          (( $# == 2 )) || usage
          [[ $2 == asus-wmi ]] || {
            echo "gpu-block-helper.sh: the PCI backend is unsupported on NixOS" >&2
            exit 2
          }
          ensure_state_dir
          atomic_write backend asus-wmi
          ;;
        clean)
          (( $# == 1 )) || usage
          ensure_state_dir
          rm -f -- "$state_dir/pending-gpu-mode"
          ;;
        mem-sleep)
          (( $# == 2 )) || usage
          case $2 in
            deep | s2idle) ;;
            *) usage ;;
          esac
          [[ -f /sys/power/mem_sleep ]] || {
            echo "gpu-block-helper.sh: /sys/power/mem_sleep is unavailable" >&2
            exit 1
          }
          grep -qw -- "$2" /sys/power/mem_sleep || {
            echo "gpu-block-helper.sh: suspend variant is not offered by the kernel" >&2
            exit 1
          }
          printf '%s\n' "$2" > /sys/power/mem_sleep
          grep -q -- "\\[$2\\]" /sys/power/mem_sleep || {
            echo "gpu-block-helper.sh: suspend variant readback failed" >&2
            exit 1
          }
          ensure_state_dir
          atomic_write mem-sleep "$2"
          ;;
        live-standard)
          echo "gpu-block-helper.sh: the PCI backend is unsupported on NixOS" >&2
          exit 2
          ;;
        *) usage ;;
      esac
    '';
  };
in
{
  inherit ghelper gpuHelper gpuStateHelper;
}
