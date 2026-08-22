# baka 的编程语言、IDE 与开发工具。
{ pkgs, ... }:

{
  home.sessionVariables = {
    # 统一复用 nixpkgs 已封装的浏览器，禁止 Playwright 首次运行另行下载。
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };

  home.packages = with pkgs; [
    # 显式包含 pip 与 Python Playwright；项目依赖仍应安装到 venv，
    # 而不是写入只读的 Nix store。浏览器路径由上面的会话变量统一指定。
    (python3.withPackages (pythonPackages: [
      pythonPackages.pip
      pythonPackages.playwright
    ]))
    nodejs
    bakaPackages.camoufox
    # 工具链自带 GOTOOLCHAIN 机制：go.mod 声明的版本高于此处的 go 时会自动下载
    # 对应版本到 GOPATH，因此不必为个别项目在这里钉死某个 go_1_xx。
    go
    # C/C++ 基础编译工具链与常用构建辅助；NixOS 默认环境不带 make/gcc，
    # file/pkg-config 也常被构建脚本假定存在。项目级复杂依赖仍建议用 devShell。
    gcc
    gnumake
    binutils
    pkg-config
    file
    # OpenChamber Web CLI 同样在 home/baka/ai.nix 安装，原因见那里的包装器注释。
    ast-grep
    # 命令行音视频转码；核显的 VA-API 栈见 hosts/bakaPC-NixOS/graphics.nix，
    # 可用 `ffmpeg -hwaccels` 确认 vaapi 可用。需要更多冷门编解码器时换成 ffmpeg-full。
    ffmpeg
    android-tools
    android-studio
    jetbrains.idea
    vscode
  ];
}
