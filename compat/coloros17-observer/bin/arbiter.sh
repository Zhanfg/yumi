#!/system/bin/sh
# ColorOS 17 observer: no sysfs / procfs / property / mount / COSA writes.
# No camera activity is inferred from listener PIDs.
set -u
MODULES_ROOT=${COLOROS17_MODULES_ROOT:-/data/adb/modules}
CPUREQ_ROOT=${COLOROS17_CPUFREQ_ROOT:-/sys/devices/system/cpu/cpufreq}

is_enabled() {
    [ -d "$MODULES_ROOT/$1" ] && [ ! -f "$MODULES_ROOT/$1/disable" ] && [ ! -f "$MODULES_ROOT/$1/remove" ]
}
proc_exists() { command -v pidof >/dev/null 2>&1 && pidof "$1" >/dev/null 2>&1; }

# Pure decision function, also used by simulated CI tests.
# Args: thermal_known, camera_process, dual_injector, oplus_game_stack (0/1).
select_state() {
    if [ "$1" != 1 ]; then echo THERMAL_UNVERIFIED
    elif [ "$2" = 1 ]; then echo CAMERA_POSSIBLE
    elif [ "$3" = 1 ]; then echo COSA_DUAL_OWNER
    elif [ "$4" = 1 ]; then echo OPLUS_GAME_OWNER
    else echo STOCK_OBSERVE
    fi
}

sample() {
    sc=0; op=0; lucky=0; thermal=0; camera=0; oplus=0; walt=0
    is_enabled scrc && sc=1
    is_enabled cosa_injector && op=1
    is_enabled Lucky_Control && lucky=1
    proc_exists thermal-engine-v2 && thermal=1
    if proc_exists com.oplus.camera || proc_exists com.tlsu.opluscamerapro; then camera=1; fi
    if [ -r "$CPUREQ_ROOT/policy0/scaling_governor" ]; then
        read -r governor < "$CPUREQ_ROOT/policy0/scaling_governor" || governor=unknown
        [ "$governor" = walt ] && walt=1
    fi
    if [ "$walt" -eq 1 ] && { proc_exists vendor.oplus.hardware.gameopt-service || proc_exists com.oplus.cosa; }; then
        oplus=1
    fi
    dual=0
    [ "$sc" -eq 1 ] && [ "$op" -eq 1 ] && dual=1
    state=$(select_state "$thermal" "$camera" "$dual" "$oplus")
    # This is not proof that the camera is open, nor that thermal is down when pidof fails.
    printf 'state=%s\nactuator_enabled=0\nthermal_process_found=%s\ncamera_process_present=%s\ncamera_session_verified=0\nscrc_enabled=%s\nopgce_enabled=%s\ncosa_dual_owner_risk=%s\nlucky_enabled=%s\nwalt_and_gameopt_seen=%s\n' \
        "$state" "$thermal" "$camera" "$sc" "$op" "$dual" "$lucky" "$oplus"
}

watch() {
    MODDIR=$1
    [ -d "$MODDIR" ] || { echo 'Module directory missing' >&2; exit 1; }
    STATE_DIR="$MODDIR/state"
    mkdir -p "$STATE_DIR" || exit 1
    # Single-process lock, cleaned at boot by service.sh; do not remove another live process lock.
    mkdir "$STATE_DIR/watcher.lock" 2>/dev/null || { echo 'Observer already running/lock present' >&2; exit 1; }
    trap 'rmdir "$STATE_DIR/watcher.lock" 2>/dev/null || :' EXIT
    trap 'exit 0' HUP INT TERM
    umask 077
    while :; do
        current=$(sample)
        if [ ! -f "$STATE_DIR/status.txt" ] || [ "$(cat "$STATE_DIR/status.txt" 2>/dev/null)" != "$current" ]; then
            printf '%s\n' "$current" > "$STATE_DIR/status.tmp.$$" && mv "$STATE_DIR/status.tmp.$$" "$STATE_DIR/status.txt"
        fi
        sleep 20
    done
}

case "${1:---once}" in
    --once) sample ;;
    --decide)
        [ "$#" -eq 5 ] || { echo 'Usage: --decide thermal camera dual oplus' >&2; exit 2; }
        select_state "$2" "$3" "$4" "$5" ;;
    --watch)
        [ "$#" -eq 2 ] || { echo 'Usage: --watch /path/to/module' >&2; exit 2; }
        watch "$2" ;;
    *) echo 'Usage: arbiter.sh --once|--decide 0/1 0/1 0/1 0/1|--watch MODDIR' >&2; exit 2 ;;
esac
