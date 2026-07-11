# bench — repeatable HaLow link test

Scripts to get the loft ↔ desk Wi-Fi HaLow link from cold back to a tested
state, and to measure it. This is the harness behind the `halow_netif` work in
[Xinyuan-LilyGO/T-Halow-P4#4](https://github.com/Xinyuan-LilyGO/T-Halow-P4/pull/4).

## Topology

```
 workstation                                      loft (airspy.local, Pi 4)
 ───────────                                      ─────────────────────────
 T-Halow-P4  ──USB──/dev/ttyACM1 (AT console)
   HaLow STA, 10.99.0.2 (static, in firmware)
        │ 866.0 MHz / 2 MHz
        └───────── ((( ~house distance ))) ───────┐
                                                   │
                                    T-Halow RJ45 board (HaLow AP)
                                      AT console ── /dev/ttyUSB0
                                      RJ45 ── ASIX AX88179 USB dongle ── eth1
                                                                          10.99.0.1/24
```

Both radios: SSID `halowbench`, 866.0 MHz (`--freq 8660`), 2 MHz, open, 14 dBm.

## Use

```bash
./bringup.sh          # cold -> tested state (idempotent)
sleep 30              # let it associate
./measure.sh          # RSSI both ways + end-to-end ping
```

Override any knob via env, e.g. `TXP=20 FREQ=9080 ./bringup.sh`.

## Why this exists — nothing here persists

- **The board reverts to STA on every power cycle.** `AT+MODE=ap` writes flash
  and works live, but the role is not restored at boot (SSID/bw/txpower are).
  So the loft AP must be re-asserted after any power cut — that is what
  `bringup.sh` does. For an unattended deployment, run it from a boot-time
  systemd unit on the loft Pi.
- **`eth1` reverts on Pi reboot.** NetworkManager will flush a manual IP off a
  managed device, so `bringup.sh` sets it `managed no` first, then a static
  address. The onboard `eth0` jack is dead (PHY healthy over MDIO, but no link
  partner ever — likely the jack magnetics); the USB dongle bypasses it.

## Known issue: the P4 transmits well below its set power

`measure.sh` reads RSSI in both directions. The channel is reciprocal, so with
equal TX power the two figures should match. They don't:

| direction | RSSI | notes |
|---|---|---|
| P4 hears AP (forward) | ~ -57 dBm | healthy |
| AP hears P4 (return)  | ~ -100 dBm | at the noise floor |

A ~43 dB gap with both ends at 14 dBm can only come from the P4 radiating far
below its setting (~ -28 dBm EIRP). Its RX is fine, so the antenna is connected
— the deficit is TX-specific. The 1 m bench hid this entirely (even -28 dBm is
strong at 1 m → 0% loss). At real distance the weak return path drops packets
or forces heavy link-layer retries (pings succeed but RTT spikes to ~1 s).

First things to try: a proper external antenna on the P4's sub-GHz (whip) port
rather than the stock antenna; confirm it is on the HaLow connector, not the
2.4 GHz patch; check `super_pwr` / `pa_pwrctrl` in `AT+WNBCFG`.

## Prerequisites

- `ssh airspy.local` reachable (key auth), passwordless `sudo` on the Pi.
- `~/thalow_config.py` present on the loft Pi (copy from `../cli/`).
- Serial device paths as in the knobs; the P4 may enumerate as `ttyACM0` or
  `ttyACM1`. A browser tab running the web configurator holds the port
  exclusively — close it before running these.
