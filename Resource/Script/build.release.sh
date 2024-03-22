#!/bin/bash

set -e
set -o pipefail

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
    -configuration Release \
    -archivePath $ARCHIVE_PATH \
    clean archive \
    CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" \
    | xcbeautify 

