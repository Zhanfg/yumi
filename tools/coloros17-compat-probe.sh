#!/system/bin/sh
# ColorOS 17 coexistence probe: READ-ONLY. Does not modify modules, processes, properties, databases or mounts.
set -u
OUT="${1:-/sdcard/Download/ColorOS17_Compat_$(date '+%Y%m%d_%H%M%S').txt}"
TMP="${OUT}.tmp.$$"
( umask 077; : > "$TMP" ) || { echo "Cannot write report: $TMP"; exit 1; }
exec 3>"$TMP"
log() { printf '%s\n' "$*" >&3; }
section() { log ""; log "=== $* ==="; }
prop() { log "$1=$(getprop "$1" 2>/dev/null)"; }
log 'ColorOS17/OnePlus13 compatibility probe (read-only)'
log "date=$(date) uid=$(id -u) kernel=$(uname -r)"
section 'Device'
for p in ro.product.model ro.product.device ro.soc.model ro.build.version.sdk ro.build.version.release; do prop "$p"; done
section 'Module states (absence does not prove no competing writer)'
for name in scrc cosa_injector Lucky_Control zygisknextsu zygisksu brene nomount iossoundeffects ViPER4Android-RE-AIDL; do
  d="/data/adb/modules/$name"
  if [ -d "$d" ]; then
    if [ -f "$d/disable" ]; then state=disabled; else state=enabled_marker_absent; fi
    log "$name: $state"
    [ -f "$d/module.prop" ] && sed -n '/^version=/p' "$d/module.prop" >&3
  else log "$name: not_found"; fi
done
section 'COSA concurrency (never change or delete this database in probe)'
if [ -d /data/adb/modules/scrc ] && [ ! -e /data/adb/modules/scrc/disable ] && [ -d /data/adb/modules/cosa_injector ] && [ ! -e /data/adb/modules/cosa_injector/disable ]; then
  log 'RISK: SCRC and OPGCE both enabled; both contain COSA injection logic'
else log 'Both COSA injectors enabled simultaneously: not observed'; fi
for path in /data/data/com.oplus.cosa/databases/db_game_database /data/user_de/0/com.oplus.cosa/databases/db_game_database; do
  [ -f "$path" ] && log "COSA database present at $path (not read)"
done
section 'Display global properties (read only)'
prop vendor.display.disable_system_load_check
prop vendor.display.enable_perf_hint_large_comp_cycle
section 'OPlus services (read only)'
for svc in oiface horae gameopt_hal_service-1-0 vendor.urcc-hal-aidl thermal-engine-v2; do prop "init.svc.$svc"; done
section 'Governors / freq ceilings (read only)'
for f in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor /sys/devices/system/cpu/cpufreq/policy*/scaling_max_freq; do
 [ -f "$f" ] && log "$f: $(cat "$f" 2>/dev/null)"
done
for f in /sys/module/cpufreq_bouncing/parameters/enable /proc/game_opt/task_boost/critical_task_name; do
 if [ -r "$f" ]; then log "present: $f"; else log "not readable: $f"; fi
done
section 'Camera package and active client indications'
for p in com.oplus.camera com.tlsu.opluscamerapro; do
 if command -v pidof >/dev/null 2>&1; then log "pidof $p: $(pidof "$p" 2>/dev/null)"; fi
done
# Active cameras can be clients of other apps; foreground package check alone is insufficient.
if command -v dumpsys >/dev/null 2>&1; then
 dumpsys media.camera 2>/dev/null | grep -i -E 'active client|client package|camera id|device status|open camera' | head -n 30 >&3
fi
section 'Competing process indicators'
ps -A 2>/dev/null | grep -i -E 'yumi|scrc|opgs_daemon|inject_core|cosa|hmbird|gameopt|thermal-engine' | head -n 35 >&3
section 'Potential system-file mounts (counts only; no remount)'
if [ -r /proc/self/mountinfo ]; then
 for p in '/odm/etc/' '/system_ext/etc/' '/vendor/etc/' '/vendor/lib64/' ; do
  n=$(grep -F -c "$p" /proc/self/mountinfo 2>/dev/null)
  log "$p : $n entries matching pathname in root namespace"
 done
fi
section 'END - read only'
exec 3>&-
mv "$TMP" "$OUT" || { echo "Failed to save $OUT; raw output at $TMP"; exit 1; }
echo "Report: $OUT"
