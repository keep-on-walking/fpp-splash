# fpp-splash

Idle / paused splash screen for FPP v10 HDMI video output.

Shows a configurable splash on the display whenever no media is playing:
centered text or a fullscreen (letterboxed) image when idle, and an
optional "PAUSED" frame while a playlist is paused.

## How it works

A small daemon (systemd service `fpp-splash`) polls `fppd` status once a
second and writes pre-rendered raw frames directly to `/dev/fb0`. The
framebuffer sits *beneath* FPP's GStreamer/KMS video plane, so:

- there is never any conflict with video playback (no DRM ownership issues)
- the splash is pre-drawn behind the video while it plays, so it appears
  the instant playback stops - zero gap
- framebuffer geometry (size and pixel depth) is auto-detected from
  `/sys/class/graphics/fb0/`, so it works at 1024x768 fallback, forced
  1080p, or any other canvas without configuration

## Install

Install from FPP UI: Plugin Manager -> add this repo URL, or clone into
`/home/fpp/media/plugins/` and run `scripts/fpp_install.sh`.

## Configure

Content Setup -> Idle Splash. Settings take effect within ~2 seconds of
saving, no restart needed. Upload images via File Manager -> Images.
