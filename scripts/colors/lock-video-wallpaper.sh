#!/usr/bin/env bash
# Plays the lock screen's own video wallpaper while the screen is locked, then puts the
# home wallpaper back. Called by services/Wallpapers.qml on lock/unlock.
# Usage: lock-video-wallpaper.sh start <video> | stop

# Same playback options as switchwall.sh
VIDEO_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 video-scale-x=1.0 video-scale-y=1.0 video-align-x=0.5 video-align-y=0.5 load-scripts=no"
# switchwall.sh keeps this up to date: it starts the home video wallpaper, or does
# nothing when the home wallpaper is a still image
RESTORE_SCRIPT="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/custom/scripts/__restore_video_wallpaper.sh"

# -x: match the process name exactly. switchwall.sh's `pkill -f mpvpaper` would also
# kill anything that merely mentions mpvpaper in its command line.
stop_video() {
    pkill -x mpvpaper
}

case "$1" in
    start)
        [ -f "$2" ] || { echo "Video not found: $2"; exit 1; }
        stop_video
        for monitor in $(hyprctl monitors -j | jq -r '.[].name'); do
            mpvpaper -o "$VIDEO_OPTS" "$monitor" "$2" &
            sleep 0.1
        done
        ;;
    stop)
        stop_video
        [ -x "$RESTORE_SCRIPT" ] && "$RESTORE_SCRIPT"
        ;;
    *)
        echo "Usage: $0 start <video> | stop"
        exit 1
        ;;
esac
