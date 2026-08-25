#!/bin/bash
# jam.sh — start/stop a jam session: a stompbox session (Carla, Hydrogen,
# SooperLooper, patchbay) plus the JamCapture web server.
#
#   ./jam.sh start [session]     default session: bossa
#   ./jam.sh stop  [session]
#   ./jam.sh restart [session]
#   ./jam.sh status [session]
#   ./jam.sh logs                follow the JamCapture logs
#
# stomp reads its manifest from ~/.config/stompbox/stompbox.yaml (a symlink
# created by `stomp apply`), so this script works from any directory.
# JamCapture reads ~/.config/jamcapture.yaml and runs as a transient systemd
# user unit, like the stompbox apps.

set -euo pipefail

SESSION="${JAM_SESSION:-bossa}"
JAM_UNIT="${JAM_UNIT:-jamcapture}"
JAM_VERBOSE="${JAM_VERBOSE:-3}"

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
            "$jamcapture_bin" serve -v"$JAM_VERBOSE" >/dev/null
    fi

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
[ $# -gt 0 ] && SESSION="$1"

case "$cmd" in
    start)   start ;;
    stop)    stop ;;
    restart) stop; start ;;
    status)  status ;;
    logs)    logs ;;
    ""|-h|--help|help)
        sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    *) die "unknown command '$cmd' (start|stop|restart|status|logs)" ;;
esac
