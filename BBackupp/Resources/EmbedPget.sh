#!/bin/zsh

set -e
set -o pipefail

echo "[*] reading from env"
echo "    PROJECT_DIR: $PROJECT_DIR"
echo "    CONFIGURATION: $CONFIGURATION"
echo "    CODESIGNING_FOLDER_PATH: $CODESIGNING_FOLDER_PATH"
echo "    CODE_SIGN_IDENTITY: $CODE_SIGN_IDENTITY"
echo "    CODE_SIGN_ENTITLEMENTS: $CODE_SIGN_ENTITLEMENTS"
echo "    DEVELOPMENT_TEAM: $DEVELOPMENT_TEAM"

CACHE_DIR="$(pwd)/.cache"
BINARY_CACHE="$CACHE_DIR/pget"

if [ -n "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
fi
if [ ! -f ".root" ]; then
    exit 1
fi

if [ "$CONFIGURATION" = "Release" ]; then
    rm -rf $CACHE_DIR
    echo "[*] removing .cache from release build"
fi
mkdir $CACHE_DIR || true

if [ -f "$BINARY_CACHE" ]; then
    echo "[*] using cached MobileBackup"
else
    echo "[*] fetch restic from GitHub"
    env -i /bin/zsh -c ./Resource/Script/prepare.pget.sh
fi

APP_PATH="$CODESIGNING_FOLDER_PATH"
AUX_BINARY_DIR="$APP_PATH/Contents/MacOS"
mkdir -p "$AUX_BINARY_DIR"

MOBILE_BACKUP_TARGET="$AUX_BINARY_DIR/pget"
cp "$BINARY_CACHE" "$MOBILE_BACKUP_TARGET"

echo "[*] done $0"
