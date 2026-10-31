#!/system/bin/sh
# Dedicated read-only observer service, no attempt to start yumi scheduler.
MODDIR=${0%/*}
[ "$MODDIR" = "$0" ] && exit 1
until [ "$(getprop sys.boot_completed 2>/dev/null)" = 1 ]; do sleep 2; done
[ -f "$MODDIR/disable" ] && exit 0
[ "$(getprop ro.product.device 2>/dev/null)" = "OP5D0DL1" ] || exit 0
mkdir -p "$MODDIR/state" || exit 1
# Clear previous-boot lock; service is invoked once by the root module manager.
rmdir "$MODDIR/state/watcher.lock" 2>/dev/null || :
sh "$MODDIR/bin/arbiter.sh" --watch "$MODDIR" >/dev/null 2>&1 &
