#!/bin/bash
# jam.sh — start/stop a jam session: a stompbox session (Carla, Hydrogen,
# SooperLooper, patchbay) plus the JamCapture web server.
#
#   ./jam.sh start [session] [youtube-url]   default session: bossa
#   ./jam.sh stop  [session]
#   ./jam.sh restart [session] [youtube-url]
#   ./jam.sh status [session]
#   ./jam.sh logs                     follow the JamCapture logs
#   ./jam.sh browser [youtube-url]    open the two tabs only
#
# `start` also opens YouTube and JamCapture as two Chrome tabs; put them
# side by side with Shift+Alt+N — Chrome's own split view — or by
# right-clicking a tab. JAM_OPEN=0 leaves the browser alone.
#
#   ./jam.sh start bossa 'https://www.youtube.com/watch?v=…'
#   ./jam.sh browser dQw4w9WgXcQ
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
JAM_OPEN="${JAM_OPEN:-1}"            # 0 to keep the browser out of `start`
JAM_BROWSER="${JAM_BROWSER:-google-chrome}"
JAM_YT="${JAM_YT:-}"                 # YouTube URL (or video id) to open

die() { echo "jam: $*" >&2; exit 1; }

require() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' not found in PATH"
}

usage() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
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

# Turn a bare video id into a watch URL; anything else is passed through.
youtube_url() {
    case "$1" in
        http://*|https://*) printf '%s' "$1" ;;
        *) printf 'https://www.youtube.com/watch?v=%s' "$1" ;;
    esac
}

# Two ordinary tabs in one window. Chrome splits them itself (Shift+Alt+N);
# nothing here can trigger that split — there is no command-line switch for
# it, and Wayland rules out sending the shortcut.
browser() {
    command -v "$JAM_BROWSER" >/dev/null 2>&1 || {
        echo "jam: '$JAM_BROWSER' not found, not opening the browser" >&2
        return 0
    }
    local yt="https://www.youtube.com/"
    [ -n "$JAM_YT" ] && yt="$(youtube_url "$JAM_YT")"

    echo "jam: opening YouTube and JamCapture…"
    echo "     Shift+Alt+N (or right-click a tab → split view) to put them side by side"
    "$JAM_BROWSER" --new-window "$yt" "http://localhost:$JAM_PORT" >/dev/null 2>&1 &
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
        systemd-run --user --collect --quiet \
            --unit="$JAM_UNIT" \
            --description="JamCapture web server" \
            --working-directory="$HOME" \
            "$jamcapture_bin" serve -v"$JAM_VERBOSE" --port "$JAM_PORT" >/dev/null
    fi

    [ "$JAM_OPEN" = "1" ] && browser

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
    browser)
        # browser takes the YouTube URL directly: jam browser <url>
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
    browser) browser ;;
    ""|-h|--help|help) usage ;;
    *) die "unknown command '$cmd' (start|stop|restart|status|logs|browser)" ;;
esac
