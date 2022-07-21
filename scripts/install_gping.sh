#!/usr/bin/env bash

# exit when any command fails
set -e

TEMPORAY_PATH="/tmp/gping"
VERSION="gping-v1.3.2"

mkdir -p "$TEMPORAY_PATH"
cd "$TEMPORAY_PATH"

# By default we install armv7
REMOTE_BINARY_URL="https://github.com/orf/gping/releases/download/${VERSION}/gping-armv7-unknown-linux-musleabihf.tar.gz"
if [[ "$(uname -m)" == "x86_64"* ]]; then
    REMOTE_BINARY_URL="https://github.com/orf/gping/releases/download/${VERSION}/gping-x86_64-unknown-linux-musl.tar.gz"
fi

wget $REMOTE_BINARY_URL
tar xzf *.tar.gz

cp gping /usr/bin/gping

# Go to original folder
cd -
rm -rf "$TEMPORAY_PATH"