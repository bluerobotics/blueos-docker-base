#!/usr/bin/env bash

# exit when any command fails
set -e

# Check if the script is running as root
[[ $EUID != 0 ]] && echo "Script must run as root."  && exit 1

# Load passed parameters or default parameters

# Versions older than 1.20 should use: https://github.com/GStreamer/gst-build
# reference: https://gitlab.freedesktop.org/gstreamer/gst-build/-/issues/195
GST_GIT_URL=${GST_GIT_URL:-https://gitlab.freedesktop.org/gstreamer/gstreamer.git}
GST_VERSION=${GST_VERSION:-main}
# This install directory will be accessed by other stages of the docker build:
GST_INSTALL_DIR=${GST_INSTALL_DIR:-/artifacts}
GST_OMX_ENABLED=${GST_OMX_ENABLED:-true}
LIBCAMERA_ENABLED=${LIBCAMERA_ENABLED:-false}
LIBCAMERA_VERSION=${LIBCAMERA_VERSION:-master}
LIBCAMERA_GIT_URL=${LIBCAMERA_GIT_URL:-https://git.libcamera.org/libcamera/libcamera.git}
ARCH=${ARCH:-$(uname -m)}
# RPICAM is only supported for arm
if [[ $ARCH == arm* ]]; then
    RPICAM_ENABLED=${RPICAM_ENABLED:-true}
else
    RPICAM_ENABLED=false
fi

# Here we carefully select what we want to build/install. Even though several
# of the listed options are disabled by default, it is interesting to have
# them here to be documented.
# Most of the options are visible on meson_options.txt files under each
# GStreamer (sub)project root folder, like: https://gitlab.freedesktop.org/gstreamer/gstreamer/-/blob/main/subprojects/gst-plugins-bad/meson_options.txt
GST_MESON_OPTIONS_DEFAULT=(
    --buildtype=release
    --strip
    -D bad=enabled
    -D devtools=enabled
    -D doc=disabled
    -D ges=disabled
    -D gpl=enabled
    -D gst-plugins-bad:libde265=enabled
    -D gst-plugins-bad:openh264=disabled
    -D gst-plugins-bad:rtp=enabled
    -D gst-plugins-bad:x265=enabled
    -D gst-plugins-base:tcp=enabled
    -D gst-plugins-good:cairo=disabled
    -D gst-plugins-good:jpeg=enabled
    -D gst-plugins-good:rtsp=enabled
    -D gst-plugins-good:udp=enabled
    -D gst-plugins-good:v4l2=enabled
    -D gst-plugins-good:vpx=enabled
    -D gst-plugins-ugly:x264=enabled
    -D gst-rtsp-server:examples=enabled
    -D introspection=disabled
    -D libav=enabled
    -D nls=disabled
    -D orc=disabled
    -D python=$( [[ "$GST_PYTHON_ENABLED" == true ]] && echo enabled || echo disabled )
    -D qt5=disabled
    -D rs=disabled
    -D rtsp_server=enabled
    -D tests=disabled
    -D tls=enabled
    -D ugly=enabled
)
GST_MESON_OPTIONS=${GST_MESON_OPTIONS:-${GST_MESON_OPTIONS_DEFAULT[@]}}
# If enabled, add OMX build configurations to the GST_MESON_OPTIONS array
if [ $GST_OMX_ENABLED == true ]; then
    GST_MESON_OPTIONS+=(
        -D omx=enabled
    )
    if [[ $ARCH == x86_64 ]]; then
        GST_MESON_OPTIONS+=(
            -D gst-omx:target=generic
        )
    elif [[ $ARCH == arm* ]]; then
        # To build omx for the "rpi" target, we need to provide the raspberrypi
        # IL headers:
        USERLAND_PATH=/tmp/userland
        GST_MESON_OPTIONS+=(
            -D gst-omx:target=rpi
            -D gst-omx:header_path=$USERLAND_PATH/interface/vmcs_host/khronos/IL
        )
    fi
fi
if [ $LIBCAMERA_ENABLED == true ]; then
    GST_MESON_OPTIONS+=(
        -D custom_subprojects=libcamera
        -D libcamera:cpp_std=c++17
        -D libcamera:cam=disabled
        -D libcamera:documentation=disabled
        -D libcamera:gstreamer=enabled
        -D libcamera:ipas=raspberrypi
        -D libcamera:pipelines=raspberrypi
        -D libcamera:pycamera=disabled
        -D libcamera:qcam=disabled
        -D libcamera:test=false
        -D libcamera:tracing=disabled
        -D libcamera:v4l2=true
    )
fi
if [ $RPICAM_ENABLED == true ]; then
    GST_MESON_OPTIONS+=(
        -D gst-plugins-good:rpicamsrc=enabled
        -D gst-plugins-good:rpi-header-dir=$GST_INSTALL_DIR/opt/vc/include
        -D gst-plugins-good:rpi-lib-dir=$GST_INSTALL_DIR/opt/vc/lib
        -D gst-plugins-good:replaygain=disabled
    )
fi

# These are the tools needed to build GStreamer
GST_BUILD_TOOLS_DEFAULT=(
    apt-transport-https
    bison
    ca-certificates
    cmake
    curl
    flex
    g++
    gcc
    git
    make
    ninja-build
    pkg-config
    python-gi-dev
)
GST_BUILD_TOOLS=${GST_BUILD_TOOLS:-${GST_BUILD_TOOLS_DEFAULT[@]}}

# Although to build GStreamer essentially we need only a few libraries, here we
# are actively providing several libraries which would otherwise be compiled
# from its sources, to basically have a reduced build time.
# Some libraries are not included here because their version on debian:bullseye
# may not satisfy GStreamer's dependencies, like fdk_aac (2.0.2),
# lame (3.100), libnice (0.1.18.1), libsoup (2.74.0), and sqlite3 (3.34.1).
GST_BUILD_LIBS_DEFAULT=(
    libavcodec-dev
    libavfilter-dev
    libavformat-dev
    libavutil-dev
    libc-dev
    libcgroup-dev
    libde265-dev
    libdrm-dev
    libdv4-dev
    libfontconfig-dev
    libfreetype-dev
    libfribidi-dev
    libharfbuzz-dev
    libjpeg-dev
    libjson-glib-dev
    libogg-dev
    libopenjp2-7-dev
    libopus-dev
    libpango1.0-dev
    libpixman-1-dev
    libpng-dev
    libpsl-dev
    libsrtp2-dev
    libssl-dev
    libsysprof-4-dev
    libv4l-dev
    libva-dev
    libvorbis-dev
    libvpx-dev
    libx264-dev
    libx265-dev
    libxml2-dev
)
GST_BUILD_LIBS=${GST_BUILD_LIBS:-${GST_BUILD_LIBS_DEFAULT[@]}}
if [ $LIBCAMERA_ENABLED == true ]; then
    GST_BUILD_LIBS+=(
        libgnutls28-dev
        libboost-dev
    )
fi

GST_PIP_DEPENDENCIES=(
    "mako==1.2.0"
    "markdown==3.3.7"
    "meson==0.63"
)
if [ $LIBCAMERA_ENABLED == true ]; then
    GST_PIP_DEPENDENCIES+=(
        "jinja2==3.1.2"
        "ply==3.11"
        "pyyaml==6.0"
    )
fi

cat << EOF
Going to build and install GStreamer in 5 seconds...
GIT: $GST_GIT_URL
Version: $GST_VERSION
Install path: $GST_INSTALL_DIR
Architecture: $ARCH
GStreamer Meson Options:
    ${GST_MESON_OPTIONS[@]}
GStreamer tool dependencies to be installed from APT:
    ${GST_BUILD_TOOLS[@]}
GStreamer library dependencies to be installed from APT:
    ${GST_BUILD_LIBS[@]}
GStreamer dependencies to be installed from PIP:
    ${GST_PIP_DEPENDENCIES[@]}
EOF
sleep 5s;

# Install all dependencies

apt update
apt install --assume-yes --no-install-recommends --mark-auto \
    ${GST_BUILD_TOOLS[@]} ${GST_BUILD_LIBS[@]}
pip3 install ${GST_PIP_DEPENDENCIES[@]}

# Download and install IL headers if needed:
if [ -n "$USERLAND_PATH" ]; then
    git clone https://github.com/raspberrypi/userland.git $USERLAND_PATH
    cd $USERLAND_PATH
    git checkout 54fd97ae4066a10b6b02089bc769ceed328737e0

    sed -i "s/sudo//g" buildme  # remove any sudo call
    ./buildme $GST_INSTALL_DIR

    # Let linux aware of userland libs, needed in runtime
    mkdir -p $GST_INSTALL_DIR/etc/ld.so.conf.d/
    echo "/opt/vc/lib" > $GST_INSTALL_DIR/etc/ld.so.conf.d/userland.conf

    cd $OLDPWD
fi

# Download, build, and pre-install Gstreamer

git clone --branch $GST_VERSION --single-branch --depth=1 \
    $GST_GIT_URL gstreamer
cd gstreamer

if [ $LIBCAMERA_ENABLED == true ]; then
    cat << EOF > subprojects/libcamera.wrap
[wrap-git]
directory=libcamera
url=$LIBCAMERA_GIT_URL
revision=$LIBCAMERA_VERSION
EOF
fi

GST_BUILD_DIR=builddir
meson $GST_BUILD_DIR ${GST_MESON_OPTIONS[@]}

DESTDIR=$GST_INSTALL_DIR ninja install -C $GST_BUILD_DIR

# Pre-install RTSP helpers
GST_RTSP_HELPERS=(
    test-mp4
    test-launch
    test-netclock
    test-netclock-client
)
for file in ${GST_RTSP_HELPERS[@]}; do
    install -Dm755 $GST_BUILD_DIR/subprojects/gst-rtsp-server/examples/$file \
        $GST_INSTALL_DIR/usr/local/bin/$file
done

# Clean the docker image
rm -rf build
apt autoremove -y