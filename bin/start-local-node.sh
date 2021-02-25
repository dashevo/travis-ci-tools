#!/bin/bash

set -ea

cmd_usage="Start local node

Usage: start-local-node.sh <path-to-package.json> [options]
  <path-to-package.json> must be an absolute path including file name

  Options:
  --override-major-version    - major version to use
  --override-minor-version    - minor version to use
  --node-count                - number of masternodes (default is 3)
  --dapi-branch               - dapi branch to be injected into mn-bootstrap
  --drive-branch              - drive branch to be injected into mn-bootstrap
  --sdk-branch                - Dash SDK (DashJS) branch to be injected into mn-bootstrap
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
    --node-count=*)
    node_count="${i#*=}"
    ;;
esac
done

# Define variables

DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CURRENT_VERSION=$("$DIR"/get-release-version "$PACKAGE_JSON_PATH" "$major_version")
MN_RELEASE_LINK=$("$DIR"/get-github-release-link "$PACKAGE_JSON_PATH" dashevo/mn-bootstrap "$major_version" "$minor_version")

echo "Current version: ${CURRENT_VERSION}";

# Create temp dir
TMP="$DIR"/../tmp
rm -rf "$TMP"
mkdir "$TMP"

# Download dapi from defined branch
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

# Download drive from defined branch
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

# Download and install mn-bootstrap
echo "Installing mn-bootstrap"
curl -L "$MN_RELEASE_LINK" > "$TMP"/mn-bootstrap.tar.gz
mkdir "$TMP"/mn-bootstrap && tar -C "$TMP"/mn-bootstrap -xvf "$TMP"/mn-bootstrap.tar.gz
MN_RELEASE_DIR="$(ls "$TMP"/mn-bootstrap)"
cd "$TMP"/mn-bootstrap/"$MN_RELEASE_DIR"

npm ci

if [ -n "$sdk_branch" ]
then
  echo "Installing Dash SDK from branch $sdk_branch"
  npm i "github:dashevo/DashJS#$sdk_branch"
fi

if [ -z "$node_count" ]
then
  node_count=3
fi

npm link

# Setup node for local node mn-bootstrap
echo "Setting up a local node"

OUTPUT=$(mn setup local --node-count="$node_count" "$mn_bootstrap_dapi_options" "$mn_bootstrap_drive_options")

FAUCET_PRIVATE_KEY=$(echo "$OUTPUT" | grep -m 1 "Private key:" | awk '{printf $4}')
DPNS_CONTRACT_ID=$(mn config:get --config=local_1 platform.dpns.contract.id)
DPNS_CONTRACT_BLOCK_HEIGHT=$(mn config:get --config=local_1 platform.dpns.contract.blockHeight)
DPNS_TOP_LEVEL_IDENTITY_ID=$(mn config:get --config=local_1 platform.dpns.ownerId)
DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY=$(echo "$OUTPUT" | grep -m 1 "HD private key:" | awk '{$1=""; printf $5}')

# Settings for masternodes
for (( i=1; i<=node_count; i++ ))
do
    mn config:set --config=local_"${i}" environment development
    mn config:set --config=local_"${i}" platform.drive.abci.log.stdout.level trace
done

# Settings for seed node
mn config:set --config=local_seed core.miner.enable true
mn config:set --config=local_seed core.miner.interval 1s

echo "Node is configured:"

echo "FAUCET_PRIVATE_KEY: ${FAUCET_PRIVATE_KEY}"
echo "DPNS_CONTRACT_ID: ${DPNS_CONTRACT_ID}"
echo "DPNS_CONTRACT_BLOCK_HEIGHT: ${DPNS_CONTRACT_BLOCK_HEIGHT}"
echo "DPNS_TOP_LEVEL_IDENTITY_ID: ${DPNS_TOP_LEVEL_IDENTITY_ID}"
echo "DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY: ${DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY}"


#Start mn-bootstrap
echo "Starting mn-bootstrap"
mn group:start "$mn_bootstrap_dapi_options" "$mn_bootstrap_drive_options"

#Export variables
export CURRENT_VERSION
export FAUCET_PRIVATE_KEY
export DPNS_TOP_LEVEL_IDENTITY_PRIVATE_KEY
export DPNS_TOP_LEVEL_IDENTITY_ID
export DPNS_CONTRACT_ID
export DPNS_CONTRACT_BLOCK_HEIGHT

echo "Success"
