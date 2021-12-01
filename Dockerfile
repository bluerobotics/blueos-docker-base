FROM python:3.9-slim-bullseye

# Create default user folder
RUN mkdir -p /home/pi

# Install gstreamer
COPY ./scripts/install_gst.sh /install_gst.sh
RUN GST_VERSION=1.18.5 ./install_gst.sh && rm /install_gst.sh

# Install necessary tools for basic usage
RUN apt install -y --no-install-recommends \
    dnsutils \
    file \
    htop \
    i2c-tools \
    iproute2 \
    iputils-ping \
    locate \
    lsof \
    nano \
    sshpass \
    tmux \
    unzip \
    watch \
    wget \