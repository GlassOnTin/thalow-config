# thalow_config.py

The command-line configurator for LilyGo T-Halow boards (Taixin TX-AH / WNB
firmware). The [web app](../index.html) is a browser port of this; this is the
scriptable original, stdlib-only (Linux/macOS).

```bash
# one board AP, the other STA — same ssid/freq/bw, open, 14 dBm:
sudo ./thalow_config.py /dev/ttyUSB0 ap  --ssid halowbench --freq 8660 --bw 2 --open --txpower 14
sudo ./thalow_config.py /dev/ttyACM1 sta --ssid halowbench --freq 8660 --bw 2 --open --txpower 14

./thalow_config.py /dev/ttyUSB0 status   # role, connection, RSSI, full WNBCFG
./thalow_config.py /dev/ttyUSB0 reset    # AT+LOADDEF=1 (factory defaults)
```

`--freq` is the centre frequency ×10 MHz (`8660` = 866.0 MHz, inside the UK/EU
863–868 band; `9080` = 908.0 MHz is the US band). Bandwidth is centred on it, so
keep `--bw` small enough to stay inside your band. `--txpower` is omitted by
default (leaves the stored value); set it explicitly for reproducible tests.

Always `reset` both ends before reconfiguring if association fails — the WNB
firmware applies a changed config inconsistently otherwise, with no error at
either end.
