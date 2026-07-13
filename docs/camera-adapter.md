# J4 ↔ ESP32-P4-EYE camera adapter (flex)

A small **flex PCB** that remaps the LilyGo T-Halow-P4 `J4` camera connector to the
**ESP32-P4-EYE** 24-pin pinout, so the whole P4-EYE camera range — including the low-light
**SC2336** — can run on the T-Halow-P4. Both ends are 24-pin, 0.5 mm pitch, 1-lane MIPI CSI-2;
only the pin order (and one power rail) differ. See [`camera-pinout.md`](camera-pinout.md) for the
full map and sources.

## Function

Passive 1:1 signal remap — no active parts. It reorders the pins and drops one rail:

| Net | J4 tail pin(s) | Module socket pin(s) (CN1) | Route as |
|-----|:--------------:|:--------------------------:|----------|
| MIPI CLK+ | 7 | 18 | 100 Ω diff pair (with CLK−) |
| MIPI CLK− | 6 | 17 | 100 Ω diff pair |
| MIPI DATA0+ | 10 | 5 | 100 Ω diff pair (with DATA0−) |
| MIPI DATA0− | 9 | 6 | 100 Ω diff pair |
| MCLK | 14 | 20 | single-ended, keep short |
| I²C SCL | 21 | 22 | single-ended |
| I²C SDA | 20 | 23 | single-ended |
| RESET | 17 | 3 | single-ended |
| AVDD (2.8 V) | 23, 24 | 1, 2 | power |
| DOVDD (1.8 V) | 16 | 11, 12 | power |
| **DVDD (1.5 V)** | **12** | **— (no connect)** | P4-EYE module self-generates 1.5 V |
| GND | 5, 8, 13, 15, 19, 22 | 4, 7, 10, 13, 16, 19, 24 | common GND plane |

Unused/NC pins — J4 {1,2,3,4,11,18}, CN1 {8,9,14,15,21} — left open. Polarity is **preserved**
(+→+, −→−); do not swap pair polarity unless the host is configured for lane-polarity swap.

## Physical

- **J4 end:** bare 24-pin, 0.5 mm gold fingers (ENIG) + stiffener, inserts directly into J4's FFC
  socket. Match J4's contact side (top/bottom) — get this wrong and the pinout is silently mirrored.
- **Module end (CN1):** a 24-pin 0.5 mm FFC socket (e.g. Hirose FH12-24S-0.5SH or JLCPCB
  equivalent) on a stiffener; the camera module's own FPC plugs in here.
- **Stack-up:** 2-layer flex (polyimide) — signal + GND reference plane, so the CLK/DATA pairs get
  a solid return and controlled 100 Ω differential impedance.
- **Size:** ≈ 13.5 mm wide (24 × 0.5 mm + margins); length as short as practical (~25–35 mm).

See [`camera-adapter-outline.svg`](camera-adapter-outline.svg) for the mechanical outline.

## Why it must be a flex, not jumpers

This carries **MIPI D-PHY** — at 1080p30 RAW10, 1-lane ≈ **~650 Mbps** on the data pair. That needs
100 Ω controlled-impedance, length-matched (<0.1 mm skew within a pair) traces over a ground plane.
It **cannot** be hand-wired on a breakout; a proper flex (or equivalent 2-layer PCB) is required.

## Validate before fabbing a batch

- **J4 pinout** here is from the `AS-AA018A72M23-50` datasheet — **LilyGo can confirm it
  authoritatively** (a good reason to submit this to them).
- The **P4-EYE (CN1) pinout** is from the `HDF2710-47-MIPI` datasheet.
- Confirm the FFC **contact-side/orientation** on both ends against the physical connectors, and the
  target module's pinout, before committing.

## Build options

- **A — flex (this spec):** cleanest, smallest, best signal integrity. 2-layer flex + one FFC socket.
- **B — rigid PCB:** 2-layer PCB with two FFC sockets + a short straight 24-pin 0.5 mm FFC cable to
  J4. Easier to fab; adds a connector + cable in the MIPI path (fine at 1-lane if kept short).

## BOM (option A)

| Item | Qty | Note |
|------|:---:|------|
| 2-layer flex PCB | 1 | ENIG fingers on J4 end; 100 Ω diff control |
| 24-pin 0.5 mm FFC socket (CN1) | 1 | FH12-24S-0.5SH or equiv; match contact side |
| Stiffener (0.2–0.3 mm) | 2 | under CN1 and under J4-end fingers |
