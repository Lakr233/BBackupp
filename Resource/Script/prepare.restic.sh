#!/bin/zsh

set -e
set -o pipefail

cd "$(dirname "$0")"

cd ../../
if [ ! -f ".root" ]; then
    echo "[*] unable to locate project directory"
    exit 1
fi

REPO="restic/restic"
TAG_NAME=$(curl --silent "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
echo "[*] fetching restic $TAG_NAME"

TAG_NAME_WITHOUT_V=$(echo $TAG_NAME | sed 's/v//')
AMD_BINARY="https://github.com/$REPO/releases/download/$TAG_NAME/restic_$(echo $TAG_NAME_WITHOUT_V)_darwin_amd64.bz2"
ARM_BINARY="https://github.com/$REPO/releases/download/$TAG_NAME/restic_$(echo $TAG_NAME_WITHOUT_V)_darwin_arm64.bz2"

AMD_BINARY_PACKAGE=".cache/restic_darwin_amd64.bz2"
ARM_BINARY_PACKAGE=".cache/restic_darwin_arm64.bz2"

echo "[*] fetching $AMD_BINARY"
rm -f $AMD_BINARY_PACKAGE || true
curl -L -o $AMD_BINARY_PACKAGE $AMD_BINARY
echo "[*] fetching $ARM_BINARY"
rm -f $ARM_BINARY_PACKAGE || true
curl -L -o $ARM_BINARY_PACKAGE $ARM_BINARY

AMD_BINARY_TARGET=".cache/restic_darwin_amd64"
ARM_BINARY_TARGET=".cache/restic_darwin_arm64"

echo "[*] extracting $AMD_BINARY_PACKAGE"
rm -f $AMD_BINARY_TARGET || true
bzip2 -d $AMD_BINARY_PACKAGE
echo "[*] extracting $ARM_BINARY_PACKAGE"
rm -f $ARM_BINARY_TARGET || true
bzip2 -d $ARM_BINARY_PACKAGE

BINARY_TARGET=".cache/restic"
echo "[*] merging $AMD_BINARY_TARGET and $ARM_BINARY_TARGET into $BINARY_TARGET"
rm -f $BINARY_TARGET || true
lipo -create $AMD_BINARY_TARGET $ARM_BINARY_TARGET -output $BINARY_TARGET

chmod +x $BINARY_TARGET

pushd .cache
file restic
popd

echo "[*] done $0"