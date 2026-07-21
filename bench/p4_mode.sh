#!/usr/bin/env bash
# p4_mode.sh — is the T-Halow-P4 running its app, or sitting in the ROM
# download (bootloader) state? Handy while fiddling with the BOOT/RST buttons.
#
#   APP       console is spewing        -> firmware running
#   DOWNLOAD  ROM bootloader            -> ready to flash
#   SILENT    quiet but not in the ROM  -> hung app; power-cycle it
#
# How DOWNLOAD is detected: the ROM prints "waiting for download" ONCE on entry
# and is then silent, so a passive read can't spot it after the fact. Whenever
# the port is silent this script asks the ROM directly with an esptool sync
# (read_mac, one attempt) — a reply means it's genuinely in the bootloader.
# That needs esptool on PATH (source ~/esp/esp-idf/export.sh first); without it
# the silent case can't be resolved and is shown as SILENT?.
#
# Usage:
#   ./p4_mode.sh          check once
#   ./p4_mode.sh -w       watch, re-check every 2s until Ctrl-C
#   PORT=/dev/ttyACM1 ./p4_mode.sh
set -u
PORT="${PORT:-/dev/ttyACM0}"
WATCH=0
for a in "$@"; do case "$a" in -w|--watch) WATCH=1 ;; esac; done  # (-p removed: probing is automatic when silent)

G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; Z=$'\e[0m'
HAVE_ESPTOOL=0
python -m esptool version >/dev/null 2>&1 && HAVE_ESPTOOL=1

esptool_says_download() {
  # --before/--after no_reset: don't toggle DTR/RTS (not wired to EN/BOOT here),
  # and leave the chip in the bootloader so a watch loop can't kick it out.
  timeout 8 python -m esptool --chip esp32p4 -p "$PORT" -b 115200 \
    --before no_reset --after no_reset --no-stub --connect-attempts 1 read_mac 2>/dev/null \
    | grep -qa 'Chip is ESP32-P4'
}

classify() {
  if [ ! -e "$PORT" ]; then
    printf '%sUNPLUGGED%s   %s absent\n' "$R" "$Z" "$PORT"; return
  fi
  stty -F "$PORT" 115200 raw -echo 2>/dev/null
  local out
  out=$(timeout 1.5 cat "$PORT" 2>/dev/null | tr -d '\0')

  # ROM download banner, on the off chance we caught the moment of entry.
  if printf '%s' "$out" | grep -qaiE 'download\(|waiting for download'; then
    printf '%sDOWNLOAD%s    ROM bootloader — ready to flash\n' "$G" "$Z"; return
  fi
  # Any continuous console output means the firmware is running: the ROM
  # download state is silent, so non-empty output is never the bootloader.
  if [ -n "${out//[[:space:]]/}" ]; then
    printf '%sAPP%s         firmware running\n' "$Y" "$Z"; return
  fi
  # Silent: ask the ROM whether it's actually in the bootloader.
  if [ "$HAVE_ESPTOOL" = 1 ]; then
    if esptool_says_download; then
      printf '%sDOWNLOAD%s    ROM bootloader — ready to flash (esptool synced)\n' "$G" "$Z"
    else
      printf '%sSILENT%s      quiet but not in the bootloader — hung app? power-cycle\n' "$R" "$Z"
    fi
  else
    printf '%sSILENT?%s     no output; source ~/esp/esp-idf/export.sh so I can esptool-probe it\n' "$C" "$Z"
  fi
}

if [ "$WATCH" = 1 ]; then
  echo "watching $PORT (Ctrl-C to stop)…"
  while true; do printf '%(%H:%M:%S)T  ' -1; classify; sleep 2; done
else
  classify
fi
