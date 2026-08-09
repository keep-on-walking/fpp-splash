#!/bin/bash
# fpp-splash renderer (v1.1)
#
#   fbsplash.sh idle   <outfile>    render the idle frame
#   fbsplash.sh paused <outfile>    render the paused frame
#   fbsplash.sh test                render idle frame straight to /dev/fb0
#
# Config keys (config/plugin.fpp-splash.json):
#   idle_display:   ""              -> centered text (key "text")
#                   /path/to/img    -> that image, letterboxed fullscreen
#   paused_display: ""              -> centered text (key "paused_text")
#                   "idle"          -> reuse the idle frame
#                   /path/to/img    -> that image, letterboxed fullscreen
#   text, paused_text, pointsize, fg, bg, font
#
# v1.0 keys (mode/image) are still honoured if the new keys are absent.
#
# Geometry/depth auto-detected from /sys/class/graphics/fb0 (virtual_size,
# bits_per_pixel) -- works on any canvas without configuration. If an image
# fails to render, falls back to the text frame so the screen is never
# stale or blank.

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

cfg() {
    python3 - "$1" "$2" << 'PYEOF'
import json, sys
key, default = sys.argv[1], sys.argv[2]
try:
    d = json.load(open("/home/fpp/media/config/plugin.fpp-splash.json"))
except Exception:
    d = {}
v = d.get(key, None)
print(v if v not in (None, "") else default)
PYEOF
}

BG=$(cfg bg black)
FG=$(cfg fg white)
FONT=$(cfg font Nimbus-Sans-Bold-Italic)
PSIZE=$(cfg pointsize 100)

render_text() {
    local text="$1"
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

# Resolve what to display for this state, with v1.0 key fallback.
if [ "$KIND" = "paused" ]; then
    DISPLAY_SEL=$(cfg paused_display "__text__")
    if [ "$DISPLAY_SEL" = "idle" ]; then
        KIND=idle
    elif [ "$DISPLAY_SEL" != "__text__" ] && [ -f "$DISPLAY_SEL" ]; then
        render_image "$DISPLAY_SEL" || { echo "fpp-splash: paused image failed, using text" >&2; render_text "$(cfg paused_text PAUSED)"; }
    else
        render_text "$(cfg paused_text PAUSED)"
    fi
fi

if [ "$KIND" = "idle" ]; then
    DISPLAY_SEL=$(cfg idle_display "__text__")
    if [ "$DISPLAY_SEL" = "__text__" ]; then
        # v1.0 compatibility: honour old mode/image keys if present
        if [ "$(cfg mode text)" = "image" ] && [ -f "$(cfg image /nonexistent)" ]; then
            DISPLAY_SEL=$(cfg image "")
        fi
    fi
    if [ "$DISPLAY_SEL" != "__text__" ] && [ -f "$DISPLAY_SEL" ]; then
        render_image "$DISPLAY_SEL" || { echo "fpp-splash: idle image failed, using text" >&2; render_text "$(cfg text Welcome)"; }
    else
        render_text "$(cfg text Welcome)"
    fi
fi

ffmpeg -loglevel error -y -i "$PNG" -f rawvideo -pix_fmt "$FMT" "$OUT"
