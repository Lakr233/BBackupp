#!/bin/bash

set -e
set -o pipefail

cd "$(dirname "$0")"

cd ../../
if [ ! -f ".root" ]; then
    echo "[*] unable to locate project directory"
    exit 1
fi

RESOLVED_FILE=BBackupp.xcworkspace/xcshareddata/swiftpm/Package.resolved
OUTPUT_FILE=BBackupp/License.resolved

export PATH=$PATH:/opt/homebrew/bin/

echo "# BBackupp License" > $OUTPUT_FILE
printf "\n\n" >> $OUTPUT_FILE
cat ./LICENSE >> $OUTPUT_FILE
printf "\n\n" >> $OUTPUT_FILE

function WriteLicense() {
    REPO_OWNER=$1
    REPO_NAME=$2

    echo "[*] fetching license for $REPO_OWNER/$REPO_NAME"
    LICENSE_JSON=$(curl -s -L \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/license")

    LICENSE_CONTENT=$(echo $LICENSE_JSON | jq -r '.content' | base64 --decode)
    echo "[*] fetched $LICENSE_CONTENT" | head -n 1 

    echo "## $REPO_NAME" >> $OUTPUT_FILE
    printf "\n\n" >> $OUTPUT_FILE
    echo "$LICENSE_CONTENT" >> $OUTPUT_FILE
    printf "\n\n" >> $OUTPUT_FILE
}

jq -r '.pins[].location' < $RESOLVED_FILE | sort | while read -r line; do
    if [[ $line == "https://github.com/"* ]]; then
        # call to github api for license information
        # https://docs.github.com/en/rest/licenses/licenses?apiVersion=2022-11-28#get-the-license-for-a-repository

        REPO_OWNER=$(echo $line | cut -d'/' -f4)
        REPO_NAME=$(echo $line | cut -d'/' -f5)
        REPO_NAME=${REPO_NAME%.git}

        WriteLicense $REPO_OWNER $REPO_NAME

        continue
    fi
    echo "[-] unable to resolve license for $line"
    exit 1
done

WriteLicense "Flight-School" "AnyCodable"
WriteLicense "dlevi309" "ipatool-ios"
WriteLicense "Code-Hex" "pget"
WriteLicense "restic" "restic"
WriteLicense "libimobiledevice" "libimobiledevice"
WriteLicense "openssl" "openssl"

echo "[*] done"
