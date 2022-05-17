#!/usr/bin/env bash

# exit when any command fails
set -e

# Check if the script is running as root
[[ $EUID != 0 ]] && echo "Script must run as root."  && exit 1

GST_VERSION=${GST_VERSION:master}

echo "Going to install GST version: $GST_VERSION in 5 seconds.."
sleep 5s;

BUILD_TOOLS=(
    binutils
    bison
    flex
    g++
    git
    ninja-build
    pkg-config
)

BUILD_LIBS=(
    libavcodec-dev
    libavfilter-dev
    libavformat-dev
    libavutil-dev
    libc6-dev
    libgirepository1.0-dev
    libglib2.0-dev
    libssl-dev
    libv4l-dev
    libvpx-dev
    libx264-dev
    libxml2-dev
    python-gi-dev
)

# Install necessary dependencies
apt update

apt -y install ${BUILD_TOOLS[*]}
apt -y install ${BUILD_LIBS[*]}

pip3 install "meson==0.62.1"

# Download and install Gstreamer

cd /tmp
git clone --branch $GST_VERSION --single-branch --depth=1 \
    https://gitlab.freedesktop.org/gstreamer/gstreamer.git
cd gstreamer

meson builddir \
    --buildtype=release \
    --strip \
    -Dbad=enabled \
    -Dbase=enabled \
    -Ddevtools=enabled \
    -Dgpl=enabled \
    -Dgst-omx:target=generic \
    -Dgst-plugins-base:app=enabled \
    -Dgst-plugins-ugly:x264=enabled \
    -Dlibav=enabled \
    -Domx=enabled \
    -Dpython=enabled \
    -Drtsp_server=enabled \
    -Dugly=enabled

DESTDIR=/artifact ninja install -C builddir

# Install RTSP helpers
install -Dm755 builddir/subprojects/gst-rtsp-server/examples/test-mp4 /artifact/usr/local/bin/gst-rtsp-mp4
install -Dm755 builddir/subprojects/gst-rtsp-server/examples/test-launch /artifact/usr/local/bin/gst-rtsp-launch
install -Dm755 builddir/subprojects/gst-rtsp-server/examples/test-netclock /artifact/usr/local/bin/gst-rtsp-netclock
install -Dm755 builddir/subprojects/gst-rtsp-server/examples/test-netclock-client /artifact/usr/local/bin/gst-rtsp-netclock-client
