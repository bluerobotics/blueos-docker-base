#!/usr/bin/env bash

# exit when any command fails
set -e

VERSION="v0.6.9"

# By default we install armv7
REMOTE_BINARY_URL="https://github.com/TheWaWaR/simple-http-server/releases/download/${VERSION}/armv7-unknown-linux-musleabihf-simple-http-server"
if [[ "$(uname -m)" == "x86_64"* ]]; then
    REMOTE_BINARY_URL="https://github.com/TheWaWaR/simple-http-server/releases/download/${VERSION}/x86_64-unknown-linux-musl-simple-http-server"
fi

wget $REMOTE_BINARY_URL -O /usr/bin/simple-http-server
chmod +x /usr/bin/simple-http-server
