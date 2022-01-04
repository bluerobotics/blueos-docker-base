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
    nasm
    ninja-build
    pkg-config
)

BUILD_LIBS=(
    libgirepository1.0-dev
    libglib2.0-0
    libgtest-dev
    libmount-dev
)

# Install necessary dependencies
apt update

apt -y install ${BUILD_TOOLS[*]}
apt -y install ${BUILD_LIBS[*]}

pip3 install "meson==0.58"

# Download and install gstreamer via gst-build

cd /tmp
git clone -b $GST_VERSION --single-branch --depth=1 https://github.com/GStreamer/gst-build
cd gst-build

meson builddir \
    --buildtype=release \
    -Domx=enabled \
    -Dpython=enabled \
    -Drtsp_server=enabled \
    -Dgst-omx:target=generic \

ninja install -C builddir

# Install RTSP helpers
install -Dm755 builddir/subprojects/gst-rtsp-server/examples/test-mp4 /usr/bin/gst-rtsp-mp4
install -Dm755 builddir/subprojects/gst-rtsp-server/examples/test-launch /usr/bin/gst-rtsp-launch
install -Dm755 builddir/subprojects/gst-rtsp-server/examples/test-netclock /usr/bin/gst-rtsp-netclock
install -Dm755 builddir/subprojects/gst-rtsp-server/examples/test-netclock-client /usr/bin/gst-rtsp-netclock-client

# Remove build files and dependencies
cd /tmp
rm -rf gst-build

pip3 uninstall -y meson

## Remove debug symbols
GST_DLL_FOLDER=$(find / | grep libavutil.so | head -n 1 | xargs dirname)
find $GST_DLL_FOLDER/* | grep \\.so | xargs strip

apt -y remove ${BUILD_TOOLS[*]}
apt -y autoremove
apt -y clean

# Make sure that we have the necessary elements for stream to work
gst-inspect-1.0 \
    rtph264pay \
    udpsink \
    videoconvert \
    videotestsrc \
    x264enc
