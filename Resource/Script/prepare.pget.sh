#!/bin/zsh

set -e
set -o pipefail

cd "$(dirname "$0")"

cd ../../
if [ ! -f ".root" ]; then
    echo "[*] unable to locate project directory"
    exit 1
fi

REPO="Code-Hex/pget"
TAG_NAME=$(curl --silent "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
echo "[*] fetching pget $TAG_NAME"

TAG_NAME_WITHOUT_V=$(echo $TAG_NAME | sed 's/v//')
AMD_BINARY="https://github.com/$REPO/releases/download/$TAG_NAME/pget_.$(echo $TAG_NAME_WITHOUT_V)_macOS_x86_64.tar.gz"
ARM_BINARY="https://github.com/$REPO/releases/download/$TAG_NAME/pget_.$(echo $TAG_NAME_WITHOUT_V)_macOS_arm64.tar.gz"

cd .cache

AMD_BINARY_PACKAGE="pget_darwin_amd64.tar.gz"
ARM_BINARY_PACKAGE="pget_darwin_arm64.tar.gz"

echo "[*] fetching $AMD_BINARY"
rm -f $AMD_BINARY_PACKAGE || true
curl -L -o $AMD_BINARY_PACKAGE $AMD_BINARY
echo "[*] fetching $ARM_BINARY"
rm -f $ARM_BINARY_PACKAGE || true
curl -L -o $ARM_BINARY_PACKAGE $ARM_BINARY

AMD_BINARY_TARGET="pget_darwin_amd64"
rm -rf $AMD_BINARY_TARGET || true
ARM_BINARY_TARGET="pget_darwin_arm64"
rm -rf $ARM_BINARY_TARGET || true

echo "[*] extracting $AMD_BINARY_PACKAGE"
rm -rf pget || true
tar -xvf $AMD_BINARY_PACKAGE pget
mv pget $AMD_BINARY_TARGET

echo "[*] extracting $ARM_BINARY_PACKAGE"
rm -rf pget || true
tar -xvf $ARM_BINARY_PACKAGE pget
mv pget $ARM_BINARY_TARGET

BINARY_TARGET="pget"
echo "[*] merging $AMD_BINARY_TARGET and $ARM_BINARY_TARGET into $BINARY_TARGET"
rm -f $BINARY_TARGET || true
lipo -create $AMD_BINARY_TARGET $ARM_BINARY_TARGET -output $BINARY_TARGET

chmod +x $BINARY_TARGET

file pget

echo "[*] done $0"