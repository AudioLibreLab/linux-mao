#!/bin/bash
# jam.sh — start/stop a jam session: a stompbox session (Carla, Hydrogen,
# SooperLooper, patchbay) plus the JamCapture web server.
#
#   ./jam.sh start [session]     default session: bossa
#   ./jam.sh stop  [session]
#   ./jam.sh restart [session]
#   ./jam.sh status [session]
#   ./jam.sh logs                follow the JamCapture logs
#   ./jam.sh board [url]         open the split YouTube / JamCapture board
#
# `start` also opens the board in Chrome; set JAM_BOARD=0 to skip it.
# A YouTube URL (or video id) given as the last argument — or in $JAM_YT —
# is loaded in the board's left pane:
#
#   ./jam.sh start bossa 'https://www.youtube.com/watch?v=…'
#   ./jam.sh board 'https://youtu.be/…'
#
# stomp reads its manifest from ~/.config/stompbox/stompbox.yaml (a symlink
# created by `stomp apply`), so this script works from any directory.
# JamCapture reads ~/.config/jamcapture.yaml and runs as a transient systemd
# user unit, like the stompbox apps.

set -euo pipefail

SESSION="${JAM_SESSION:-bossa}"
JAM_UNIT="${JAM_UNIT:-jamcapture}"
JAM_VERBOSE="${JAM_VERBOSE:-3}"
JAM_PORT="${JAM_PORT:-8080}"
JAM_BOARD="${JAM_BOARD:-1}"          # 0 to keep the browser out of `start`
JAM_BROWSER="${JAM_BROWSER:-google-chrome}"
JAM_YT="${JAM_YT:-}"                 # YouTube URL (or id) to load in the board
BOARD_HTML="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/jamboard.html"

die() { echo "jam: $*" >&2; exit 1; }

require() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' not found in PATH"
}

# JamCapture's UI needs the graphical session (system tray); systemd user
# units only see what has been imported into the user manager.
import_graphical_env() {
    systemctl --user import-environment \
        DISPLAY WAYLAND_DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP \
        XDG_SESSION_TYPE DBUS_SESSION_BUS_ADDRESS 2>/dev/null || true
}

jam_active() {
    systemctl --user is-active --quiet "$JAM_UNIT.service"
}

# Percent-encode a string for use in a query parameter (YouTube URLs carry
# ? and & of their own). Pure bash: no python/jq needed.
urlencode() {
    local s="$1" out="" c i
    for (( i = 0; i < ${#s}; i++ )); do
        c="${s:i:1}"
        case "$c" in
            [a-zA-Z0-9.~_-]) out+="$c" ;;
            *) printf -v c '%%%02X' "'$c"; out+="$c" ;;
        esac
    done
    printf '%s' "$out"
}

# GNOME under Wayland ignores --window-position (mutter places windows
# itself), so a scripted two-window split is not possible. The board is a
# local page splitting one Chrome window between the YouTube player and the
# JamCapture UI instead; drag the divider to resize.
board() {
    [ -f "$BOARD_HTML" ] || die "board page not found: $BOARD_HTML"
    command -v "$JAM_BROWSER" >/dev/null 2>&1 || {
        echo "jam: '$JAM_BROWSER' not found, skipping the board" >&2
        return 0
    }
    local url="file://$BOARD_HTML?jam=http://localhost:$JAM_PORT"
    [ -n "$JAM_YT" ] && url="$url&yt=$(urlencode "$JAM_YT")"
    echo "jam: opening the board…"
    # --app drops the tab strip and address bar; the window is ours alone.
    "$JAM_BROWSER" --app="$url" --start-maximized >/dev/null 2>&1 &
    disown
}

start() {
    require stomp
    require jamcapture
    local jamcapture_bin
    jamcapture_bin="$(command -v jamcapture)"

    import_graphical_env

    echo "jam: starting stompbox session '$SESSION'…"
    stomp on "$SESSION"

    if jam_active; then
        echo "jam: JamCapture already running ($JAM_UNIT.service)"
    else
        echo "jam: starting JamCapture (-v$JAM_VERBOSE)…"
        # --collect drops the transient unit once it exits, so a later
        # start does not trip over a failed leftover.
        systemd-run --user --collect \
            --unit="$JAM_UNIT" \
            --description="JamCapture web server" \
            --working-directory="$HOME" \
            "$jamcapture_bin" serve -v"$JAM_VERBOSE" --port "$JAM_PORT" >/dev/null
    fi

    [ "$JAM_BOARD" = "1" ] && board

    status
}

stop() {
    require stomp

    if jam_active; then
        echo "jam: stopping JamCapture…"
        systemctl --user stop "$JAM_UNIT.service"
    fi

    echo "jam: stopping stompbox session '$SESSION'…"
    stomp off "$SESSION"
}

status() {
    echo
    # Keep only the requested session's block (target line + its instances).
    stomp status | awk -v s="$SESSION.target" '$1 == s {p=1; print; next} /^[^ ]/ {p=0} p' || true
    echo
    printf '%-28s %s\n' "$JAM_UNIT.service" \
        "$(systemctl --user is-active "$JAM_UNIT.service" 2>/dev/null || true)"
    if jam_active; then
        # JamCapture logs its LAN URL at startup — the one to open on a phone.
        journalctl --user -u "$JAM_UNIT.service" --since "-1day" --no-pager 2>/dev/null \
            | grep -oE 'local_url=https?://[^ ]+' | tail -1 \
            | sed 's/^local_url=/  UI: /' || true
    fi
}

logs() {
    journalctl --user -u "$JAM_UNIT.service" -f --no-pager
}

cmd="${1:-}"
[ $# -gt 0 ] && shift || true

case "$cmd" in
    board)
        # board takes the YouTube URL directly: jam board <url>
        [ $# -gt 0 ] && JAM_YT="$1"
        ;;
    *)
        # everything else: jam <cmd> [session] [youtube-url]
        [ $# -gt 0 ] && SESSION="$1"
        [ $# -gt 1 ] && JAM_YT="$2"
        ;;
esac

case "$cmd" in
    start)   start ;;
    stop)    stop ;;
    restart) stop; start ;;
    status)  status ;;
    logs)    logs ;;
    board)   board ;;
    ""|-h|--help|help)
        sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    *) die "unknown command '$cmd' (start|stop|restart|status|logs|board)" ;;
esac
