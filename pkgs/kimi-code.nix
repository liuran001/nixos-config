# Kimi Code 命令行编程助手：官方 Linux x64 二进制的 Nix 封装。
# 当前 nixpkgs 尚未收录 Kimi，因此封装官方发行版；版本和 SHA-256 均固定，
# 重新构建时会验证下载内容。升级时修改 version 并重新计算 hash。
{
  stdenvNoCC,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  unzip,
  lib,
}:

stdenvNoCC.mkDerivation rec {
  pname = "kimi-code";
  version = "0.37.2";

  src = fetchurl {
    url = "https://github.com/MoonshotAI/kimi-code/releases/download/%40moonshot-ai/kimi-code%40${version}/kimi-code-linux-x64.zip";
    hash = "sha256-GmbZylCRxiDnsulrq7QU3YUH4yTYbTmwEc95ElyovQk=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
  ];
  buildInputs = [ stdenv.cc.cc.lib ];
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    unzip "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 kimi "$out/bin/kimi"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Kimi Code command-line coding agent";
    homepage = "https://github.com/MoonshotAI/kimi-code";
    license = licenses.mit;
    mainProgram = "kimi";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
