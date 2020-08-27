#!/bin/bash

set -ea

cmd_usage="Start local node

Usage: prepare-mn-bootstrap.sh <path-to-package.json> [options]
  <path-to-package.json> must be an absolute path including file name

  Options:
  --override-major-version    - major version to use
  --dapi-branch               - dapi branch to be injected into mn-bootstrap
  --drive-branch              - drive branch to be injected into mn-bootstrap
"

PACKAGE_JSON_PATH="$1"

if [ -z "$PACKAGE_JSON_PATH" ]
then
  echo "Path to package.json is not specified"
  echo ""
  echo "$cmd_usage"
  exit 1
fi

for i in "$@"
do
case ${i} in
    -h|--help)
        echo "$cmd_usage"
        exit 0
    ;;
    --override-major-version=*)
    major_version="${i#*=}"
    ;;
    --dapi-branch=*)
    dapi_branch="${i#*=}"
    ;;
    --drive-branch=*)
    drive_branch="${i#*=}"
    ;;
esac
done

#Define variables
echo "Defining versions to download"
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CURRENT_VERSION=$("$DIR"/get-release-version "$PACKAGE_JSON_PATH" "$major_version")
MN_RELEASE_LINK=$("$DIR"/get-github-release-link "$PACKAGE_JSON_PATH" dashevo/mn-bootstrap "$major_version")

#Create temp dir
TMP="$DIR"/../tmp
rm -rf "$TMP"
mkdir "$TMP"

#Download dapi from defined branch
mn_bootstrap_dapi_options="--dapi-image-build-path="
if [ -n "$dapi_branch" ]
then
  echo "Cloning DAPI from branch $dapi_branch"
  cd "$TMP"
  git clone https://github.com/dashevo/dapi.git
  cd "$TMP"/dapi
  git checkout "$dapi_branch"
  mn_bootstrap_dapi_options="--dapi-image-build-path=$TMP/dapi"
fi
echo "$drive_branch"
#Download drive from defined branch
mn_bootstrap_drive_options="--drive-image-build-path="
if [ -n "$drive_branch" ]
then
  echo "Cloning Drive from branch $dapi_branch"
  cd "$TMP"
  git clone https://github.com/dashevo/drive.git
  cd "$TMP"/drive
  git checkout "$drive_branch"
  mn_bootstrap_drive_options="--drive-image-build-path=$TMP/drive"
fi

#Download and install mn-bootstrap
echo "Installing mn-bootstrap"
curl -L "$MN_RELEASE_LINK" > "$TMP"/mn-bootstrap.tar.gz
mkdir "$TMP"/mn-bootstrap && tar -C "$TMP"/mn-bootstrap -xvf "$TMP"/mn-bootstrap.tar.gz
MN_RELEASE_DIR="$(ls "$TMP"/mn-bootstrap)"
cd "$TMP"/mn-bootstrap/"$MN_RELEASE_DIR"
chmod -R 777 data
npm ci && npm link

#Initialize mn-bootstrap
echo "Initializing mn-bootstrap"
mn config:default local
OUTPUT=$(mn setup-for-local-development "$mn_bootstrap_dapi_options" "$mn_bootstrap_drive_options")
FAUCET_PRIVATE_KEY=$(echo "$OUTPUT" | grep -m 1 "Private key:" | awk '{printf $4}')
DPNS_CONTRACT_ID=$(echo "$OUTPUT" | grep -m 1 "DPNS contract ID:" | awk '{printf $5}')
DPNS_TOP_LEVEL_IDENTITY_ID=$(echo "$OUTPUT" | grep -m 1 "DPNS identity:" | awk '{printf $4}')
DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY=$(echo "$OUTPUT" | grep -m 1 "HD private key:" | awk '{$1=""; printf $5}')

#Start mn-bootstrap
echo "Starting mn-bootstrap"
mn start "$mn_bootstrap_dapi_options" "$mn_bootstrap_drive_options"

#Export variables
export CURRENT_VERSION
export FAUCET_PRIVATE_KEY
export DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY
export DPNS_TOP_LEVEL_IDENTITY_ID
export DPNS_CONTRACT_ID

echo "Success"
