# T-Halow-P4 camera (J4) pinout map & adapter

A reference for putting a MIPI CSI-2 camera on the LilyGo **T-Halow-P4** `J4` connector —
and why "any 24-pin camera" does **not** work.

> **The core problem:** *"24-pin MIPI camera" is not a standard pinout.* Several boards use a
> 24-pin 0.5 mm FFC for a MIPI camera, each with a **different signal order**. Two modules can
> even use the **same sensor (OV2710) from the same maker (HongJia)** and still be wired
> differently. A connector that physically mates tells you nothing about electrical compatibility.

## Reference pinouts

### 1. LilyGo T-Halow-P4 `J4` — module `AS-AA018A72M23-50` (OV2710, 1-lane MIPI, 24-pin 0.5 mm)

| Pin | Signal | Pin | Signal |
|----:|--------|----:|--------|
| 1–4 | NC | 13 | GND |
| 5 | GND | 14 | **MCLK** (ext ~24 MHz) |
| 6 | CKN (CLK−) | 15 | GND |
| 7 | CKP (CLK+) | 16 | DOVDD (1.8 V) |
| 8 | GND | 17 | RST |
| 9 | DON (DATA0−) | 18 | NC |
| 10 | DOP (DATA0+) | 19 | GND |
| 11 | NC | 20 | SDA |
| 12 | **DVDD (1.5 V)** | 21 | SCL |
| | | 22 | GND |
| | | 23–24 | AVDD (2.8 V) |

### 2. Espressif ESP32-P4-EYE — module `HDF2710-47-MIPI` (OV2710, 1-lane MIPI, 24-pin)

| Pin | Signal | Pin | Signal |
|----:|--------|----:|--------|
| 1–2 | AVDD | 13 | GND |
| 3 | RESET | 14–15 | NC |
| 4 | GND | 16 | GND |
| 5 | MDP (DATA0+) | 17 | MCN (CLK−) |
| 6 | MDN (DATA0−) | 18 | MCP (CLK+) |
| 7 | GND | 19 | GND |
| 8–9 | NC | 20 | **MCLK** |
| 10 | GND | 21 | NC |
| 11–12 | DOVDD (1.8 V) | 22 | SCL |
| | | 23 | SDA |
| | | 24 | GND |

*Note: no DVDD pin — the 1.5 V core is generated on-module.*

### 3. Raspberry Pi CSI (15-pin, 1.0 mm) — for contrast

`1 GND · 2 D0− · 3 D0+ · 4 GND · 5 D1− · 6 D1+ · 7 GND · 8 CLK− · 9 CLK+ · 10 GND ·
11 GPIO0 · 12 GPIO1 · 13 SCL · 14 SDA · 15 3V3`

## Signal-aligned comparison

| Signal | J4 pin | P4-EYE pin | RPi 15-pin |
|--------|:------:|:----------:|:----------:|
| AVDD (≈2.8 V) | 23, 24 | 1, 2 | 15 (3V3, on-board reg) |
| RESET | 17 | 3 | via I²C GPIO |
| DOVDD (1.8 V) | 16 | 11, 12 | on-board reg |
| **DVDD (1.5 V)** | **12** | **— (internal)** | internal |
| **MCLK (ext)** | **14** | **20** | **— (self-clocked xtal)** |
| MIPI CLK + / − | 7 / 6 | 18 / 17 | 9 / 8 |
| MIPI DATA0 + / − | 10 / 9 | 5 / 6 | 3 / 2 |
| MIPI DATA1 + / − | — (1-lane) | — (1-lane) | 6 / 5 (**2-lane**) |
| I²C SCL / SDA | 21 / 20 | 22 / 23 | 13 / 14 |
| GND | 5,8,13,15,19,22 | 4,7,10,13,16,19,24 | 1,4,7,10 |

**Findings**

- **J4 and P4-EYE are a full 24→24 remap** — every signal is on a different pin — but the signal
  *sets* are identical and each differential pair stays adjacent on both sides, so a passive
  remap adapter is feasible (see below). That adapter makes the **whole ESP32-P4-EYE camera
  range (incl. SC2336) usable on J4**.
- **One electrical difference:** J4 supplies **DVDD (1.5 V)** on pin 12; P4-EYE modules generate
  it internally. When driving a P4-EYE-style module through the adapter, leave J4 pin 12 open.
- **Raspberry Pi cameras are architecturally different**, not just re-pinned: **2-lane** (J4 is
  1-lane), **self-clocked** (no MCLK line; J4 feeds MCLK to a bare sensor), single 3V3 rail, and
  a 15-pin/1.0 mm connector. Not an adapter job — use a bare 24-pin sensor module instead.

## J4 ↔ P4-EYE adapter

Maps a **P4-EYE-pinout camera module** onto the **J4 host**. Wire each J4-host pin to the module
pin carrying the same signal:

| Signal | J4 host pin | → | P4-EYE module pin |
|--------|:-----------:|:-:|:-----------------:|
| AVDD | 23, 24 | → | 1, 2 |
| RESET | 17 | → | 3 |
| DOVDD | 16 | → | 11, 12 |
| DVDD (1.5 V) | 12 | → | **NC** (self-generated) |
| MCLK | 14 | → | 20 |
| MIPI CLK+ | 7 | → | 18 |
| MIPI CLK− | 6 | → | 17 |
| MIPI DATA0+ | 10 | → | 5 |
| MIPI DATA0− | 9 | → | 6 |
| I²C SCL | 21 | → | 22 |
| I²C SDA | 20 | → | 23 |
| GND | 5,8,13,15,19,22 | → | tie all to GND plane |

**Design rules (this is MIPI D-PHY — it must be impedance-controlled, not hand-wired):**

- Route **CLK** (6/7 ↔ 17/18) and **DATA0** (9/10 ↔ 5/6) as **100 Ω differential pairs** over a
  solid GND plane; **length-match within each pair** (<0.1 mm skew). Preserve polarity (+→+, −→−).
- 1-lane 1080p30 RAW10 ≈ **~650 Mbps** on the data lane — well inside D-PHY, but still needs the
  100 Ω control. Keep the adapter **as short as possible**.
- MCLK is a single-ended ~24 MHz clock — keep it short and away from the pairs.
- **FFC contact-side matters:** the connector (top/bottom contact) and any FFC cable
  (same-side / opposite-side contacts) must be chosen so the pinout isn't silently reversed — the
  classic FPC bring-up bug.

**Build options**

- **A — rigid PCB (easiest to fab):** 2-layer PCB with two 24-pin 0.5 mm FFC connectors
  (e.g. Hirose FH12-24S-0.5SH or a JLCPCB equivalent), remap routed between them with a GND
  plane. Camera FPC into one; a short straight 24-pin 0.5 mm FFC cable to J4 on the other.
- **B — flex FPC (cleanest):** 2-layer flex with the module-side FFC connector at one end and
  bare 24-pin 0.5 mm gold fingers + stiffener at the J4 end. Smaller, fewer connectors, better SI.

## Sensor notes

- **OV2710** — LilyGo's J4 sensor; driver already in the repo's `camera_display` example. Fine by
  day; weaker low-light.
- **SC2336** — Espressif's ESP32-P4 reference sensor (better NIR/low-light → better for nocturnal
  wildlife); driver + ISP tuning ship in the repo. Sold as P4-EYE-pinout modules → needs the
  adapter above to run on J4.

## Status / to verify on the bench

- J4 column is from the `AS-AA018A72M23-50` datasheet; confirm against the physical board
  (continuity) before fabbing an adapter.
- The `RH1OM8-P4` OV2710 module (ordered for test) is "for ESP32-P4" but its pinout is
  unconfirmed — it may match **J4**, match **P4-EYE**, or be a third variant. Checking it against
  both columns above decides whether it drops in or needs the adapter.

## Sources

- LilyGo J4 module: `AS-AA018A72M23-50` datasheet (T-Halow-P4 repo `hardware/`).
- ESP32-P4-EYE module: `HDF2710-47-MIPI-V2.0` datasheet (Espressif `dl.espressif.com`).
- [T-Halow-P4 issue #3](https://github.com/Xinyuan-LilyGO/T-Halow-P4/issues/3) — LilyGo confirming
  the J4 mapping and that it differs from Espressif's reference.
