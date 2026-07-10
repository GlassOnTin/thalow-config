# T-Halow Config

A browser-based configurator for LilyGo **T-Halow** boards (Taixin TX-AH / HUGE-IC "WNB"
firmware). It speaks the documented AT command set over the board's USB serial console, so it
needs no drivers, no Python, and no install — just Chrome and a USB cable.

Contains **no vendor driver code**. Only AT strings.

## Why Web Serial and not WebHID

The boards are not HID devices:

| Board | USB ID | Interface class | Driver |
|---|---|---|---|
| T-Halow-P4 | `1a86:55d3` | `020201:0a0000` (CDC) | `cdc_acm` |
| T-Halow RJ45 | `1a86:7523` | `ff0102` (vendor) | `ch341` |

`navigator.hid` only enumerates HID-class devices, so neither board is visible to WebHID.
`navigator.serial` handles both.

## Requirements

Chrome, Edge or Opera **on desktop**. Firefox and Safari do not implement Web Serial, and it is
not available on Android. A secure context is required, so serve over `https://` or from
`localhost` — opening `index.html` as a `file://` URL will not work.

```bash
python3 -m http.server 8000
# then visit http://localhost:8000
```

On Linux your user must be able to open the port (usually the `dialout` group).

## What it does

- Reads `AT+VERSION`, `AT+MODE` and `AT+WNBCFG` into a status table.
- Polls `AT+CONN_STATE` and `AT+RSSI`, with a rolling RSSI trace — useful when siting an antenna.
- Applies role, SSID, frequency, bandwidth, encryption and TX power in one go.
- Has a raw AT console for anything not covered by the form.

## Things it knows that the vendor documentation does not

These were found the hard way, and the tool encodes them so you do not have to.

**Factory-reset before reconfiguring.** Changing role, frequency or bandwidth on a board that
already has a stored configuration frequently leaves the two ends unable to associate, with no
error reported at either end. `AT+LOADDEF=1` first, then configure, and it comes up. The
*Factory reset first* checkbox is on by default; it costs about 12 seconds.

**A channel must fit inside its band.** Bandwidth is centred on the frequency you give, so an
8 MHz channel on 866.0 MHz spans 862.0–870.0 MHz and falls out of the UK/EU 863–868 MHz band at
both edges. The page computes the span and warns. Pick 1 or 2 MHz at 866.0.

**908 MHz is the US band.** The UK/EU SRD band is 863–868 MHz. Boards ship configured for either
depending on the variant, and the radio will happily transmit wherever you point it.

**`tx_power` defaults to 20 dBm**, which is above the 14 dBm ERP normally permitted in
863–868 MHz. The form defaults to 14 and warns above it.

**The console needs quietening.** The radio dumps a periodic `LMAC STATUS` block that lands in the
middle of command replies. Connecting issues `AT+SYSDBG=LMAC,0` and resynchronises first. On the
T-Halow-P4 the problem is worse: the ESP32-P4's own log output shares the same USB serial port as
the radio's AT UART, so replies always arrive interleaved with firmware logs.

**DTR/RTS are not wired to EN/BOOT** on the T-Halow-P4, so nothing here can reset or flash the
board — that remains a manual BOOT+RST affair. The page explicitly clears both signals on open so
it can never reset a board that *does* wire them.

## Languages

English, 简体中文, 日本語, Deutsch, Français, Español. The language is picked from
`navigator.languages` on first load and remembered thereafter; the selector is top-right.

English and 简体中文 were written by hand. The other four are best-effort — **corrections are very
welcome**, and are a one-line change: every string lives in the `STRINGS` table at the top of the
`<script>` block in `index.html`, and all languages carry the same 73 keys. Right-to-left languages
are not supported; the layout has no `dir="rtl"` path.

## Documentation

### The boards

- [`Xinyuan-LilyGO/T-Halow-P4`](https://github.com/Xinyuan-LilyGO/T-Halow-P4) — ESP32-P4 + HaLow board.
- [`Xinyuan-LilyGO/T-Halow`](https://github.com/Xinyuan-LilyGO/T-Halow) — the original RJ45 boards.
- [T-Halow P4 product page](https://lilygo.cc/products/t-halow-p4) — sold in 868, 915 and 920 MHz variants.

### The AT command set

- [`doc/AT_cmd.md`](https://github.com/Xinyuan-LilyGO/T-Halow-P4/blob/master/doc/AT_cmd.md) — the
  commands this tool sends. Note that `AT+LOADDEF`, `AT+TXPOWER` and `AT+SYSDBG` are documented
  only sparsely, and the ordering constraints are not documented at all.
- [`hardware/`](https://github.com/Xinyuan-LilyGO/T-Halow-P4/tree/master/hardware) — schematic, plus
  the Taixin AT and non-OS driver PDFs.
- [Taixin Semiconductor](https://www.taixin-semi.com/) — the module vendor (泰芯). The non-OS
  Wi-Fi driver is linked from the T-Halow-P4 README.

### Related work in these repos

- [T-Halow-P4 PR #4](https://github.com/Xinyuan-LilyGO/T-Halow-P4/pull/4) — `esp_netif` driver giving
  the ESP32-P4 an IP stack over HaLow, and three fixes to the vendor SPI path.
- [T-Halow-P4 issue #3](https://github.com/Xinyuan-LilyGO/T-Halow-P4/issues/3) — which camera module
  mates with the board's `J4` connector.

### Web Serial

- [MDN: Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API)
- [Specification](https://wicg.github.io/serial/) (WICG)
- [Browser support](https://caniuse.com/web-serial) — Chromium desktop only.

## Licence

AGPL-3.0-or-later.
