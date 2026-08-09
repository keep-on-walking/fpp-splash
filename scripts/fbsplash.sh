#!/bin/bash
# fpp-splash renderer
#
# Renders the configured splash frame as raw framebuffer pixels.
#   fbsplash.sh idle   <outfile>    render the idle frame (text or image)
#   fbsplash.sh paused <outfile>    render the paused frame (falls back to idle
#                                   frame if paused_text is empty)
#   fbsplash.sh test                render idle frame straight to /dev/fb0
#
# Geometry and pixel format are auto-detected from the live framebuffer:
#   - size  from /sys/class/graphics/fb0/virtual_size (the real scanout
#     canvas -- NOT fbset's stale "visible" geometry)
#   - depth from /sys/class/graphics/fb0/bits_per_pixel (16 -> rgb565le,
#     32 -> bgra)
# so the same plugin works unmodified on 1024x768 fallback, forced 1080p,
# and any future 4K canvas.

set -e

KIND="${1:-idle}"
OUT="${2:-/dev/fb0}"
[ "$KIND" = "test" ] && { KIND=idle; OUT=/dev/fb0; }

CONFIG="/home/fpp/media/config/plugin.fpp-splash.json"
PNG="/tmp/fpp-splash-render-$$.png"
trap 'rm -f "$PNG"' EXIT

read -r W H < <(tr ',' ' ' < /sys/class/graphics/fb0/virtual_size)
BPP=$(cat /sys/class/graphics/fb0/bits_per_pixel)
case "$BPP" in
    16) FMT=rgb565le ;;
    32) FMT=bgra ;;
    *)  echo "fpp-splash: unsupported framebuffer depth ${BPP}bpp" >&2; exit 1 ;;
esac

# Read one key from the JSON config with a default.
cfg() {
    python3 - "$1" "$2" << 'PYEOF'
import json, sys
key, default = sys.argv[1], sys.argv[2]
try:
    d = json.load(open("/home/fpp/media/config/plugin.fpp-splash.json"))
except Exception:
    d = {}
v = d.get(key, default)
print(v if v not in (None, "") else default)
PYEOF
}

BG=$(cfg bg black)
FG=$(cfg fg white)
FONT=$(cfg font Nimbus-Sans-Bold-Italic)
PSIZE=$(cfg pointsize 100)

render_text() {
    local text="$1"
    # If the configured font isn't installed, retry with ImageMagick's default
    # rather than failing the whole render.
    convert -size "${W}x${H}" -background "$BG" -fill "$FG" \
            -font "$FONT" -gravity center -pointsize "$PSIZE" \
            label:"$text" "$PNG" 2>/dev/null ||
    convert -size "${W}x${H}" -background "$BG" -fill "$FG" \
            -gravity center -pointsize "$PSIZE" \
            label:"$text" "$PNG"
}

render_image() {
    local img="$1"
    ffmpeg -loglevel error -y -i "$img" \
        -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:${BG}" \
        -frames:v 1 "$PNG"
}

if [ "$KIND" = "paused" ]; then
    PTEXT=$(cfg paused_text "")
    if [ -n "$PTEXT" ]; then
        render_text "$PTEXT"
    else
        KIND=idle   # empty paused_text -> paused shows the idle frame
    fi
fi

if [ "$KIND" = "idle" ]; then
    MODE=$(cfg mode text)
    IMG=$(cfg image "")
    if [ "$MODE" = "image" ] && [ -f "$IMG" ]; then
        render_image "$IMG"
    else
        render_text "$(cfg text Welcome)"
    fi
fi

ffmpeg -loglevel error -y -i "$PNG" -f rawvideo -pix_fmt "$FMT" "$OUT"
