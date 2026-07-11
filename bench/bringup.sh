#!/usr/bin/env bash
# Bring the HaLow link from cold to the tested state:
#   loft board = AP, P4 = STA, loft Pi eth1 = static IP bridged onto the BSS.
#
# Idempotent — safe to re-run. Run from the workstation; it drives the loft Pi
# over SSH and the P4 over local serial. Nothing here survives a power cycle
# (the board reverts to STA) or a Pi reboot (eth1 is unmanaged/static), which
# is exactly why this script exists.
#
# Prereqs: ssh alias `airspy.local` reachable; thalow_config.py present on the
# loft Pi at ~/thalow_config.py and locally at ../cli/thalow_config.py.
set -euo pipefail

# --- knobs (override via env) ----------------------------------------------
LOFT_HOST="${LOFT_HOST:-airspy.local}"
LOFT_PORT="${LOFT_PORT:-/dev/ttyUSB0}"     # loft board AT console on the Pi
LOFT_ETH="${LOFT_ETH:-eth1}"               # ASIX USB dongle (onboard eth0 jack is dead)
P4_PORT="${P4_PORT:-/dev/ttyACM1}"         # P4 AT console on the workstation
SSID="${SSID:-halowbench}"
FREQ="${FREQ:-8660}"                        # 866.0 MHz (UK/EU 863-868 band)
BW="${BW:-2}"                               # MHz
TXP="${TXP:-14}"                            # dBm (EU 863-868 ERP limit)
LOFT_IP="${LOFT_IP:-10.99.0.1/24}"
CLI="$(dirname "$0")/../cli/thalow_config.py"

echo "== loft board ($LOFT_HOST:$LOFT_PORT) -> AP $SSID $FREQ/$BW MHz ${TXP}dBm =="
ssh -n -o BatchMode=yes "$LOFT_HOST" \
  "python3 ~/thalow_config.py $LOFT_PORT ap --ssid $SSID --freq $FREQ --bw $BW --open --txpower $TXP" \
  | sed 's/^/  /'

echo "== loft $LOFT_ETH -> $LOFT_IP (unmanaged; NM would otherwise flush it) =="
ssh -n -o BatchMode=yes "$LOFT_HOST" "
  sudo -n nmcli device set $LOFT_ETH managed no
  sudo -n ip addr flush dev $LOFT_ETH
  sudo -n ip addr add $LOFT_IP dev $LOFT_ETH
  sudo -n ip link set $LOFT_ETH up
  ip -br addr show $LOFT_ETH
  echo default: \$(ip route show default | head -1)
" | sed 's/^/  /'

echo "== P4 ($P4_PORT) -> STA $SSID ${TXP}dBm (static IP is baked into firmware) =="
python3 "$CLI" "$P4_PORT" sta --ssid "$SSID" --freq "$FREQ" --bw "$BW" --open --txpower "$TXP" \
  | sed 's/^/  /'

echo
echo "Done. Give it ~30s to associate, then: ./measure.sh"
