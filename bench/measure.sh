#!/usr/bin/env bash
# Measure the HaLow link both ways. The channel is reciprocal, so a large gap
# between the two RSSIs means a TX-power imbalance, not just a weak link.
# On 2026-07-11 this showed P4-rx -63 dBm vs AP-rx -105 dBm: the P4 radiates
# far below its set power. The 1 m bench hid this; only real distance reveals it.
set -euo pipefail

LOFT_HOST="${LOFT_HOST:-airspy.local}"
LOFT_PORT="${LOFT_PORT:-/dev/ttyUSB0}"
P4_PORT="${P4_PORT:-/dev/ttyACM1}"
P4_IP="${P4_IP:-10.99.0.2}"
CLI="$(dirname "$0")/../cli/thalow_config.py"

echo "== P4 side: association + how well the P4 hears the AP (forward path) =="
python3 "$CLI" "$P4_PORT" status 2>/dev/null | grep -E 'MODE|CONN_STATE|RSSI' | sed 's/^/  /'

echo "== AP side: how well the loft hears the P4 (return path) =="
# Enable the LMAC status dump for one cycle to read per-STA rssi, then silence it.
ssh -n -o BatchMode=yes "$LOFT_HOST" '
  python3 - <<PY 2>/dev/null | grep -iE "STA[0-9]|rx[0-9]|rssi=" | head -4 | sed "s/^/  /"
import importlib.util
s=importlib.util.spec_from_file_location("t","/home/ian/thalow_config.py")
t=importlib.util.module_from_spec(s); s.loader.exec_module(t)
fd=t.open_serial("'"$LOFT_PORT"'"); t.resync(fd)
t.cmd(fd,"AT+SYSDBG=LMAC,1",1.0)
print(t.read_for(fd,18).decode("utf-8","replace").replace(chr(13),chr(10)))
t.cmd(fd,"AT+SYSDBG=LMAC,0",1.0)
PY
'

echo "== end-to-end ping from the loft Pi across the HaLow hop =="
ssh -n -o BatchMode=yes "$LOFT_HOST" "ping -c 20 -i 0.3 -W 2 -q $P4_IP 2>&1 | tail -3" | sed 's/^/  /'
