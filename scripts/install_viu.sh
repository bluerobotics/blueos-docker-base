#!/usr/bin/env bash

# exit when any command fails
set -e

VERSION="build_more"

# By default we install armv7
REMOTE_BINARY_URL="https://github.com/patrickelectric/viu/releases/download/${VERSION}/viu-armv7-unknown-linux-musleabihf"
if [[ "$(uname -m)" == "x86_64"* ]]; then
    REMOTE_BINARY_URL="https://github.com/patrickelectric/viu/releases/download/${VERSION}/viu-x86_64-unknown-linux-musl"
fi

wget $REMOTE_BINARY_URL -O /usr/bin/viu
chmod +x /usr/bin/viu