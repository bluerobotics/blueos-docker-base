FROM python:3.11.7-slim-bullseye AS build_gstreamer

# Build and Pre-Install Gstreamer
COPY ./scripts/build_gst.sh /build_gst.sh
RUN GST_VERSION=1.24.1 \
    LIBCAMERA_VERSION=v0.3.0 LIBCAMERA_ENABLED=true \
    RPICAM_ENABLED=false \
    GST_OMX_ENABLED=false \
    ./build_gst.sh && rm /build_gst.sh


FROM python:3.11.7-slim-bullseye AS main


# Setup the user environment
RUN mkdir -p /home/pi && \
    RCFILE_PATH="/etc/blueosrc" && \
    echo "alias cat='batcat --paging=never'" >> $RCFILE_PATH && \
    echo "alias ls=exa" >> $RCFILE_PATH && \
    echo "cd ~" >> $RCFILE_PATH && \
    echo "source $RCFILE_PATH" >> /etc/bash.bashrc

# Add backports
RUN echo "deb http://deb.debian.org/debian bullseye-backports main contrib non-free" | tee -a /etc/apt/sources.list

# Install necessary tools and libs for basic use
# Note: Remove iotop if htop is newer 3.2+
RUN apt update && \
    apt install --assume-yes --no-install-recommends \
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
        libxml2 \
    # Clean it
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Pre-built GStreamer
COPY --from=build_gstreamer /artifacts/. /.

# Update links for the installed libraries and check if GStreamer is setup correctly
COPY ./scripts/inspect_gst_plugins.sh /inspect_gst_plugins.sh
RUN ldconfig && \
    LIBCAMERA_ENABLED=true RPICAM_ENABLED=false GST_OMX_ENABLED=false /inspect_gst_plugins.sh && \
    mkdir -p /home/pi/tools && \
    mv /inspect_gst_plugins.sh /home/pi/tools/.

# Install some tools
COPY ./scripts/install_viu.sh /install_viu.sh
RUN ./install_viu.sh && rm /install_viu.sh

COPY ./scripts/install_gping.sh /install_gping.sh
RUN ./install_gping.sh && rm /install_gping.sh

COPY ./scripts/install_simple_http_server.sh /install_simple_http_server.sh
RUN ./install_simple_http_server.sh && rm /install_simple_http_server.sh
