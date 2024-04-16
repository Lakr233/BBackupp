#!/bin/bash

set -e
set -o pipefail

HIKARI_TOOLCHAIN="/Users/qaq/Library/Developer/Toolchains/Hikari.LLVM.15.2.xctoolchain"
if [ ! -d "$HIKARI_TOOLCHAIN" ]; then
    echo "[!] Hikari toolchain not found"
    exit 1
fi

ARCHIVE_PATH="BBackupp.xcarchive"

cd "$(dirname "$0")/../.."

if [ ! -f .root ]; then
    echo "[!] .root file not found"
    exit 1
fi

git clean -fdx -f
git submodule update --init --recursive

xcodebuild \
    -workspace BBackupp.xcworkspace \
    -scheme BBackupp \
    -toolchain $HIKARI_TOOLCHAIN \
    -configuration Release \
    -archivePath $ARCHIVE_PATH \
    clean archive \
    CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" \
    GCC_OPTIMIZATION_LEVEL=0 SWIFT_OPTIMIZATION_LEVEL=-Onone \
    | xcbeautify

