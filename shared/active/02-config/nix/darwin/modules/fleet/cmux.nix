{ lib, stdenv, fetchurl, makeBinaryWrapper, _7zz }:

stdenv.mkDerivation rec {
  pname = "cmux";
  version = "0.64.10";

  src = fetchurl {
    url = "https://github.com/manaflow-ai/cmux/releases/download/v${version}/cmux-macos.dmg";
    hash = "sha256-+MKcMChZTFiDF482mVIh6mzeyKghDMV9gLA+6BjamXw=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ _7zz makeBinaryWrapper ];

  unpackCmd = ''7zz x -snld -xr'!*:com.apple.*' $curSrc'';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -R cmux.app $out/Applications/

    mkdir -p $out/bin
    makeBinaryWrapper \
      "$out/Applications/cmux.app/Contents/MacOS/cmux" \
      "$out/bin/cmux"

    runHook postInstall
  '';

  meta = {
    description = "cmux terminal multiplexer for macOS";
    homepage = "https://github.com/manaflow-ai/cmux";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-darwin" ];
  };
}
