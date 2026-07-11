#!/usr/bin/env python3
"""
thalow_config.py - configure a LilyGo T-Halow (Taixin TX-AH, WNB firmware)
over its USB-C serial console (CH340, 115200 8N1). Stdlib only; Linux/macOS.

The WNB firmware bridges the board's RJ45 <-> HaLow transparently at layer 2.
This tool only sets the radio role/SSID/frequency over the AT console; the
actual data path is the RJ45 jack, NOT the USB.

Examples:
  # one board as AP, the other as STA, same ssid/freq/bw, open (no crypto):
  sudo ./thalow_config.py /dev/ttyUSB0 ap  --ssid halowlink --freq 9080 --bw 8 --open
  sudo ./thalow_config.py /dev/ttyUSB0 sta --ssid halowlink --freq 9080 --bw 8 --open

  ./thalow_config.py /dev/ttyUSB0 status     # role, connection, RSSI, version
  ./thalow_config.py /dev/ttyUSB0 reset      # AT+LOADDEF=1 (factory defaults)

Verified on firmware hgSDK-v1.6.4.3 (TAIXIN-WNB). WPA-PSK path follows the
vendor AT reference but was not hardware-tested here -- see --psk.
"""
import argparse, os, sys, termios, time

BAUD = termios.B115200


def open_serial(dev):
    fd = os.open(dev, os.O_RDWR | os.O_NOCTTY)
    a = termios.tcgetattr(fd)
    a[0] = 0          # iflag: raw
    a[1] = 0          # oflag: raw
    a[3] = 0          # lflag: raw (no echo/canon)
    a[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    a[4] = a[5] = BAUD
    a[6][termios.VMIN] = 0
    a[6][termios.VTIME] = 2
    termios.tcsetattr(fd, termios.TCSANOW, a)
    return fd


def read_for(fd, secs):
    end = time.time() + secs
    buf = b""
    while time.time() < end:
        try:
            d = os.read(fd, 4096)
        except OSError:
            d = b""
        if d:
            buf += d
            end = time.time() + 0.25
    return buf


def cmd(fd, line, wait=1.2):
    """Send one AT command, return the textual response."""
    os.write(fd, line.encode() + b"\r\n")
    return read_for(fd, wait).decode("utf-8", "replace")


def resync(fd):
    """Recover a console stuck in AT+TXDATA data-mode or spewing debug:
    feed filler bytes to finish any pending read, then confirm AT works."""
    for _ in range(5):
        os.write(fd, b"\x55" * 1700)
        time.sleep(0.2)
        read_for(fd, 0.4)
        if "+MODE" in cmd(fd, "AT+MODE", 1.0):
            return True
    return False


def quiet(fd):
    cmd(fd, "AT+SYSDBG=LMAC,0")   # stop the periodic LMAC STATUS spew
    cmd(fd, "AT+SYSDBG=WNB,0")


def configure(fd, role, args):
    if not resync(fd):
        sys.exit("ERROR: no AT response on this port (wrong device/baud?)")
    quiet(fd)
    steps = [f"AT+MODE={role}", f"AT+SSID={args.ssid}"]
    if args.psk:
        steps += ["AT+KEYMGMT=WPA-PSK", f"AT+PSK={args.psk}"]
    else:
        steps += ["AT+KEYMGMT=NONE"]
    steps += [f"AT+CHAN_LIST={args.freq}", f"AT+BSS_BW={args.bw}"]
    if args.txpower is not None:
        steps += [f"AT+TXPOWER={args.txpower}"]
    for s in steps:
        r = cmd(fd, s).strip().splitlines()
        ok = any("OK" in x for x in r)
        print(f"  {s:24s} -> {'OK' if ok else r}")
    print(f"\nConfigured as {role.upper()}. Give it a few seconds, then run: "
          f"{sys.argv[0]} {args.port} status")


def status(fd):
    if not resync(fd):
        sys.exit("ERROR: no AT response on this port (wrong device/baud?)")
    quiet(fd)
    for c in ["AT+VERSION", "AT+MODE", "AT+CONN_STATE", "AT+RSSI"]:
        print(f"{c:16s}: {cmd(fd, c).strip()}")
    print("\n" + cmd(fd, "AT+WNBCFG", 2.0).strip())


def main():
    p = argparse.ArgumentParser(description="Configure a LilyGo T-Halow over serial.")
    p.add_argument("port", help="serial device, e.g. /dev/ttyUSB0")
    p.add_argument("action", choices=["ap", "sta", "status", "reset"])
    p.add_argument("--ssid", default="halowlink")
    p.add_argument("--freq", default="9080",
                   help="center freq x10 MHz, e.g. 9080 = 908.0 MHz (single channel)")
    p.add_argument("--bw", default="8", choices=["1", "2", "4", "8"],
                   help="bandwidth in MHz")
    p.add_argument("--txpower", type=int, metavar="DBM",
                   help="TX power in dBm (6-20); omit to leave unchanged")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--open", action="store_true", help="no encryption (default)")
    g.add_argument("--psk", metavar="HEX64",
                   help="WPA-PSK as 64 hex chars (the PMK); set identical on both ends")
    args = p.parse_args()

    fd = open_serial(args.port)
    try:
        if args.action in ("ap", "sta"):
            configure(fd, args.action, args)
        elif args.action == "status":
            status(fd)
        elif args.action == "reset":
            if not resync(fd):
                sys.exit("ERROR: no AT response on this port")
            print(cmd(fd, "AT+LOADDEF=1", 3.0).strip())
            print("Factory defaults restored; board reboots to role=sta, no SSID.")
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()
