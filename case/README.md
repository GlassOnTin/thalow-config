# T-Halow-P4 case

A 3D-printable enclosure for the LilyGo **T-Halow-P4** (a 22 × 80 mm M.2 2280 board),
generated with the [YAPP_Box](https://github.com/mrWheel/YAPP_Box) OpenSCAD project-box
generator. Prints as two parts (base + lid) with a snap-fit lid.

## Generating the STLs

`thalow_p4_case.scad` `include`s the YAPP_Box generator, which is **not vendored here**
(it's MIT-licensed — fetch `YAPPgenerator_v3.scad` from the link above and drop it next to
the config). Then:

```sh
openscad -o thalow_p4_base.stl --render -D printLidShell=false -D showSideBySide=false thalow_p4_case.scad
openscad -o thalow_p4_lid.stl  --render -D printBaseShell=false -D showSideBySide=false thalow_p4_case.scad
```

## Layout (matches the LilyGo board)

- **96 × 29 mm** footprint. The front end is extended ~12 mm to house an **SMA bulkhead**
  for the HaLow antenna — a Ø7.35 mm hole, vertically centred in the front wall.
- **USB-C**: full-height slot on the finger (M.2-connector) end of the GPIO-side long wall.
- **Buttons**: a single long slot on the opposite long wall.
- **Snap-fit lid**; the clips on the button wall are pulled out to the ends so the long
  button slot clears them (YAPP snap joins take an explicit per-face position).
- The PCB is held by **double-sided tape against the lid** — no standoffs or screws.

## Printing

The first article was printed in **nylon (PA)** — the thin M.2-card region and the snap
joins flex without cracking. PETG/PLA should also work.

## Status

Test-fit / iterating. The board mounts and the P4 runs in the case (USB and HaLow both
verified working while enclosed). Open item: the button-slot height is referenced to the
board's modelled position, so it may want re-tuning now that the board tapes to the lid.
The other cutouts are insensitive to board height (USB-C is full height; the SMA is a
pigtail bulkhead).
