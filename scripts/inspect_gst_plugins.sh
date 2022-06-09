#!/usr/bin/env bash

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
exit $errors
