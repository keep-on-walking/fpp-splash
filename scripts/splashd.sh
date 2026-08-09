#!/bin/bash
# fpp-splash daemon (v1.3)
#
#   idle     -> configured idle display (text/image frame, or start a
#               screensaver playlist), optionally only after idle_delay
#               seconds of continuous idle
#   paused   -> configured paused frame
#   playing  -> nothing visible; a frame is pre-drawn BENEATH the video
#               plane for an instant reveal when playback stops:
#                 idle_delay = 0  -> idle frame is pre-drawn
#                 idle_delay > 0  -> PAUSED frame is pre-drawn, so pausing
#                    reveals the paused display with ZERO flip; a stop
#                    shows the same frame for idle_delay seconds, then the
#                    idle display (frame or playlist) takes over
#
# The delay only applies when idle follows playback (playing/paused).
# On boot, or after fppd restarts, the idle display activates immediately.
# Screensaver mode stays self-healing: playlist started with repeat,
# restarted if it ends (throttled to one attempt per 5s), never started
# while fppd is unreachable.

PLUGDIR="$(cd "$(dirname "$0")/.." && pwd)"
RENDER="$PLUGDIR/scripts/fbsplash.sh"
CONFIG="/home/fpp/media/config/plugin.fpp-splash.json"
FB=/dev/fb0
IDLE_RAW=/tmp/fpp-splash-idle.raw
PAUSED_RAW=/tmp/fpp-splash-paused.raw

state=""
cfg_mtime=""
idle_playlist=""
idle_delay=0
idle_at=0
idle_active=0
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

read_config_extras() {
    local out
    out=$(python3 - << 'PYEOF'
import json
try:
    d = json.load(open("/home/fpp/media/config/plugin.fpp-splash.json"))
except Exception:
    d = {}
v = d.get("idle_display", "")
pl = v[len("playlist:"):] if isinstance(v, str) and v.startswith("playlist:") else ""
try:
    delay = max(0, int(float(d.get("idle_delay", 0) or 0)))
except Exception:
    delay = 0
print(pl)
print(delay)
PYEOF
)
    idle_playlist=$(echo "$out" | sed -n 1p)
    idle_delay=$(echo "$out" | sed -n 2p)
    [ -n "$idle_delay" ] || idle_delay=0
}

render_frames() {
    "$RENDER" idle   "$IDLE_RAW"   || echo "fpp-splash: idle render failed"   >&2
    "$RENDER" paused "$PAUSED_RAW" || echo "fpp-splash: paused render failed" >&2
}

show() { [ -s "$1" ] && cat "$1" > "$FB" 2>/dev/null; }

underlay() {
    # frame pre-drawn beneath the video plane while playing
    if [ "$idle_delay" -gt 0 ]; then show "$PAUSED_RAW"; else show "$IDLE_RAW"; fi
}

activate_idle() {
    if [ -n "$idle_playlist" ]; then
        [ "$idle_active" = 0 ] && show "$IDLE_RAW"   # gap frame while playlist starts
        local now; now=$(date +%s)
        if [ $((now - last_start)) -ge 5 ]; then
            last_start=$now
            curl -s -m 3 -X POST http://localhost/api/command \
                -H "Content-Type: application/json" \
                -d "{\"command\":\"Start Playlist\",\"args\":[\"${idle_playlist}\",true]}" > /dev/null 2>&1
        fi
    else
        [ "$idle_active" = 0 ] && show "$IDLE_RAW"
    fi
    idle_active=1
}

while [ ! -e "$FB" ]; do sleep 1; done
render_frames
read_config_extras

while true; do
    m=$(stat -c %Y "$CONFIG" 2>/dev/null)
    if [ "$m" != "$cfg_mtime" ]; then
        cfg_mtime="$m"
        render_frames
        read_config_extras
        state=""
        idle_active=0
    fi

    case "$(get_status)" in
        playing|"stopping gracefully"*) new="playing" ;;
        paused)                         new="paused"  ;;
        unknown)                        new="unknown" ;;
        *)                              new="idle"    ;;
    esac

    now=$(date +%s)

    if [ "$new" = "idle" ]; then
        if [ "$state" != "idle" ]; then
            idle_active=0
            if [ "$idle_delay" -gt 0 ] && { [ "$state" = "playing" ] || [ "$state" = "paused" ]; }; then
                idle_at=$((now + idle_delay))   # hold current frame, activate later
            else
                idle_at=$now                    # boot / fppd restart: no delay
            fi
        fi
        [ "$now" -ge "$idle_at" ] && activate_idle
    elif [ "$new" != "$state" ]; then
        idle_active=0
        case "$new" in
            paused)  show "$PAUSED_RAW" ;;
            playing) underlay ;;
            unknown) : ;;    # fppd down: leave whatever is showing alone
        esac
    fi
    state="$new"
    sleep 0.3
done
