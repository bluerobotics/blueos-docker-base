FROM python:3.9-slim-bullseye AS build_gstreamer

# Build Gstreamer
COPY ./scripts/build_gst.sh /build_gst.sh
RUN GST_VERSION=1.20.2 \
    ./build_gst.sh && rm /build_gst.sh

# Build Webrtcsink
COPY ./scripts/build_webrtcsink.sh /build_webrtcsink.sh
RUN WEBRTCSINK_VERSION="55d30db53bb3931f6477b6c1bad4de2a5ec5f7e4" \
    ./build_webrtcsink.sh && rm /build_webrtcsink.sh


FROM python:3.9-slim-bullseye AS main

# Install Gstreamer
COPY --from=build_gstreamer /artifact/. /
# Install necessary libs
RUN apt update && \
    apt install -y --no-install-recommends \
    libavcodec58 \
    libavfilter7 \
    libavformat58 \
    libavutil56 \
    libglib2.0-0 \
    libv4l-0 \
    libvpx6 \
    libx264-160

# Create default user folder
RUN mkdir -p /home/pi

# Install necessary tools for basic usage
RUN apt install -y --no-install-recommends \
    bat \
    dnsutils \
    exa \
    file \
    htop \
    i2c-tools \
    iproute2 \
    iputils-ping \
    jq \
    less \
    locate \
    lsof \
    nano \
    parallel \
    screen \
    ssh \
    sshpass \
    tmux \
    unzip \
    watch \
    wget && \
    apt autoremove -y && \
    apt clean

# Update dynamic library cache, and make sure that we have
# the necessary elements for stream to work
COPY ./scripts/inspect_gst_plugins.sh /inspect_gst_plugins.sh
RUN export GST_PLUGIN_SYSTEM_PATH=$(dirname $(find /usr/local/lib -name libgstwebrtc-1.0.so | head -n1)) && \
    ldconfig && \
    ./inspect_gst_plugins.sh && rm /inspect_gst_plugins.sh

RUN RCFILE_PATH="/etc/blueosrc" \
    && echo "alias cat='batcat --paging=never'" >> $RCFILE_PATH \
    && echo "alias ls=exa" >> $RCFILE_PATH \
    && echo "source $RCFILE_PATH" >> /etc/bash.bashrc \
    && echo "export GST_PLUGIN_SYSTEM_PATH=$(dirname $(find /usr/local/lib -name libgstwebrtc-1.0.so | head -n1))" >> /etc/bash.bashrc
