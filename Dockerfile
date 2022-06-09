FROM python:3.9-slim-bullseye AS build_gstreamer

# Build and Pre-Install Gstreamer
COPY ./scripts/build_gst.sh /build_gst.sh
RUN GST_VERSION=1.20.2 \
    ./build_gst.sh && rm /build_gst.sh


FROM python:3.9-slim-bullseye AS main


# Create default user folder
RUN mkdir -p /home/pi

# Install Pre-built GStreamer
COPY --from=build_gstreamer /artifacts/. /.

# Install necessary tools for basic usage
RUN apt install -y --no-install-recommends \
    bat \
    dnsutils \
    exa \
    file \
    gdbserver \
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