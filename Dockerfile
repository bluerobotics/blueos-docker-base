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

# Install necessary tools and libs for basic use
RUN apt update && \
    apt install --assume-yes --no-install-recommends \
    # TOOLS:
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
        wget \
    # LIBS:
        libatm1 \
        libavcodec58 \
        libavfilter7 \
        libavformat58 \
        libavutil56 \
        libdv4 \
        libglib2.0-0 \
        libjson-glib-1.0-0 \
        libsrtp2-1 \
        libtcl8.6 \
        libtk8.6 \
        libv4l-0 \
        libvpx6 \
        libx264-160 \
        libxml2

RUN RCFILE_PATH="/etc/blueosrc" \
    && echo "alias cat='batcat --paging=never'" >> $RCFILE_PATH \
    && echo "alias ls=exa" >> $RCFILE_PATH \
    && echo "source $RCFILE_PATH" >> /etc/bash.bashrc