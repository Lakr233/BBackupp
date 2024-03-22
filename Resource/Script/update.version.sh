#!/bin/bash

set -e
set -o pipefail

VERSION_FILE=BBackupp/Version.resolved
VERSION=$(cat $VERSION_FILE | xargs)
VERSION_MAJOR=$(echo $VERSION | cut -d. -f1)
VERSION_MINOR=$(echo $VERSION | cut -d. -f2)
VERSION_PATCH=$(echo $VERSION | cut -d. -f3)

echo "[*] reading version $VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH"

if [ -n "$CI_SKIP_BUMP_VERSION" ]; then
    echo "[*] environment variable indicates to skip bumping version"
else
    echo "[*] bumping version..."
    VERSION_PATCH=$((VERSION_PATCH + 1))
    if [ "$CONFIGURATION" = "Release" ]; then
        VERSION_MINOR=$((VERSION_MINOR + 1))
    fi
    echo "[*] will update version to $VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH"
    echo "$VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH" > $VERSION_FILE
fi

if [ -n "$CODESIGNING_FOLDER_PATH" ]; then
    echo "[*] updating Info.plist"
    INFO_PLIST="$CODESIGNING_FOLDER_PATH/Contents/Info.plist"

    echo "[*] updating CFBundleShortVersionString to $VERSION_MAJOR.$VERSION_MINOR"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION_MAJOR.$VERSION_MINOR" "$INFO_PLIST"

    echo "[*] updating CFBundleVersion to $VERSION_PATCH"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION_PATCH" "$INFO_PLIST"
fi

echo "[*] done $0"
