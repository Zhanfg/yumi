#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
S="$ROOT/bin/arbiter.sh"
sh -n "$S"; sh -n "$ROOT/service.sh"; sh -n "$ROOT/customize.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/modules/scrc" "$TMP/modules/cosa_injector" "$TMP/modules/Lucky_Control" "$TMP/cpufreq/policy0" "$TMP/bin"
printf 'walt\n' > "$TMP/cpufreq/policy0/scaling_governor"
cat > "$TMP/bin/pidof" <<'MOCK'
#!/bin/sh
case "$1" in
    thermal-engine-v2|com.oplus.cosa|vendor.oplus.hardware.gameopt-service) exit 0;;
    com.oplus.camera) [ "${TEST_CAMERA:-0}" = 1 ] && exit 0 || exit 1;;
    *) exit 1;;
esac
MOCK
chmod +x "$TMP/bin/pidof"
export COLOROS17_MODULES_ROOT="$TMP/modules"
export COLOROS17_CPUFREQ_ROOT="$TMP/cpufreq"
PATH="$TMP/bin:$PATH"; export PATH
out=$(sh "$S" --once)
printf '%s\n' "$out" | grep -qx 'state=COSA_DUAL_OWNER'
printf '%s\n' "$out" | grep -qx 'cosa_dual_owner_risk=1'
printf '%s\n' "$out" | grep -qx 'actuator_enabled=0'
[ "$(sh "$S" --decide 0 1 1 1)" = THERMAL_UNVERIFIED ]
[ "$(sh "$S" --decide 1 1 1 1)" = CAMERA_POSSIBLE ]
[ "$(sh "$S" --decide 1 0 1 1)" = COSA_DUAL_OWNER ]
[ "$(sh "$S" --decide 1 0 0 1)" = OPLUS_GAME_OWNER ]
[ "$(sh "$S" --decide 1 0 0 0)" = STOCK_OBSERVE ]
TEST_CAMERA=1; export TEST_CAMERA
out=$(sh "$S" --once)
printf '%s\n' "$out" | grep -qx 'state=CAMERA_POSSIBLE'
printf '%s\n' "$out" | grep -qx 'camera_session_verified=0'
: > "$TMP/modules/cosa_injector/disable"
TEST_CAMERA=0; export TEST_CAMERA
out=$(sh "$S" --once)
printf '%s\n' "$out" | grep -qx 'state=OPLUS_GAME_OWNER'
printf '%s\n' "$out" | grep -qx 'opgce_enabled=0'
# Prevent accidental introduction of system write tools in this observer's executable scripts.
if grep -v '^[[:space:]]*#' "$S" "$ROOT/service.sh" | grep -nE '(^|[;[:space:]])(setprop|resetprop|mount|umount|chcon|chmod|chown|killall|pm clear|pm disable)([[:space:]]|$)'; then
   echo 'Unexpected system mutation command in observer' >&2; exit 1
fi
printf 'PASS: read-only arbitration and synthetic camera/COSA priority tests\n'
