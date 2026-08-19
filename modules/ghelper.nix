# G-Helper：ASUS 笔记本性能、风扇、电池、灯效和 GPU 模式控制。
# 只复用上游持续更新的软件包，不导入其 NOPASSWD 和全员可写的默认权限模块。
{
  config,
  g-helper-linux,
  lib,
  pkgs,
  ...
}:

let
  ghelperPackages = pkgs.callPackage ../pkgs/ghelper {
    inherit g-helper-linux;
    nvidiaPackage = config.hardware.nvidia.package;
  };
  inherit (ghelperPackages) ghelper gpuHelper gpuStateHelper;

  # 开机仅兑现受校验的状态文件。Eco 路径在写 dgpu_disable=1 前会动态找出
  # 本机 dGPU、停止 NVIDIA 守护进程、释放驱动并再次确认没有任何函数绑定。
  # 任一步失败都会保留 pending 标记供下次重试，同时以成功状态退出，不阻塞桌面。
  gpuBootApply = pkgs.writeShellScript "ghelper-nixos-apply-state" ''
    set +e
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.kmod
        pkgs.systemd
        gpuHelper
      ]
    }

    state_dir=/var/lib/ghelper-nixos
    pending_state=$state_dir/pending-gpu-mode
    persistent_state=$state_dir/persistent-gpu-mode
    backend_state=$state_dir/backend
    mem_sleep_state=$state_dir/mem-sleep
    gpu_helper=${gpuHelper}/bin/gpu-helper

    powerd_was_active=0
    persistenced_was_active=0
    eco_release_in_progress=0
    declare -a released_nodes=()
    declare -a released_drivers=()

    log() {
      echo "ghelper-nixos: $*" >&2
    }

    read_state() {
      local state_path=$1
      [[ -f $state_path ]] || return 1
      local state_value
      state_value=$(<"$state_path")
      printf '%s' "$state_value"
    }

    resolve_asus_attribute() {
      local attribute=$1
      local candidate
      for candidate in \
        "/sys/bus/platform/devices/asus-nb-wmi/$attribute" \
        "/sys/devices/platform/asus-nb-wmi/$attribute" \
        "/sys/class/firmware-attributes/asus-armoury/attributes/$attribute/current_value"; do
        if [[ -f $candidate ]]; then
          printf '%s\n' "$candidate"
          return 0
        fi
      done
      return 1
    }

    apply_mem_sleep() {
      [[ -f $mem_sleep_state && -f /sys/power/mem_sleep ]] || return 0
      local variant
      variant=$(read_state "$mem_sleep_state") || return 0
      case $variant in
        deep | s2idle) ;;
        *)
          log "ignoring invalid mem-sleep state"
          return 0
          ;;
      esac
      if ! grep -qw -- "$variant" /sys/power/mem_sleep; then
        log "mem-sleep '$variant' is not offered by the kernel"
        return 0
      fi
      if printf '%s\n' "$variant" > /sys/power/mem_sleep \
        && grep -q -- "\\[$variant\\]" /sys/power/mem_sleep; then
        log "restored mem-sleep '$variant'"
      else
        log "failed to restore mem-sleep '$variant'"
      fi
    }

    find_nvidia_graphics() {
      local device vendor class boot_vga
      for device in /sys/bus/pci/devices/*; do
        [[ -e $device ]] || continue
        [[ -r $device/vendor && -r $device/class ]] || continue
        vendor=$(<"$device/vendor")
        [[ $vendor == 0x10de ]] || continue
        class=$(<"$device/class")
        case $class in
          0x030000 | 0x030200) ;;
          *) continue ;;
        esac
        boot_vga=0
        [[ -r $device/boot_vga ]] && boot_vga=$(<"$device/boot_vga")
        if [[ $boot_vga == 1 ]]; then
          log "refusing NVIDIA graphics device ''${device##*/}: it is boot_vga"
          return 2
        fi
        printf '%s\n' "$device"
        return 0
      done
      return 1
    }

    restore_after_failed_eco() {
      local index
      timeout 5 "$gpu_helper" modprobe nvidia >/dev/null 2>&1 || true
      for (( index = ''${#released_nodes[@]} - 1; index >= 0; index-- )); do
        timeout 5 "$gpu_helper" pci-bind \
          "''${released_drivers[$index]}" "''${released_nodes[$index]}" \
          >/dev/null 2>&1 || true
      done
      [[ $powerd_was_active == 1 ]] \
        && timeout 5 "$gpu_helper" daemon start nvidia-powerd >/dev/null 2>&1
      [[ $persistenced_was_active == 1 ]] \
        && timeout 5 "$gpu_helper" daemon start nvidia-persistenced >/dev/null 2>&1
      [[ -w /sys/bus/pci/rescan ]] && printf '1\n' > /sys/bus/pci/rescan
      eco_release_in_progress=0
    }

    cleanup_interrupted_release() {
      if [[ $eco_release_in_progress == 1 ]]; then
        log "GPU release was interrupted; restoring drivers before exit"
        restore_after_failed_eco
      fi
    }

    trap 'exit 1' HUP INT TERM
    trap cleanup_interrupted_release EXIT

    release_nvidia() {
      local slot=$1
      local -a pci_nodes=(/sys/bus/pci/devices/"$slot".*)
      local node vendor driver holder_output module attempt index
      local has_bound=0

      released_nodes=()
      released_drivers=()
      powerd_was_active=0
      persistenced_was_active=0

      [[ -e ''${pci_nodes[0]} ]] || {
        log "no PCI functions found for NVIDIA slot $slot"
        return 1
      }

      # Preflight every function before changing anything. Unknown drivers such as
      # vfio-pci are never detached from a running VM.
      for node in "''${pci_nodes[@]}"; do
        [[ -r $node/vendor ]] || {
          log "refusing unreadable PCI function ''${node##*/}"
          return 1
        }
        vendor=$(<"$node/vendor")
        [[ $vendor == 0x10de ]] || {
          log "refusing mixed-vendor PCI slot $slot"
          return 1
        }
        [[ -L $node/driver ]] || continue
        driver=$(basename "$(readlink -f "$node/driver")")
        case $driver in
          nvidia | snd_hda_intel) ;;
          *)
            log "refusing ''${node##*/}: unsupported bound driver '$driver'"
            return 1
            ;;
        esac
        has_bound=1
      done

      [[ $has_bound == 1 ]] || return 0

      eco_release_in_progress=1
      systemctl is-active --quiet nvidia-powerd.service && powerd_was_active=1
      systemctl is-active --quiet nvidia-persistenced.service && persistenced_was_active=1

      timeout 5 "$gpu_helper" smi -rgc >/dev/null 2>&1 || true
      timeout 5 "$gpu_helper" smi -rmc >/dev/null 2>&1 || true
      timeout 5 "$gpu_helper" daemon stop nvidia-powerd >/dev/null 2>&1 || true
      timeout 5 "$gpu_helper" daemon stop nvidia-persistenced >/dev/null 2>&1 || true

      holder_output=$(timeout 5 "$gpu_helper" list 0 2>/dev/null)
      if [[ $? != 0 ]]; then
        log "could not verify NVIDIA process holders"
        restore_after_failed_eco
        return 1
      fi
      if [[ -n $holder_output ]]; then
        log "NVIDIA still has active process holders; refusing Eco"
        restore_after_failed_eco
        return 1
      fi

      # Reverse function order releases HDMI audio before the graphics function.
      for (( index = ''${#pci_nodes[@]} - 1; index >= 0; index-- )); do
        node=''${pci_nodes[$index]}
        [[ -L $node/driver ]] || continue
        driver=$(basename "$(readlink -f "$node/driver")")
        if timeout 10 "$gpu_helper" pci-unbind "$driver" "''${node##*/}" \
          >/dev/null 2>&1; then
          released_nodes+=("''${node##*/}")
          released_drivers+=("$driver")
        else
          log "failed to unbind $driver from ''${node##*/}"
          restore_after_failed_eco
          return 1
        fi
      done

      for module in nvidia_drm nvidia_modeset nvidia_uvm nvidia nvidia_wmi_ec_backlight; do
        for attempt in 1 2 3; do
          [[ -d /sys/module/$module ]] || break
          timeout 5 "$gpu_helper" rmmod "$module" >/dev/null 2>&1 || true
          sleep 0.2
        done
      done

      for node in "''${pci_nodes[@]}"; do
        if [[ -L $node/driver ]]; then
          log "driver rebound to ''${node##*/}; refusing dgpu_disable"
          restore_after_failed_eco
          return 1
        fi
      done
      return 0
    }

    apply_eco() {
      local dgpu_path mux_path mux_value current graphics find_status bdf slot node
      dgpu_path=$(resolve_asus_attribute dgpu_disable) || {
        log "dgpu_disable is unavailable; leaving Eco pending"
        return 1
      }

      current=$(<"$dgpu_path")
      [[ $current == 0 || $current == 1 ]] || {
        log "invalid dgpu_disable readback '$current'"
        return 1
      }

      mux_path=$(resolve_asus_attribute gpu_mux_mode)
      if [[ -n $mux_path ]]; then
        mux_value=$(<"$mux_path")
        [[ $mux_value == 0 || $mux_value == 1 ]] || {
          log "invalid gpu_mux_mode readback '$mux_value'"
          return 1
        }
        if [[ $mux_value == 0 ]]; then
          # Recover an already-impossible state, but never write disable=1 while
          # the dGPU is the sole display device.
          if [[ $current == 1 ]]; then
            printf '0\n' > "$dgpu_path" || true
            log "recovered MUX=0 with dgpu_disable=1 by enabling the dGPU"
          fi
          if printf '1\n' > "$mux_path"; then
            log "MUX=1 was latched for Eco; request remains pending until the next reboot"
          else
            log "MUX=0 makes Eco unsafe and MUX=1 could not be latched"
          fi
          return 1
        fi
      fi

      if [[ $current == 1 ]]; then
        log "Eco is already active"
        return 0
      fi

      graphics=$(find_nvidia_graphics)
      find_status=$?
      if [[ $find_status != 0 || -z $graphics ]]; then
        log "could not identify a safe non-primary NVIDIA dGPU"
        return 1
      fi
      bdf=''${graphics##*/}
      slot=''${bdf%.*}

      release_nvidia "$slot" || return 1

      # Recheck both invariants immediately before the only dangerous write.
      if [[ -n $mux_path && $(<"$mux_path") == 0 ]]; then
        log "MUX changed to 0 during release; aborting Eco"
        restore_after_failed_eco
        return 1
      fi
      for node in /sys/bus/pci/devices/"$slot".*; do
        if [[ -L $node/driver ]]; then
          log "''${node##*/} is still driver-bound; aborting Eco"
          restore_after_failed_eco
          return 1
        fi
      done

      printf '1\n' > "$dgpu_path"
      sleep 0.1
      current=$(<"$dgpu_path")
      if [[ $current != 1 ]]; then
        log "first dgpu_disable write read back '$current'; retrying"
        printf '1\n' > "$dgpu_path"
        sleep 0.1
        current=$(<"$dgpu_path")
      fi
      if [[ $current != 1 ]]; then
        log "dgpu_disable write failed; restoring the NVIDIA driver"
        restore_after_failed_eco
        return 1
      fi

      eco_release_in_progress=0
      log "Eco applied and dgpu_disable=1 confirmed"
      return 0
    }

    apply_enabled_mode() {
      local mode=$1 dgpu_path mux_path current mux_value target_mux
      dgpu_path=$(resolve_asus_attribute dgpu_disable) || {
        log "dgpu_disable is unavailable; leaving '$mode' pending"
        return 1
      }
      current=$(<"$dgpu_path")
      [[ $current == 0 || $current == 1 ]] || {
        log "invalid dgpu_disable readback '$current'"
        return 1
      }
      if [[ $current == 1 ]]; then
        printf '0\n' > "$dgpu_path"
        sleep 0.1
        current=$(<"$dgpu_path")
      fi
      if [[ $current != 0 ]]; then
        log "failed to enable the dGPU for '$mode'"
        return 1
      fi

      target_mux=1
      [[ $mode == ultimate ]] && target_mux=0
      mux_path=$(resolve_asus_attribute gpu_mux_mode)
      if [[ -z $mux_path ]]; then
        if [[ $mode == ultimate ]]; then
          log "gpu_mux_mode is unavailable; Ultimate cannot be verified"
          return 1
        fi
      else
        mux_value=$(<"$mux_path")
        [[ $mux_value == 0 || $mux_value == 1 ]] || {
          log "invalid gpu_mux_mode readback '$mux_value'"
          return 1
        }
        if [[ $mux_value != $target_mux ]]; then
          if printf '%s\n' "$target_mux" > "$mux_path"; then
            log "MUX=$target_mux was latched for '$mode'; request remains pending until the next reboot"
          else
            log "failed to latch MUX=$target_mux for '$mode'"
          fi
          return 1
        fi
      fi

      [[ -w /sys/bus/pci/rescan ]] && printf '1\n' > /sys/bus/pci/rescan
      log "'$mode' applied with dgpu_disable=0 and the expected MUX state"
      return 0
    }

    main() {
      local mode backend

      apply_mem_sleep
      udevadm settle --timeout=10 >/dev/null 2>&1 || true

      if [[ -f $pending_state ]]; then
        mode=$(read_state "$pending_state") || return 0
        log "applying pending GPU mode '$mode'"
      elif [[ -f $persistent_state ]]; then
        mode=$(read_state "$persistent_state") || return 0
        log "re-applying persistent GPU mode '$mode'"
      else
        return 0
      fi

      backend=asus-wmi
      if [[ -f $backend_state ]]; then
        backend=$(read_state "$backend_state") || backend=invalid
      fi
      if [[ $backend != asus-wmi ]]; then
        log "refusing unsupported GPU backend '$backend'"
        return 0
      fi

      case $mode in
        eco)
          if apply_eco; then
            rm -f -- "$pending_state"
          else
            log "Eco was not applied; pending state was preserved"
          fi
          ;;
        standard | optimized | ultimate)
          if apply_enabled_mode "$mode"; then
            rm -f -- "$pending_state"
          else
            log "'$mode' was not applied; pending state was preserved"
          fi
          ;;
        *)
          log "refusing invalid GPU mode state"
          ;;
      esac
    }

    main || true
    exit 0
  '';

  # G-Helper 直接写入内核公开的 sysfs 控制节点。把节点限制为 root 和
  # ghelper 组可写，避免上游 0666 规则让本机所有账号都能修改风扇、MUX 或功耗。
  setHardwarePermissions = pkgs.writeShellScript "ghelper-hardware-permissions" ''
    for ghelper_path in \
      /sys/devices/platform/asus-nb-wmi/{throttle_thermal_policy,panel_od,ppt_pl1_spl,ppt_pl2_sppt,ppt_fppt,ppt_apu_sppt,ppt_platform_sppt,nv_dynamic_boost,nv_temp_target,egpu_enable,boot_sound} \
      /sys/bus/platform/devices/asus-nb-wmi/{dgpu_disable,gpu_mux_mode,mini_led_mode} \
      /sys/class/firmware-attributes/asus-armoury/attributes/*/current_value \
      /sys/class/hwmon/hwmon*/pwm*_auto_point* \
      /sys/class/hwmon/hwmon*/pwm*_enable \
      /sys/class/power_supply/BAT*/charge_control_end_threshold \
      /sys/class/backlight/*/brightness \
      /sys/firmware/acpi/platform_profile \
      /sys/devices/system/cpu/intel_pstate/no_turbo \
      /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference \
      /sys/devices/system/cpu/cpu*/online \
      /sys/module/pcie_aspm/parameters/policy \
      /sys/bus/pci/rescan \
      /sys/class/leds/asus::kbd_backlight*/{brightness,multi_intensity,kbd_rgb_mode,kbd_rgb_state} \
      /sys/class/leds/asus::lightbar/brightness; do
      if [ -e "$ghelper_path" ]; then
        ${pkgs.coreutils}/bin/chgrp ghelper "$ghelper_path"
        ${pkgs.coreutils}/bin/chmod 0660 "$ghelper_path"
      fi
    done
  '';
in
{
  # 上游从 master 源码构建 GUI 和原生 GPU helper；后者仅在交互操作时
  # 通过 pkexec 请求管理员认证，不添加任何免密 sudo 规则。
  environment.systemPackages = [
    ghelper
    gpuHelper
    gpuStateHelper
  ];
  security.polkit.enable = true;

  # Native AOT 程序会在运行时解出少量动态库，上游目前依赖 nix-ld 查找它们。
  programs.nix-ld.enable = true;

  # Fn 键重映射使用 uinput；本机触摸板不是发光 NumberPad，不开放 i2c-dev。
  boot.kernelModules = [ "uinput" ];

  users.groups.ghelper = { };
  users.users.baka.extraGroups = [ "ghelper" ];

  # 热插拔设备节点只授权给当前 seat 或 ghelper 组，不使用上游的 MODE=0666。
  services.udev.extraRules = ''
    KERNEL=="uinput", OPTIONS+="static_node=uinput", TAG+="uaccess", GROUP="ghelper", MODE="0660"

    SUBSYSTEM=="input", ATTRS{name}=="Asus WMI hotkeys", TAG+="uaccess", GROUP="ghelper", MODE="0660"
    SUBSYSTEM=="input", KERNEL=="event*", ATTRS{id/vendor}=="0b05", TAG+="uaccess", GROUP="ghelper", MODE="0660"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0b05", TAG+="uaccess", GROUP="ghelper", MODE="0660"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0b05", TAG+="uaccess", GROUP="ghelper", MODE="0660"

    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", TAG+="uaccess", GROUP="ghelper", MODE="0660"
    SUBSYSTEM=="hidraw", KERNELS=="0005:046D:*", TAG+="uaccess", GROUP="ghelper", MODE="0660"

    ACTION=="add|change", SUBSYSTEM=="platform", DRIVER=="asus-nb-wmi", RUN+="${setHardwarePermissions}"
    ACTION=="add|change", SUBSYSTEM=="firmware-attributes", RUN+="${setHardwarePermissions}"
    ACTION=="add|change", SUBSYSTEM=="power_supply", RUN+="${setHardwarePermissions}"
    ACTION=="add|change", SUBSYSTEM=="backlight", RUN+="${setHardwarePermissions}"
    ACTION=="add|change", SUBSYSTEM=="hwmon", ATTR{name}=="asus_nb_wmi", RUN+="${setHardwarePermissions}"
    ACTION=="add|change", SUBSYSTEM=="hwmon", ATTR{name}=="asus_custom_fan_curve", RUN+="${setHardwarePermissions}"
    ACTION=="add|change", SUBSYSTEM=="cpu", KERNEL=="cpu0", RUN+="${setHardwarePermissions}"
  '';

  # 再在设备枚举完成后执行一次，覆盖启动早期尚未触发或晚创建的 sysfs 节点。
  systemd.services.ghelper-hardware-permissions = {
    description = "Restrict G-Helper hardware controls to the ghelper group";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-trigger.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = setHardwarePermissions;
      RemainAfterExit = true;
    };
  };

  systemd.services.ghelper-apply-state = {
    description = "Apply persistent G-Helper hardware state safely";
    wantedBy = [ "multi-user.target" ];
    before = [
      "display-manager.service"
      "graphical.target"
    ];
    after = [
      "systemd-modules-load.service"
      "systemd-udev-trigger.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = gpuBootApply;
      StateDirectory = "ghelper-nixos";
      StateDirectoryMode = "0755";
      UMask = "0022";
      TimeoutStartSec = "2min";
    };
  };
}
