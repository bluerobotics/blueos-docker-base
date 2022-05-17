#!/usr/bin/env bash

# exit when any command fails
set -e

# Check if the script is running as root
[[ $EUID != 0 ]] && echo "Script must run as root."  && exit 1

echo "Going to install Webrtcsink version: $WEBRTCSINK_VERSION in 5 seconds.."
sleep 5s;

# Install Rust
apt-get install -y curl
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --profile=minimal -y
source $HOME/.cargo/env
rustup update stable
rustup default stable

# Download and Build Webrtcsink
cd /tmp
git clone https://github.com/centricular/webrtcsink
cd webrtcsink
git checkout $WEBRTCSINK_VERSION
PKG_CONFIG_PATH=/tmp/gstreamer/builddir/meson-uninstalled:/tmp/gstreamer/prefix/lib/pkgconfig:/artifact/usr/local/lib/x86_64-linux-gnu/pkgconfig \
cargo build --package webrtcsink --lib --release

# Pre-install Webrtcsink
cp -a /tmp/webrtcsink/target/release/libwebrtcsink.so $(dirname $(find /artifact -name libgstwebrtc-1.0.so | head -n1))
