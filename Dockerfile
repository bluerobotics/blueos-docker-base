# Global build environment variables
ARG GST_INSTALL_DIR=/artifacts
ARG GST_VERSION=1.24.1
ARG LIBCAMERA_ENABLED=true
ARG LIBCAMERA_VERSION=v0.3.0
ARG RPICAM_ENABLED=false
ARG GST_OMX_ENABLED=false


# Stage 1: Base Image
FROM python:3.11.7-slim-bullseye AS base

RUN <<-EOF
set -e
    # Add backports
    echo "deb http://deb.debian.org/debian bullseye-backports main contrib non-free" >> "/etc/apt/sources.list"

    # Setup cache
    rm -f /etc/apt/apt.conf.d/docker-clean
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' >/etc/apt/apt.conf.d/keep-cache
EOF


# Stage 2: Build GStreamer
FROM base AS gstreamer

ARG GST_INSTALL_DIR
ARG GST_VERSION
ARG LIBCAMERA_ENABLED
ARG LIBCAMERA_VERSION
ARG RPICAM_ENABLED
ARG GST_OMX_ENABLED

COPY ./scripts/build_gst.sh /build_gst.sh
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/root/.cache,sharing=locked \
    ./build_gst.sh \
    && rm -f /build_gst.sh


# Stage 3: Final Image
FROM base AS main

ARG GST_INSTALL_DIR
ARG LIBCAMERA_ENABLED
ARG RPICAM_ENABLED

# Setup the user environment
RUN <<-EOF
set -e
    RCFILE_PATH="/etc/blueosrc"
    echo "alias cat='batcat --paging=never'" >> "$RCFILE_PATH"
    echo "alias ls=exa" >> "$RCFILE_PATH"
    echo "cd ~" >> "$RCFILE_PATH"
    echo "source $RCFILE_PATH" >> "/etc/bash.bashrc"
EOF

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    # Install necessary tools and libs for basic use
        apt-get update \
        && apt-get install --assume-yes --no-install-recommends \
        # TOOLS:
            bat \
            bzip2 \
            curl \
            dnsmasq \
            dnsutils \
            exa \
            file \
            gdbserver \
            gettext \
            hostapd \
            htop \
            i2c-tools \
            ifmetric \
            # Note: Remove iotop if htop is newer 3.2+
            iotop \
            iproute2 \
            iperf3 \
            iputils-ping \
            iw \
            jq \
            less \
            libudev-dev \
            locate \
            lsof \
            mtr \
            nano \
            net-tools \
            nginx \
            parallel \
            rsync \
            screen \
            ssh \
            sshpass \
            sudo \
            tmux \
            tree \
            unzip \
            vim \
            watch \
            wget \
        # LIBS:
            libatm1 \
            libavcodec58 \
            libavfilter7 \
            libavformat58 \
            libavutil56 \
            libde265-0 \
            libdrm2 \
            libdv4 \
            libglib2.0-0 \
            libgudev-1.0-0 \
            libjson-glib-1.0-0 \
            libogg0 \
            libopenjp2-7 \
            libopus0 \
            libpulse0 \
            libsrtp2-1 \
            libtcl8.6 \
            libvorbis0a \
            libtk8.6 \
            libv4l-0 \
            libva-drm2/bullseye-backports \
            libva-glx2/bullseye-backports \
            libva-wayland2/bullseye-backports \
            libva-x11-2/bullseye-backports \
            libva2/bullseye-backports \
            libvpx6 \
            libyaml-0-2 \
            libx264-160 \
            libx265-192 \
            libxml2

# Install some tools
COPY ./scripts/install_viu.sh /install_viu.sh
RUN ./install_viu.sh && rm /install_viu.sh

COPY ./scripts/install_gping.sh /install_gping.sh
RUN ./install_gping.sh && rm /install_gping.sh

COPY ./scripts/install_simple_http_server.sh /install_simple_http_server.sh
RUN ./install_simple_http_server.sh && rm /install_simple_http_server.sh

# Install Pre-built GStreamer
COPY --from=gstreamer /artifacts/. /.

# Update links for the installed libraries and check if GStreamer is setup correctly
COPY ./scripts/inspect_gst_plugins.sh /inspect_gst_plugins.sh
RUN ldconfig \
    && /inspect_gst_plugins.sh \
    && mkdir -p /home/pi/tools \
    && mv /inspect_gst_plugins.sh /home/pi/tools/.
