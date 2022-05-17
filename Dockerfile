FROM python:3.9-slim-bullseye AS build_gstreamer

# Build Gstreamer
COPY ./scripts/install_gst.sh /install_gst.sh
RUN GST_VERSION=1.20.2 \
    ./install_gst.sh && rm /install_gst.sh

FROM python:3.9-slim-bullseye AS main

# Install Gstreamer
COPY --from=build_gstreamer /artifact/. /

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
    wget

RUN RCFILE_PATH="/etc/blueosrc" \
    && echo "alias cat='batcat --paging=never'" >> $RCFILE_PATH \
    && echo "alias ls=exa" >> $RCFILE_PATH \
    && echo "source $RCFILE_PATH" >> /etc/bash.bashrc