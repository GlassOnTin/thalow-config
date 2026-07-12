# Bringing up the LilyGo T-Halow-P4

Notes from getting a LilyGo **T-Halow-P4** talking IP over Wi-Fi HaLow, configuring
its radio, and characterising the link — including a wrong turn that's worth
recording because the fix was *methodology*, not code.

Everything here was done against **ESP-IDF v5.4.1** on Linux. Corrections welcome.

- Firmware contribution: [Xinyuan-LilyGO/T-Halow-P4#4](https://github.com/Xinyuan-LilyGO/T-Halow-P4/pull/4)
- Browser configurator: this repo → [glassontin.github.io/thalow-config](https://glassontin.github.io/thalow-config/)
- Open question to the vendor about the camera connector: [#3](https://github.com/Xinyuan-LilyGO/T-Halow-P4/issues/3)

---

## What the board actually is

Three radios and one brain, which matters because none of them is where you'd
first assume:

| Part | Role | Interface |
|---|---|---|
| **ESP32-P4** | The application CPU. **Has no radio of its own.** | — |
| **ESP32-C6** | 2.4 GHz Wi-Fi 6 + BLE 5, via `esp-hosted-mcu` | SDIO |
| **Taixin TX-AH-R900PNR** | Wi-Fi HaLow (802.11ah, sub-GHz) | SPI (data) + a separate UART (AT) |

So the P4's only networking comes from the two attached radios. The **patch
antenna** is the C6's 2.4 GHz; the **large sub-GHz antenna** is the HaLow module
(silkscreened "T-Halow 875M SAW").

The USB-C port is a **CH343** (`1a86:55d3`) presenting a CDC-ACM serial port
(`/dev/ttyACM*`). Importantly, the P4's own console **and** the HaLow module's AT
UART are multiplexed onto that one serial port — so you can drive the radio over
USB with no firmware flashed.

---

## IP over Wi-Fi HaLow

This was the goal: give the P4 an ordinary IP stack over the sub-GHz link, so it
can `ping`/UDP/TCP like any `esp_netif` device. The AP-side board (a T-Halow RJ45
board) bridges the BSS onto ethernet at layer 2, so frames the P4 sends land
directly on that wire.

### Don't port the vendor's lwIP demo

The stock `examples/halow_spi_single` is **not** a network example — its core is
`hgic_raw_test`/`hgic_raw_test2`, a throughput test, and the repo docs mark it
`暂时不可用` ("temporarily unavailable"). Buried in the driver is
`demo/hgic_lwip_demo.c`, which *looks* like the answer but isn't: it targets raw
lwIP (which ESP-IDF hides behind `esp_netif`), it doesn't compile (a stray comma),
and it couldn't link even fixed (see bug 1 below).

The driver already hands you a complete ethernet frame on both edges:

```c
hgic_raw_send_ether(frame, len);                    // TX
hgic_raw_rx(&frame, &len) == HGIC_RAW_RX_TYPE_DATA  // RX  (advances past the hgic header)
```

So the port is just to hang those two calls off an `esp_netif` driver, the same
way `esp-hosted` does — about 130 lines. That's the `hgic_netif` component in
PR #4.

### Four things that bite, all found by something failing

1. **`raw_send()` collides with lwIP.** The vendor driver requires the
   *application* to export a global `raw_send()`. lwIP also exports one
   (`lwip/src/core/raw.c`), and `LWIP_RAW` is hard-wired to `1` in ESP-IDF with no
   Kconfig (the ping app needs it). The moment any netif is linked, the build dies
   on `multiple definition of 'raw_send'`. Fix: rename the vendor hook with a
   compile definition on the vendor component —
   `target_compile_definitions(${COMPONENT_LIB} PUBLIC raw_send=hgic_spi_raw_send)`
   — touching no vendor source. This is also *why the vendor's own lwIP demo could
   never have linked.*

2. **`hgic_raw_get_fwinfo()` is asynchronous.** It only *writes* the request;
   `hgic.addr` (the module MAC) is populated later, inside `hgic_raw_rx()`, when
   the response arrives. Read the MAC straight after the call and you get
   `00:00:00:00:00:00`, so the interface comes up with an all-zero hardware
   address. Pump RX until a real MAC appears.

3. **The module interrupt is edge-triggered (FALLING).** Read one buffer per
   interrupt and you strand any frame that arrived while you were servicing the
   previous one — the line is already low, so no new edge fires. Drain in a loop
   until the read returns empty.

4. **`uart_driver_install()` eats queued log output.** Installing the driver on
   the console UART resets its TX FIFO, discarding anything `app_main()` printed in
   the moments before. `fflush(stdout)` + `esp_rom_uart_tx_wait_idle()` first. The
   stock `echo_task()` has the same bug; it just never prints anything worth
   losing.

### Result

Two boards 1 m apart, 866.0 MHz, 2 MHz bandwidth, open, at low power:

```
400 packets transmitted, 400 received, 0% packet loss
~1.28 Mbps each way, 1500-byte MTU with DF set
```

Throughput (iperf) is still unmeasured — ping gives latency and loss, not Mbps.

---

## Configuring the radio (AT)

The HaLow module is configured with AT commands over the serial console — no
flashing needed. Two front-ends for it live in this repo:

- **[Browser configurator](https://glassontin.github.io/thalow-config/)** — Web
  Serial, no install, desktop Chrome/Edge. (Not WebHID: these boards are CDC /
  vendor-class serial, not HID, so `navigator.hid` can't see them.)
- **`cli/thalow_config.py`** — the scriptable original the web app is a port of.

Both encode the things the vendor docs don't say:

- **`AT+LOADDEF=1` before reconfiguring.** Changing role/frequency/bandwidth on a
  board that already holds a stored config frequently leaves the two ends unable to
  associate, **with no error reported at either end**. Factory-reset first, then
  configure. This one cost an hour before we spotted it.
- **Bandwidth is centred on the frequency.** An 8 MHz channel on 866.0 MHz spans
  862–870 MHz and falls out of the UK/EU 863–868 band at both edges. Use 1 or
  2 MHz at 866.0.
- **866.0 MHz is UK/EU; 908 MHz is the US band.** Boards ship configured for
  either depending on variant, and the radio transmits wherever you point it.
- **`tx_power` defaults to 20 dBm**, above the 14 dBm ERP usually permitted in
  863–868 MHz. (And see the SDR section — the *setting* appears not to change the
  actual output anyway.)
- **The console needs quietening.** The radio dumps a periodic `LMAC STATUS`
  block into the middle of command replies; `AT+SYSDBG=LMAC,0` stops it. On the P4
  the ESP32's own log output also shares the port.
- **AP role does not survive a power cycle.** `AT+MODE=ap` writes flash and works
  live, but the role reverts to `sta` on the next boot (SSID/bandwidth/power
  persist). A standalone AP therefore needs its role re-asserted at boot — e.g. a
  systemd unit running the CLI. On the P4 our firmware sets the mode every boot, so
  it's immune.

---

## Flashing notes

- **No auto-reset.** DTR/RTS only force *download* mode; booting the app needs a
  manual **RST** press or a **USB power-cycle** (esptool's "hard reset via RTS"
  does not stick on this board). Every flash is therefore: hold **BOOT**, tap
  **RST**, release RST, release BOOT → flash → tap **RST** to run.
- A full **16 MB flash read/write takes ~4 minutes** — run it detached, not in a
  2-minute-capped shell.
- The factory image is recoverable from `firmware/factory_no_screen.bin` in the
  vendor repo; a full 16 MB dump additionally carries the bootloader, `nvs` and
  per-board `phy_init` calibration.

---

## Measuring the link — and a wrong turn worth recording

A real-distance test (a loft AP with a good colinear antenna, the P4 on a desk a
floor below) worked but lost 40–75 % of packets. The loft AP's per-STA RSSI field
read the P4 at **≈ −94 dBm** while the P4 heard the loft at **−51 dBm** — an
apparent **~43 dB transmit asymmetry**.

We chased that as a **P4 transmitter hardware fault** and built a thorough case
for it:

- antennas confirmed correctly connected (clear silkscreen labels);
- the P4's `AT+WNBCFG` was *identical* to the working boards (`tx_power`,
  `pa_pwrctrl_dis`, `super_pwr`, antenna config all matching);
- disabling closed-loop PA power control (`pa_pwrctrl_dis=1`) + commanding max
  power changed nothing;
- `AT+TXPOWER` swept 6→20 dBm produced a *flat* received level on **both** boards
  (the setting appears inert);
- head-to-head at 1 m against a *second* independent RJ45 board reproduced the gap;
- **even the pristine factory firmware** showed the same deficit, ruling out our
  own firmware.

That's a lot of controls, and they all pointed one way. We were about to file a
hardware-defect report to LilyGo.

**Then we measured it with the right instrument** — an SDRplay RSPdx-R2 as an
independent receiver, keying the module's production-test carrier
(`AT+TEST_START=1; AT+TX_CW=1`). Ground truth:

> The P4 emits a **strong** CW carrier — SNR ~57 dB, matching or exceeding the
> reference RJ45 board on the same receiver. **The transmitter is fine.**

The ~43 dB "deficit" was an **artifact of the HaLow module's own RSSI reporting**
(the AP's per-STA field was most likely reporting the noise floor, not the P4's
signal). The link genuinely worked — association held, pings crossed — which had
always been slightly at odds with "40 dB weak"; we'd rationalised that away instead
of trusting it. The real cause of the lossy loft link is most consistent with the
colinear's **downward radiation null** (the desk sat under it) plus that unreliable
RSSI field — a geometry problem, not a hardware one.

The lesson we'd underline for anyone else on this board: **the HaLow module's
reported RSSI is not a reliable absolute measurement.** Confirm anything
power/range-related with an independent receiver before concluding — and
especially before filing a defect report. A pile of consistent-but-derived
measurements can all be wrong together if they share one bad instrument.

Two loose ends from that dig, unresolved:

- `AT+TXPOWER` appears not to change the actual radiated power (flat on two
  boards). Worth verifying properly on the SDR.
- Test-mode `AT+TX_CW` ignores `AT+CHAN_LIST` — both boards' CW landed off the
  commanded channel, at *different* frequencies — so it can't be used to check the
  operational TX frequency.

The bench harness for all this (`bench/bringup.sh`, `bench/measure.sh`) is in this
repo.

---

## The camera

The goal was a HaLow wildlife camera. This half is **hardware-blocked**:

- **No IMX477 driver** exists for the ESP32-P4 (`esp_cam_sensor` supports
  OV2710, SC2336, OV5647, etc., not IMX477). And an Arducam IMX477 is a Pi-style
  22-pin board — self-regulated rails, its own oscillator, 3.3 V I²C — the opposite
  convention to the P4's connector.
- The board's camera connector **`J4`** is a **24-pin 0.5 mm bare-CCM** socket: the
  host supplies 2.8/1.8/1.5 V rails **and** the master clock, with I²C level-shifted
  to 1.8 V, and **no board-level PA/switch**. LilyGo sells no MIPI camera — their
  camera accessories are all **DVP** on an identical-looking 24-pin footprint (a
  trap). The intended sensor is OV2710 (the `camera_display` example enables it and
  ships its tuning JSON).
- **The software is ready**: `camera_display` builds clean against IDF 5.4.1 with
  the OV2710 and SC2336 drivers compiled in. What's missing is a **24-pin CCM whose
  pinout matches `J4`** — which needs a continuity check on the board and a sourced
  module to verify, since the vendor hasn't answered [#3](https://github.com/Xinyuan-LilyGO/T-Halow-P4/issues/3)
  and the repo has been quiet since February.

A `J4` pin map read from the schematic is in issue #3.

---

## Enclosure

A parametric case (YAPP_Box) for the 22×80 mm M.2 (2280) board:
`case/YAPP_Box/thalow_p4_case.scad` in the `thalow-contrib` repo. Key measured
dimensions: PCB 1 mm; 2 mm buttons on the back face (→ 2.5 mm standoffs); 3.25 mm
USB-C on the RF face (→ ~4 mm lid clearance).

---

## Status

| Piece | State |
|---|---|
| IP over HaLow (`hgic_netif` esp_netif driver) | Working; PR [#4](https://github.com/Xinyuan-LilyGO/T-Halow-P4/pull/4) |
| Browser + CLI configurator | Done; [live](https://glassontin.github.io/thalow-config/), PR [#5](https://github.com/Xinyuan-LilyGO/T-Halow-P4/pull/5) |
| Bench harness (bringup + measure) | Done (`bench/`) |
| P4 transmitter | **Confirmed healthy** (SDR) — the "deficit" was a measurement artifact |
| Throughput (iperf) | Not yet measured |
| Camera | Software ready; blocked on a `J4`-compatible CCM |
| Enclosure | Base test-printing |
