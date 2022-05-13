# syntax = docker/dockerfile:experimental
FROM python:3.9-slim-bullseye

# Create default user folder
RUN mkdir -p /home/pi

# Configure cargo workaround for 32bits emulation on 64bits
# reference: https://github.com/rust-lang/cargo/issues/8719
# Install gstreamer
COPY ./scripts/install_gst.sh /install_gst.sh
COPY ./scripts/rustup_init.sh /rustup_init.sh
RUN --security=insecure mkdir -p /root/.cargo && chmod 777 /root/.cargo && mount -t tmpfs none /root/.cargo && GST_VERSION=1.20.2 ./install_gst.sh && rm /install_gst.sh /rustup_init.sh

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