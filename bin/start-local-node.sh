#!/bin/bash

set -ea

cmd_usage="Start local node

Usage: start-local-node.sh <path-to-package.json> [options]
  <path-to-package.json> must be an absolute path including file name

  Options:
  --override-major-version    - major version to use
  --override-minor-version    - minor version to use
  --dapi-branch               - dapi branch to be injected into dashman
  --drive-branch              - drive branch to be injected into dashman
  --sdk-branch                - Dash SDK (DashJS) branch to be injected into dashman
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
    --override-minor-version=*)
    minor_version="${i#*=}"
    ;;
    --dapi-branch=*)
    dapi_branch="${i#*=}"
    ;;
    --drive-branch=*)
    drive_branch="${i#*=}"
    ;;
    --sdk-branch=*)
    sdk_branch="${i#*=}"
    ;;
esac
done

# Define variables

DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CURRENT_VERSION=$("$DIR"/get-release-version "$PACKAGE_JSON_PATH" "$major_version")
DASHMAN_RELEASE_LINK=$("$DIR"/get-github-release-link "$PACKAGE_JSON_PATH" dashevo/dashman "$major_version" "$minor_version")

echo "Current version: ${CURRENT_VERSION}";

# Create temp dir
TMP="$DIR"/../tmp
rm -rf "$TMP"
mkdir "$TMP"

# Download dapi from defined branch
dashman_dapi_options="--dapi-image-build-path="
if [ -n "$dapi_branch" ]
then
  echo "Cloning DAPI from branch $dapi_branch"
  cd "$TMP"
  git clone https://github.com/dashevo/dapi.git
  cd "$TMP"/dapi
  git checkout "$dapi_branch"
  dashman_dapi_options="--dapi-image-build-path=$TMP/dapi"
fi

# Download drive from defined branch
dashman_drive_options="--drive-image-build-path="
if [ -n "$drive_branch" ]
then
  echo "Cloning Drive from branch $dapi_branch"
  cd "$TMP"
  git clone https://github.com/dashevo/drive.git
  cd "$TMP"/drive
  git checkout "$drive_branch"
  dashman_drive_options="--drive-image-build-path=$TMP/drive"
fi

# Download and install dashman
echo "Installing dashman"
curl -L "$DASHMAN_RELEASE_LINK" > "$TMP"/dashman.tar.gz
mkdir "$TMP"/dashman && tar -C "$TMP"/dashman -xvf "$TMP"/dashman.tar.gz
DASHMAN_RELEASE_LINK="$(ls "$TMP"/dashman)"
cd "$TMP"/dashman/"$DASHMAN_RELEASE_LINK"

npm ci

if [ -n "$sdk_branch" ]
then
  echo "Installing Dash SDK from branch $sdk_branch"
  npm i "github:dashevo/DashJS#$sdk_branch"
fi

npm link

# Setup node for local node dashman
echo "Setting up a local node"

dashman config:default local
dashman config:set core.miner.enable true
dashman config:set core.miner.interval 1s
dashman config:set environment development
dashman config:set platform.drive.abci.log.level debug

OUTPUT=$(dashman setup local "$dashman_dapi_options" "$dashman_drive_options")

FAUCET_PRIVATE_KEY=$(echo "$OUTPUT" | grep -m 1 "Private key:" | awk '{printf $4}')
DPNS_CONTRACT_ID=$(dashman config:get platform.dpns.contract.id)
DPNS_CONTRACT_BLOCK_HEIGHT=$(dashman config:get platform.dpns.contract.blockHeight)
DPNS_TOP_LEVEL_IDENTITY_ID=$(dashman config:get platform.dpns.ownerId)
DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY=$(echo "$OUTPUT" | grep -m 1 "HD private key:" | awk '{$1=""; printf $5}')

echo "Node is configured:"

echo "FAUCET_PRIVATE_KEY: ${FAUCET_PRIVATE_KEY}"
echo "DPNS_CONTRACT_ID: ${DPNS_CONTRACT_ID}"
echo "DPNS_CONTRACT_BLOCK_HEIGHT: ${DPNS_CONTRACT_BLOCK_HEIGHT}"
echo "DPNS_TOP_LEVEL_IDENTITY_ID: ${DPNS_TOP_LEVEL_IDENTITY_ID}"
echo "DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY: ${DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY}"


#Start dashman
echo "Starting dashman"
dashman start "$dashman_dapi_options" "$dashman_drive_options"

#Export variables
export CURRENT_VERSION
export FAUCET_PRIVATE_KEY
export DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY
export DPNS_TOP_LEVEL_IDENTITY_ID
export DPNS_CONTRACT_ID
export DPNS_CONTRACT_BLOCK_HEIGHT

echo "Success"
