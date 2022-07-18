#!/usr/bin/env bash

function clear_cache {
    rm -rf ~/.cache/gstreamer-1.0/registry.*.bin
}

PLUGINS=(
    decodebin3
    h264parse
    jpegenc
    libav
    multiudpsink
    queue
    rtph264pay
    srtpenc
    tcpserversink
    v4l2src
    videoconvert
    videotestsrc
    vp9enc
    webrtcbin
    x264enc
)

ARCH=${ARCH:-$(uname -m)}
GST_OMX_ENABLED=${GST_OMX_ENABLED:-true}
LIBCAMERA_ENABLED=${LIBCAMERA_ENABLED:-false}
if [[ $ARCH == arm* ]]; then
    RPICAM_ENABLED=${RPICAM_ENABLED:-true}

    if [ $RPICAM_ENABLED == true ] && [ -f /dev/vchiq ]; then
        # This test needs to be run in a Raspberry Pi hardware to work.
        PLUGINS+=(
            rpicamsrc
        )
    fi

    if [ $GST_OMX_ENABLED == true ]; then
        PLUGINS+=(
            omxh264enc
        )
    fi

else
    RPICAM_ENABLED=false
fi

if [ $GST_OMX_ENABLED == true ]; then
    PLUGINS+=(
        omx
    )
fi

if [ $LIBCAMERA_ENABLED == true ]; then
    PLUGINS+=(
        libcamera
        libcamerasrc
    )
fi

clear_cache

# Here we are individually checking for each plugin because gst-inspect-1.0 only returns the error
# code for the last item when a list is passed.
errors=0
for plugin in ${PLUGINS[@]}; do \
    # Check if gst-inspect can find the plugin
    filename=$(gst-inspect-1.0 $plugin | grep Filename | awk '{print $2}')
    if [ -z "$filename" ]; then
        let "errors++"
    # If found, check for possible missing links
    elif ldd -r "$filename" 2>&1 | grep -qF "undefined symbol\|not found\|???"; then
        echo "Error: $filename has at least one undefined symbol."
        let "errors++"
    fi
done
if [ $errors -gt 0 ]; then
    echo "Failed: found $errors errors."
fi

clear_cache

exit $errors
