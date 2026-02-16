# Global build environment variables
ARG GST_INSTALL_DIR=/artifacts
ARG GST_VERSION=1.26.10
ARG LIBCAMERA_ENABLED=true
ARG LIBCAMERA_VERSION=v0.3.1
ARG RPICAM_ENABLED=false
ARG GST_OMX_ENABLED=false


# Stage 1: Base Image
FROM python:3.11.7-slim-bookworm AS base

RUN <<-EOF
set -e
    # Add backports
    echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free" >> "/etc/apt/sources.list"

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

COPY --link ./scripts/build_gst.sh /build_gst.sh
ENV CCACHE_DIR=/ccache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/root/.cache,sharing=locked \
    --mount=type=cache,target=/ccache,sharing=locked \
    ./build_gst.sh \
    && rm -f /build_gst.sh \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Stage 3: Final Image
FROM base AS main

ARG GST_INSTALL_DIR
ARG LIBCAMERA_ENABLED
ARG RPICAM_ENABLED

# Setup the user environment
RUN <<-EOF
set -e
    RCFILE_PATH="/etc/blueosrc"
    {
      echo "alias cat='batcat --paging=never'"
      echo "alias ls=exa"
      echo "cd ~"
    } >> "$RCFILE_PATH"
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
            dhcpcd5 \
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
            isc-dhcp-client \
            # Note: Remove iotop if htop is newer 3.2+
            iotop \
            iproute2 \
            iperf3 \
            iproute2 \
            iptables \
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
            nmap \
            parallel \
            rsync \
            screen \
            ssh \
            sshpass \
            sudo \
            systemd \
            tmux \
            tree \
            unzip \
            vim-tiny \
            watch \
            wget \
        # LIBS:
            libatm1 \
            libatomic1 \
            libavcodec59 \
            libavfilter8 \
            libavformat59 \
            libavutil57 \
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
            libva-drm2 \
            libva-glx2 \
            libva-wayland2 \
            libva-x11-2 \
            libva2 \
            libvpx7 \
            libyaml-0-2 \
            libx264-164 \
            libx265-199 \
            libxml2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && ln -sf /usr/bin/vim.tiny /usr/bin/vim

# Install some tools
COPY --link ./scripts/install_viu.sh /install_viu.sh
RUN ./install_viu.sh && rm /install_viu.sh

COPY --link ./scripts/install_gping.sh /install_gping.sh
RUN ./install_gping.sh && rm /install_gping.sh

COPY --link ./scripts/install_simple_http_server.sh /install_simple_http_server.sh
RUN ./install_simple_http_server.sh && rm /install_simple_http_server.sh

# Install Pre-built GStreamer
COPY --from=gstreamer /artifacts/. /.

# Update links for the installed libraries and check if GStreamer is setup correctly
COPY --link ./scripts/inspect_gst_plugins.sh /inspect_gst_plugins.sh
RUN ldconfig \
    && /inspect_gst_plugins.sh \
    && mkdir -p /home/pi/tools \
    && mv /inspect_gst_plugins.sh /home/pi/tools/.
