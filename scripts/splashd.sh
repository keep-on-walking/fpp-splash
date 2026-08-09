#!/bin/bash
# fpp-splash daemon
#
# Polls fppd status once a second and keeps the framebuffer showing the
# right frame:
#
#   idle / stopped / fppd down  ->  idle splash (text or image)
#   paused                      ->  paused frame (or idle frame if unset)
#   playing                     ->  nothing drawn; the idle frame is
#                                   pre-drawn BENEATH the video plane, so
#                                   the moment playback stops it is already
#                                   on screen with zero latency
#
# Frames are pre-rendered to raw files on startup and whenever the config
# file changes, so a state transition is a single cat -- milliseconds.

PLUGDIR="$(cd "$(dirname "$0")/.." && pwd)"
RENDER="$PLUGDIR/scripts/fbsplash.sh"
CONFIG="/home/fpp/media/config/plugin.fpp-splash.json"
FB=/dev/fb0
IDLE_RAW=/tmp/fpp-splash-idle.raw
PAUSED_RAW=/tmp/fpp-splash-paused.raw

state=""
cfg_mtime=""

get_status() {
    curl -s -m 2 http://localhost/api/fppd/status 2>/dev/null | python3 -c '
import sys, json
try:
    print(json.load(sys.stdin).get("status_name", "unknown"))
except Exception:
    print("unknown")
' 2>/dev/null
}

render_frames() {
    "$RENDER" idle   "$IDLE_RAW"   || echo "fpp-splash: idle render failed"   >&2
    "$RENDER" paused "$PAUSED_RAW" || echo "fpp-splash: paused render failed" >&2
}

show() { [ -s "$1" ] && cat "$1" > "$FB" 2>/dev/null; }

# Wait for the framebuffer device (early boot) then render both frames.
while [ ! -e "$FB" ]; do sleep 1; done
render_frames

while true; do
    # Re-render on any config change (dashboard save). Forces a redraw.
    m=$(stat -c %Y "$CONFIG" 2>/dev/null)
    if [ "$m" != "$cfg_mtime" ]; then
        cfg_mtime="$m"
        render_frames
        state=""
    fi

    case "$(get_status)" in
        playing) new="playing" ;;
        paused)  new="paused"  ;;
        *)       new="idle"    ;;   # idle, stopped, unknown, fppd restarting
    esac

    if [ "$new" != "$state" ]; then
        case "$new" in
            idle)    show "$IDLE_RAW" ;;
            paused)  show "$PAUSED_RAW" ;;
            playing) show "$IDLE_RAW" ;;   # hidden under video; pre-arms the
                                           # instant reveal at end of playback
        esac
        state="$new"
    fi
    sleep 1
done
