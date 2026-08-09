#!/bin/bash
# fpp-splash daemon (v1.2)
#
# Keeps the display showing the right thing based on fppd status:
#
#   idle     -> configured idle display: text frame, image frame, or
#               starting a chosen playlist (screensaver mode)
#   paused   -> configured paused frame (text/image/same-as-idle)
#   playing  -> nothing visible; the idle frame is pre-drawn BENEATH the
#               video plane so the moment playback stops it is already on
#               screen, and the paused/screensaver handover happens within
#               one poll tick (0.3s)
#
# Screensaver mode is self-healing: the playlist is started with repeat,
# but even if it ends or is stopped, the daemon sees "idle" and starts it
# again (throttled to one attempt per 5s). It is never started while fppd
# is unreachable, so fppd restarts don't trigger spurious playback.

PLUGDIR="$(cd "$(dirname "$0")/.." && pwd)"
RENDER="$PLUGDIR/scripts/fbsplash.sh"
CONFIG="/home/fpp/media/config/plugin.fpp-splash.json"
FB=/dev/fb0
IDLE_RAW=/tmp/fpp-splash-idle.raw
PAUSED_RAW=/tmp/fpp-splash-paused.raw

state=""
cfg_mtime=""
idle_playlist=""
last_start=0

get_status() {
    curl -s -m 2 http://localhost/api/fppd/status 2>/dev/null | python3 -c '
import sys, json
try:
    print(json.load(sys.stdin).get("status_name", "unknown"))
except Exception:
    print("unknown")
' 2>/dev/null
}

read_idle_playlist() {
    python3 - << 'PYEOF'
import json
try:
    d = json.load(open("/home/fpp/media/config/plugin.fpp-splash.json"))
except Exception:
    d = {}
v = d.get("idle_display", "")
print(v[len("playlist:"):] if isinstance(v, str) and v.startswith("playlist:") else "")
PYEOF
}

render_frames() {
    "$RENDER" idle   "$IDLE_RAW"   || echo "fpp-splash: idle render failed"   >&2
    "$RENDER" paused "$PAUSED_RAW" || echo "fpp-splash: paused render failed" >&2
}

show() { [ -s "$1" ] && cat "$1" > "$FB" 2>/dev/null; }

start_screensaver() {
    local now; now=$(date +%s)
    [ $((now - last_start)) -lt 5 ] && return
    last_start=$now
    curl -s -m 3 -X POST http://localhost/api/command \
        -H "Content-Type: application/json" \
        -d "{\"command\":\"Start Playlist\",\"args\":[\"${idle_playlist}\",true]}" > /dev/null 2>&1
}

while [ ! -e "$FB" ]; do sleep 1; done
render_frames
idle_playlist=$(read_idle_playlist)

while true; do
    m=$(stat -c %Y "$CONFIG" 2>/dev/null)
    if [ "$m" != "$cfg_mtime" ]; then
        cfg_mtime="$m"
        render_frames
        idle_playlist=$(read_idle_playlist)
        state=""
    fi

    case "$(get_status)" in
        playing|"stopping gracefully"*) new="playing" ;;
        paused)                         new="paused"  ;;
        unknown)                        new="unknown" ;;   # fppd down/restarting
        *)                              new="idle"    ;;
    esac

    if [ "$new" = "idle" ] && [ -n "$idle_playlist" ]; then
        # screensaver mode: gap frame is already on screen (pre-drawn),
        # (re)start the playlist -- throttled, and retried automatically
        # if it ends or fails to start
        [ "$state" != "idle" ] && show "$IDLE_RAW"
        start_screensaver
    elif [ "$new" != "$state" ]; then
        case "$new" in
            idle|unknown) show "$IDLE_RAW" ;;
            paused)       show "$PAUSED_RAW" ;;
            playing)      show "$IDLE_RAW" ;;   # pre-arm the reveal
        esac
    fi
    state="$new"
    sleep 0.3
done
