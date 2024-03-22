#!/bin/zsh

set -e
set -o pipefail

cd "$(dirname $0)"/..

git submodule update --init --recursive

# MobileBackup/Sources/MobileBackup/
# idevicebackup2.c -> ../../libimobiledevice/tools/idevicebackup2.c

pushd ./Sources/MobileBackup/ > /dev/null

unlink idevicebackup2.c || true
cp ../../libimobiledevice/tools/idevicebackup2.c .

popd > /dev/null