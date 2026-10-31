#!/bin/sh
# Regression check: safe-start gate must execute before normal yumi service work.
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SERVICE="$ROOT/module/service.sh"
[ -f "$SERVICE" ] || { echo "Missing service.sh" >&2; exit 1; }
sh -n "$SERVICE"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/bin" "$TMP/mod"
cp "$SERVICE" "$TMP/mod/service.sh"
cat > "$TMP/bin/getprop" <<'MOCK'
#!/bin/sh
case "$1" in
  ro.product.model) echo PJZ110;;
  ro.product.device) echo OP5D0DL1;;
  ro.soc.model) echo SM8750;;
  *) exit 1;;
esac
MOCK
cat > "$TMP/bin/killall" <<'MOCK'
#!/bin/sh
echo 'FAIL: killall called on OnePlus 13 safety path' >&2
exit 90
MOCK
chmod 755 "$TMP/bin/getprop" "$TMP/bin/killall"
PATH="$TMP/bin:$PATH" sh "$TMP/mod/service.sh"
grep -Fq 'scheduler startup blocked' "$TMP/mod/logs/service.log"
echo 'PASS: OnePlus 13 safety gate exits before scheduler/killall.'
