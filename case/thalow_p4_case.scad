//-----------------------------------------------------------------------
// Case for LilyGo T-Halow-P4  (YAPP_Box config)
// Board: 22 x 80 mm M.2 card (2280 form factor).
//
// Orientation used here (confirm/adjust against photos):
//   X (length 80): M.2 gold-finger edge = Back (X=0) -> screw-notch end = Front (X=80)
//   Y (width 22) : Left edge (Y=0) has the buttons; Right edge (Y=22)
//   Buttons  : LEFT edge, top ~2/3 (toward the screw/Front end, away from M.2 fingers)
//   USB-C    : bottom-right corner, opposite the buttons (near the M.2/Back end)
//
// TODO from photos + calipers (marked [MEASURE] below):
//   - exact X positions of each button along the Left edge, and button count
//   - exact USB-C position + whether it exits the Right edge or the Back end face
//   - the two antenna u.FL connectors (HaLow + C6) — which edge/end they exit
//   - tallest component height (module cans / u.FL) -> lid clearance
//   - underside component height -> standoffHeight
//   - M.2 gold-finger edge: leave an opening or wall it off?
//-----------------------------------------------------------------------
include <./YAPPgenerator_v3.scad>

printBaseShell        = true;
printLidShell         = true;
printSwitchExtenders  = true;   // button extenders for the Left-edge buttons
printDisplayClips     = false;

pcbLength           = 80;     // X : M.2 fingers (Back,0) -> screw end (Front,80)
pcbWidth            = 22;     // Y
pcbThickness        = 1.0;    // measured
standoffHeight      = 2.5;    // below-PCB: fits the 2mm buttons on the back face (+0.5 clr)
standoffDiameter    = 5;
standoffPinDiameter = 2.0;
standoffHoleSlack   = 0.4;
// Heights (measured): back(bottom) side = 2mm buttons; RF(top) side = 3.25mm USB-C.
// [CONFIRM] any top module/u.FL taller than the USB-C? if so raise lidWallHeight.

pcb =
[
  ["Main", pcbLength,pcbWidth, 0,0, pcbThickness, standoffHeight, standoffDiameter, standoffPinDiameter, standoffHoleSlack]
];

paddingFront        = 12;  // screw end: cavity for the SMA bulkhead body so it
                           // clears the M.2 mounting post (at X~78.5) and card edge
paddingBack         = 1;   // M.2 finger end
paddingRight        = 2;
paddingLeft         = 2;

wallThickness       = 1.6;  // 1.8*wt=2.88 -> ridge can be < wall height
basePlaneThickness  = 1.5;
lidPlaneThickness   = 1.5;
baseWallHeight      = 4.5;  // standoff 2.5 + pcb 1 + room; also gives the SMA hole wall margin
lidWallHeight       = 9.0;  // tall front wall so a full Ø6.35 SMA hole clears the ridge + top rounding

//-- SMA bulkhead antenna connector, captured at the base/lid seam (front end) ---------
smaHoleDia          = 7.35;   // was 6.35; enlarged +1.0mm dia to fit the bulkhead thread (test-fit)
smaCentreZ          = 4.0;    // vertically centred in the 16.5mm front face (clears 2mm corner rounding top+bottom)

ridgeHeight         = 3.0;   // >= 1.8*wallThickness(2.88) and < wall height(4.0)
ridgeSlack          = 0.3;
ridgeGap            = 0.5;
roundRadius         = 2.0;
boxType             = 0;
printerLayerHeight  = 0.2;

renderQuality             = 6;
previewQuality            = 5;
showSideBySide            = true;
onLidGap                  = 0;
colorLid                  = "YellowGreen";
alphaLid                  = 1;
colorBase                 = "BurlyWood";
alphaBase                 = 1;
hideLidWalls              = false;
hideBaseWalls             = false;
showOrientation           = true;
showPCB                   = true;    // verify cutout alignment against the board
showSwitches              = false;
showButtonsDepressed      = false;
showMarkersPCB            = true;
showMarkersCenter         = false;
inspectX                  = 0;
inspectY                  = 0;
inspectZ                  = 0;
inspectXfromBack          = true;
inspectYfromLeft          = true;
inspectZfromBottom        = true;

//-- M.2 mounting: finger-end edge slot only (see hooks). The notch-end screw post/stub was
//   REMOVED (test-fit): it sat where the SMA bulkhead body/nut needs to screw in at the front.
pcbStands = [];

connectors   = [];

cutoutsBase = [];
cutoutsLid  = [];

//-- Screw/notch end: SMA bulkhead for the HALOW antenna. The lid dominates the front-face
//   height (base wall is short), so a vertically-centred hole lands in the LID wall; the
//   SMA's own nut clamps it. p(0)=horizontal (centre of pcbWidth), p(1)=height above PCB.
//   yappCoordPCB is the reference YAPP reliably cuts on this face (per the RJ45 case).
cutoutsFront =
[
   [ 11, 4.0, 0, 0, 3.675, yappCircle, yappCenter, yappCoordPCB ]   // SMA Ø7.35 @ y=11, 4.0 above PCB = vertically centred in the front wall
];

//-- M.2 finger end (X=0). Fingers walled off (board used standalone). USB-C exits here,
//   just above the fingers, centre-left of the width. Position along face = Y. --
cutoutsBack  = [];   // finger end walled off; USB-C is on the LEFT long wall (see cutoutsLeft)

//-- Buttons on the LEFT edge (Y=0): ONE long slot covering all 4 buttons (X 43.5..73.5),
//   extended +10mm toward the FINGER end (away from the SMA). Spans X ~31.5..75.5
//   (centre 53.5, length 44 along the wall, 3 tall). --
cutoutsLeft =
[
   [53.5, 0, 44, 3, 0, yappRectangle, yappCenter, yappCoordPCB]   // single button slot, extended toward finger end
];

//-- USB-C at the gold-finger (Back) end, exiting the BACK end face. Drawing shows it
//   just above the fingers, centre-left. [CONFIRM Y-offset + size against the plug] --
cutoutsRight =
[
   [12, 4.25, 19.5, 16, 1.0, yappRoundedRect, yappCenter, yappCoordPCB]   // USB-C: extended +10mm along wall (9.5->19.5) + FULL case height (Z-extent 16, centred) for the plug's plastic surround
];

//-- Snap clips (box coords). LEFT wall clips pulled out to the ENDS so the long button slot
//   (box-X ~34..78) doesn't cut through them; RIGHT wall keeps centre clips (clear of the
//   finger-end USB-C at box-X ~5..24). yappSymmetric mirrors about the box centre.
snapJoins   =
[
   [13, 5, yappLeft,  yappCenter, yappSymmetric]   // LEFT: clips near both ends (~box 13 & 83)
  ,[40, 5, yappRight, yappCenter, yappSymmetric]   // RIGHT: centre clips (~box 40 & 56)
];
boxMounts   = [];
lightTubes  = [];
pushButtons = [];   // switch extenders auto-derive from cutoutsLeft buttons after positions fixed
labelsPlane = [];
ridgeExtLeft = []; ridgeExtRight = []; ridgeExtFront = []; ridgeExtBack = [];
displayMounts = [];

//-- M.2 card-edge slot REMOVED (test-fit): the PCB is now held by double-sided tape against the
//   lid inner surface, so no base ledge/lip that would lift the board. All hooks empty.
module hookLidInside(){}
module hookLidOutside(){}
module hookBaseInside(){}
module hookBaseOutside(){}

YAPPgenerate();
