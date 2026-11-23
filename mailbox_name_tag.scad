// =====================================================
//  Customizable Mailbox Name Tag - Embossed Text
//  Open in OpenSCAD -> Window -> Customizer to edit
// =====================================================

/* [Text] */
// First line (e.g. family name)
line1 = "משפחת נדלר";
// Second line (leave empty for a single line)
line2 = "";
// Font - use any installed font. For Hebrew try "Arial:style=Bold", "David Libre", "Rubik:style=Bold"
font_name = "Liberation Sans:style=Bold";
// Line 1 text height (mm)
line1_size = 9;
// Line 2 text height (mm)
line2_size = 6;
// Space between lines (mm)
line_spacing = 4;
// How far the text rises above the plate (mm)
text_height = 1.2;
// Text direction - "auto" detects Hebrew automatically (כיוון כתב - auto מזהה עברית אוטומטית)
text_direction = "auto"; // [auto, ltr, rtl]
// Shrink text automatically if it is wider than the plate
auto_fit = true;

/* [Plate] */
plate_width = 100;
plate_height = 35;
plate_thickness = 2.5;
// Corner radius (0 = sharp corners)
corner_radius = 5;

/* [Border] */
add_border = true;
border_width = 1.5;
// Gap between plate edge and border (mm)
border_inset = 2;

/* [Mounting] */
// Enable screw mounting holes
add_holes = false;
// Screw shaft diameter (mm)
hole_diameter = 3.5;
// Countersink head diameter (0 = no countersink)
countersink_diameter = 7;
// Hole distance from left/right edge (mm)
hole_edge_offset = 9;

/* [Render] */
// Choose "all" for single-color print, or export plate & text separately for 2-color prints
part = "all"; // [all, plate, text]

/* [Hidden] */
$fn = 64;
eps = 0.01;

// ---------- derived values ----------
has_line2 = len(line2) > 0;
has_holes = add_holes;
// Usable text width - leave room for border and holes
text_area_w = plate_width
              - 2 * (add_border ? border_inset + border_width + 2 : 3)
              - (has_holes ? 2 * (hole_edge_offset + max(hole_diameter, countersink_diameter) / 2) : 0);
text_area_h = plate_height - 2 * (add_border ? border_inset + border_width + 1.5 : 3);

block_h = has_line2 ? line1_size + line_spacing + line2_size : line1_size;
// Vertical scale-down if the text block is too tall
v_fit = auto_fit ? min(1, text_area_h / block_h) : 1;

// ---------- modules ----------
module rounded_rect(w, h, r) {
    r2 = min(r, w / 2 - eps, h / 2 - eps);
    if (r2 <= 0) square([w, h], center = true);
    else offset(r = r2) square([w - 2 * r2, h - 2 * r2], center = true);
}

// --- Hebrew / RTL support (תמיכה בעברית) ---
// Hebrew letters are Unicode U+0590..U+05FF
function is_hebrew_char(c) = ord(c) >= 1424 && ord(c) <= 1535;
function has_hebrew(s, i = 0) =
    i >= len(s) ? false : is_hebrew_char(s[i]) ? true : has_hebrew(s, i + 1);

// In "rtl" mode OpenSCAD lays out every character right-to-left, so numbers
// and English words inside a Hebrew line come out reversed (12 -> 21).
// Pre-reverse each run of non-Hebrew, non-space characters to cancel that.
function is_ltr_char(c) = !is_hebrew_char(c) && c != " ";
function run_end(s, i) = (i < len(s) && is_ltr_char(s[i])) ? run_end(s, i + 1) : i;
function rev_sub(s, a, b) = b <= a ? "" : str(s[b - 1], rev_sub(s, a, b - 1));
function fix_rtl(s, i = 0) =
    i >= len(s) ? "" :
    is_ltr_char(s[i]) ? str(rev_sub(s, i, run_end(s, i)), fix_rtl(s, run_end(s, i)))
                      : str(s[i], fix_rtl(s, i + 1));

// Direction per line: "auto" -> rtl if the line contains any Hebrew letter
function line_dir(s) = text_direction == "auto" ? (has_hebrew(s) ? "rtl" : "ltr")
                                                : text_direction;

module text_line(s, size) {
    d = line_dir(s);
    text(d == "rtl" ? fix_rtl(s) : s,
         size = size, font = font_name,
         halign = "center", valign = "center",
         direction = d);
}

// Shrinks a line proportionally if its estimated width exceeds the text area.
// Estimate: average bold glyph is ~0.7 x font size wide.
module fitted_line(s, size) {
    est_w = len(s) * size * 0.7;
    k = auto_fit ? min(1, text_area_w / max(est_w, eps)) : 1;
    scale([k, k]) text_line(s, size);
}

module text_2d() {
    scale([v_fit, v_fit]) {
        if (has_line2) {
            y1 = block_h / 2 - line1_size / 2;
            y2 = -block_h / 2 + line2_size / 2;
            translate([0, y1]) fitted_line(line1, line1_size);
            translate([0, y2]) fitted_line(line2, line2_size);
        } else {
            fitted_line(line1, line1_size);
        }
    }
}

module border_2d() {
    ow = plate_width - 2 * border_inset;
    oh = plate_height - 2 * border_inset;
    r  = max(corner_radius - border_inset, 0);
    difference() {
        rounded_rect(ow, oh, r);
        rounded_rect(ow - 2 * border_width, oh - 2 * border_width,
                     max(r - border_width, 0));
    }
}

module hole_positions() {
    for (sx = [-1, 1])
        translate([sx * (plate_width / 2 - hole_edge_offset), 0, 0]) children();
}

module mounting_holes() {
    hole_positions() {
        translate([0, 0, -1]) cylinder(d = hole_diameter, h = plate_thickness + 2);
        if (countersink_diameter > hole_diameter) {
            cs_depth = (countersink_diameter - hole_diameter) / 2; // 90° countersink
            translate([0, 0, plate_thickness - cs_depth])
                cylinder(d1 = hole_diameter, d2 = countersink_diameter, h = cs_depth + eps);
            translate([0, 0, plate_thickness])
                cylinder(d = countersink_diameter, h = text_height + 1);
        }
    }
}

module plate() {
    difference() {
        linear_extrude(plate_thickness) rounded_rect(plate_width, plate_height, corner_radius);
        if (has_holes) mounting_holes();
    }
}

module raised() {
    difference() {
        translate([0, 0, plate_thickness - eps])
            linear_extrude(text_height + eps) {
                text_2d();
                if (add_border) border_2d();
            }
        if (has_holes) mounting_holes();
    }
}

// ---------- output ----------
if (part == "all" || part == "plate") color("white") plate();
if (part == "all" || part == "text")  color("navy")  raised();
