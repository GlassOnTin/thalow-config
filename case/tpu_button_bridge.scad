// ================================================================
// TPU button bridge — LilyGo T-Halow-P4 case  (BASE opening, press-down)
//
// A flexible TPU insert that fills an opening in the case BASE. Two
// finger pads poke out the bottom; pressing each one lifts a short
// plunger UP onto the down-facing BOOT / RST tact switch across the
// standoff gap. Each key hangs on its own thin annular web (living
// hinge) so holding BOOT does not drag on RST, and vice-versa.
// Print in TPU, flat, finger-pads down on the bed (no supports).
//
// Vertical scheme (z = 0 is the base-plate INNER floor):
//   base plate  : z = -base_thick .. 0   (the opening is a hole in it)
//   finger pad  : z < -base_thick         (pokes out the bottom)
//   body/hinge  : z = -memb_th .. 0        (within the opening)
//   plunger     : z = 0 .. rest_gap+       (up into the gap to the switch)
//   switch tip  : z = +rest_gap            (down-facing tact)
// ================================================================

/* [ MEASURE from your board — these drive the fit ] */
button_pitch = 10.0;  // centre-to-centre BOOT <-> RST                       [MEASURE]
rest_gap     = 0.5;   // base inner floor -> tact actuator tip at rest
                      //   (= standoffHeight 2.5 - button height 2.0)        [MEASURE]
actuator_dia = 1.5;   // tact-switch actuator tip diameter (SW_1010A)        [MEASURE]

/* [ case interface — from thalow_p4_case.scad ] */
base_thick   = 1.5;   // basePlaneThickness = opening depth

/* [ design knobs ] */
pad_dia      = 6.0;   // finger pad diameter
outer_proud  = 0.6;   // finger pad sticks this far past the outer base face
plunger_dia  = 2.6;   // plunger dia (>= actuator_dia + slop)
over_travel  = 0.2;   // plunger reaches this far past rest_gap (light preload)
memb_th      = 0.9;   // sheet thickness (< base_thick)
hinge_th     = 0.4;   // thinned web around each key (decouples the two keys)
moat_w       = 1.3;   // width of the thinned decoupling ring
flange_th    = 0.8;   // retaining-lip thickness (inner overhang)
flange_w     = 1.6;   // lip overlap onto the base inner face around the opening
$fn          = 64;

// ---- derived footprint (open_* = the BASE opening you must cut) ----
key_win  = pad_dia + 2*moat_w + 0.6;    // clear window per key (pad + its moat)
open_len = button_pitch + key_win;      // BASE OPENING length (X)
open_wid = key_win;                     // BASE OPENING width  (Y)
part_len = open_len + 2*flange_w;       // flange outer length
part_wid = open_wid + 2*flange_w;
plung_h  = rest_gap + over_travel;

assert(memb_th < base_thick, "memb_th must be < base_thick");
assert(hinge_th < memb_th,   "hinge_th must be < memb_th");
assert(plunger_dia >= actuator_dia, "plunger must cover the actuator");
echo(str(">>> BASE OPENING to cut in the case: ", open_len, " x ", open_wid,
         " mm  (flange overlaps +", flange_w, " all round)"));
echo(str(">>> Part footprint: ", part_len, " x ", part_wid, " mm"));

module rrect(l, w, th, r = 2)
  linear_extrude(th) offset(r) offset(-r) square([l, w], center = true);

module key(sign)
  translate([sign * button_pitch/2, 0, 0]) {
    // finger pad — pokes out below the outer base face (widening up: clean pad-down print)
    translate([0, 0, -(base_thick + outer_proud)])
      cylinder(d1 = pad_dia*0.7, d2 = pad_dia, h = outer_proud);
    // key body — fills the opening depth
    translate([0, 0, -base_thick]) cylinder(d = pad_dia, h = base_thick);
    // plunger — pokes UP onto the switch
    cylinder(d1 = plunger_dia + 0.6, d2 = plunger_dia, h = plung_h);
  }

difference() {
  union() {
    // retaining flange: inner-overhang RING (stops it pulling out the bottom),
    // centre open so the plungers are clear
    difference() {
      rrect(part_len, part_wid, flange_th);
      translate([0, 0, -1]) rrect(open_len - 0.4, open_wid - 0.4, flange_th + 2);
    }
    // flexible sheet spanning the opening
    translate([0, 0, -memb_th]) rrect(open_len, open_wid, memb_th);
    key(+1);
    key(-1);
  }
  // decoupling moat: thin the sheet to hinge_th in a ring around each key,
  // carved from the OUTER (bottom) face
  for (s = [-1, 1])
    translate([s * button_pitch/2, 0, -memb_th])
      difference() {
        cylinder(d = pad_dia + 2*moat_w, h = memb_th - hinge_th);
        translate([0, 0, -1]) cylinder(d = pad_dia, h = memb_th + 1);
      }
}
