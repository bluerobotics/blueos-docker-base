#!/usr/bin/env bash

# exit when any command fails
set -e

# Check if the script is running as root
[[ $EUID != 0 ]] && echo "Script must run as root."  && exit 1

# Load passed parameters or default parameters

ARCH=${ARCH:-$(uname -m)}

# Because building WebRTCSink using buildx/qemu for armv7 is currently broken
# (see https://github.com/docker/buildx/issues/395), we are cross-building it
# via rust cross (https://github.com/cross-rs/cross), but using it with a
# tailored Bullseye image with GStreamer compiled for both armv7 and x86_64
# architectures, with all plugins we need.
# See https://github.com/joaoantoniocardoso/gstreamer_rust_cross_docker
if [[ $ARCH == x86_64 ]]; then
    WEBRTCSINK_BINARY_URL=https://s3.amazonaws.com/downloads.bluerobotics.com/BlueOS/artifacts/blueos-base/webrtcsink-gst-1.20.2-x86_64.zip
elif [[ $ARCH == armv7* ]]; then
    WEBRTCSINK_BINARY_URL=https://s3.amazonaws.com/downloads.bluerobotics.com/BlueOS/artifacts/blueos-base/webrtcsink-gst-1.20.2-armv7.zip
else
    echo "Unsupported architecture: $ARCH. The only supported architectures are x86_64 and armv7l"
    exit 1
fi

# Download, Install, Clean
cd /tmp
curl -O $WEBRTCSINK_BINARY_URL
unzip webrtcsink-gst-*.zip -d /tmp
mv $(find /tmp -type f -name libwebrtcsink.so) /usr/local/lib/gstreamer-1.0/.
rm -rf /tmp/*