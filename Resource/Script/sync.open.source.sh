#!/bin/bash

set -e
set -o pipefail

cd "$(dirname "$0")"
cd ../../
if [ ! -f ".root" ]; then
    echo "[*] unable to locate project directory"
    exit 1
fi

ORIG_DIR=$(pwd)
TARGET_DIR="/Users/qaq/Documents/GitHub/BBackupp"

if [ ! -d $TARGET_DIR ]; then
    echo "[*] target directory $TARGET_DIR does not exist"
    exit 1
fi

echo "[*] syncing from $ORIG_DIR to $TARGET_DIR"

if [ -n "$(git status --porcelain)" ]; then
    echo "[*] git repo at $ORIG_DIR has uncommitted changes"
    exit 1
fi

pushd $ORIG_DIR
git clean -fdx -f
git reset --hard
popd

pushd $TARGET_DIR
git clean -fdx -f
git reset --hard
popd

rm -rf $TARGET_DIR/*
cp -r $ORIG_DIR/* $TARGET_DIR

COMMIT_HASH=$(git rev-parse --short HEAD)

pushd $TARGET_DIR

PROHIBIT_FILE_LIST=(
    "BBackupp/Interface"
    "BBackupp/Backend/MuxProxy"
    "BBackupp/Library/ApplePackage"
    "BBackupp/Resources/Assets.xcassets"
    "MobileBackup/libimobiledevice"
)

for file in "${PROHIBIT_FILE_LIST[@]}"; do
    echo "[*] removing $file"
    rm -rf "$file"
done

find . -name ".DS_Store" -delete
find . -name ".swiftpm" -delete
find . -name "Package.resolved" -delete
find . -name "xcshareddata" -delete

sed -i '' '/DEVELOPMENT_TEAM/d' ./BBackupp.xcodeproj/project.pbxproj

git add .
git commit -m "Sync Update - $COMMIT_HASH"


echo "[*] done sync update with commit hash $COMMIT_HASH"

popd