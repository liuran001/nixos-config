# 时区、语言环境和 Fcitx 5 中文输入法。
{ pkgs, ... }:

{
  # 设置系统时区为中国标准时间（北京时间，UTC+8）。
  time.timeZone = "Asia/Shanghai";

  # 设置默认语言环境。这里保留英文界面，同时保证程序使用 UTF-8 编码。
  i18n.defaultLocale = "en_US.UTF-8";

  # 单独将地址、计量单位、货币、姓名、数字、纸张、电话和日期时间格式设为中国大陆格式。
  # 这些设置主要影响日期、金额等显示方式，不会把 KDE 或应用程序界面改成中文。
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  # 启用 Fcitx 5 中文输入法框架。登录桌面后按 Ctrl+Space 可在英文和中文之间切换。
  # KDE Wayland 如果无法输入，可在“系统设置 → 虚拟键盘”中选择“Fcitx 5”，然后注销并重新登录。
  i18n.inputMethod = {
    # 输入法总开关。
    enable = true;
    # 指定使用 Fcitx 5，而不是 IBus 等其他输入法框架。
    type = "fcitx5";
    fcitx5 = {
      # 安装中文拼音插件和 Rime（中州韵）引擎；当前默认使用普通拼音。
      addons = [
        pkgs.qt6Packages.fcitx5-chinese-addons # 提供拼音、双拼、五笔等常用中文输入方式。
        pkgs.fcitx5-rime # 提供可高度自定义的 Rime 输入法框架。
      ];
      # 预先创建一个输入法组，避免首次启动后还要手动添加英文键盘和拼音。
      settings.inputMethod = {
        "Groups/0" = {
          Name = "Default"; # 输入法组名称。
          "Default Layout" = "us"; # 默认使用美式键盘布局。
          DefaultIM = "pinyin"; # 激活输入法时默认进入拼音。
        };
        # 输入法组中的第一个项目是英文键盘。
        "Groups/0/Items/0" = {
          Name = "keyboard-us";
          Layout = "";
        };
        # 输入法组中的第二个项目是中文拼音。
        "Groups/0/Items/1" = {
          Name = "pinyin";
          Layout = "";
        };
        # 指定输入法组的显示顺序。
        GroupOrder."0" = "Default";
      };
    };
  };
}
