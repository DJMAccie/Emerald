-- Voxel world mode

local V = ...

local ModSetting = V.require("ModSetting")
local Sky = V.require("Sky")
local DayNight = V.require("DayNight")
local ShadowMap = V.require("ShadowMap")
local Mat4 = V.require("Mat4")

local Water = {}

Water.KEY = "water"
Water.LABEL = "WATER"

Water.setting = ModSetting.new(Water.KEY, Water.LABEL,
                               { "full", "sky", "off" },
                               { "FULL", "SKY", "OFF" })

function Water.level()
  local v = Water.setting:get()
  if v == "off" then return 0 end
  if v == "sky" then return 1 end
  return 2
end

function Water.enabled()
  return Water.level() > 0
end

Water.FRESNEL_FLOOR = 0.34
Water.FRESNEL_CEIL = 0.92
Water.FRESNEL_POWER = 2.0

Water.LEAN_FROM = 0.30 -- descent where the lean starts: the top rung's
Water.LEAN_FULL = 0.55 -- and where it is complete
Water.LEAN_ELEV = math.asin(Water.LEAN_FROM)

function Water.lean(descent)
  local span = Water.LEAN_FULL - Water.LEAN_FROM
  local t = ((descent or 0) - Water.LEAN_FROM) / span
  if t <= 0 then return 0 end
  return t < 1 and t or 1
end

Water.WAVE_HEIGHT = 5

Water.WAVE_TRAINS = {
  { 0.150, 0.062, 1.60, 0.60 },
  { 0.058, 0.132, -1.05, 0.29 },
  { -0.041, 0.033, 0.55, 0.11 },
}

Water.WAVE_SWELL = { 0.0325, 0.0134, 0.55, 0.35 }

Water.WAVE_BEND = { -0.0138, 0.0333, 0.35, 1.10 }

Water.WAVE_FPS = 12

Water.WAVE_PIXELS_PER_STEP = 1

function Water.waveRate()
  local t = Water.WAVE_TRAINS[1]
  local freq = math.sqrt(t[1] * t[1] + t[2] * t[2])
  local speed = math.abs(t[3])
  if not (freq > 0 and speed > 0) then return 0 end
  return Water.WAVE_PIXELS_PER_STEP * (freq / speed) * Water.WAVE_FPS
end
Water.WAVE_STEPS = 16

Water.WAVE_STRIDE = 1

Water.WAVE_SLOPE = 3.5
Water.WAVE_SLOPE_LEAN = 1.5

Water.CAST_ALPHA = 0.55
Water.CAST_WOBBLE = 0.006

Water.CAST_RAISE = 6

Water.RAY_STEPS = 24
Water.RAY_REFINE = 5 -- halvings once a crossing is found
Water.RAY_STEP = 3.0 -- world pixels in the first step
Water.RAY_GROW = 1.18
Water.RAY_THICK = 1.6
Water.EDGE_FADE = 0.14 -- reflection eased off over this much of the frame

local SHADER_SRC = [[
varying float vShade;
varying vec3 vSun;
// World position, as drawn -- and a varying that cannot ride GLSL ES's
// mediump fragment default: everything below floors it into columns and
// marches it through the frame's matrices, and a route's coordinates run
// to a few thousand, where fp16 has no fraction left at all. The same
// reasoning the scene shader's vGrid states at length.
varying LOVE_HIGHP_OR_MEDIUMP vec3 vBent;

#ifdef VERTEX
uniform mat4 vp;
uniform mat4 model;
uniform mat4 sunVP;
uniform vec3 curve;          // xy = the focus in world XZ, z = k; 0 = off
attribute float VertexShade;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
  vShade = VertexShade;
  vec4 w = model * vertex_position;
  vSun = (sunVP * w).xyz;
  if (curve.z > 0.0) {
    vec2 cd = w.xz - curve.xy;
    w.y -= dot(cd, cd) * curve.z;
  }
  vBent = w.xyz;
  return vp * w;
}
#endif

#ifdef PIXEL
// Everything below works in WORLD units through the frame's own matrices,
// and GLSL ES defaults fragment floats to mediump -- fp16, out of fraction
// by a coordinate of two thousand and quantising a depth into steps the
// march falls straight through. Worse than wrong pictures: `vp` is
// declared by BOTH stages, the vertex side's default is highp, and GLSL ES
// refuses to LINK a uniform whose precision the two stages disagree on --
// which is not broken water but NO water shader at all, the flat fallback
// with nothing in the log. One statement lifts the whole stage; the guard
// keeps the odd GPU without fragment highp compiling, and such a driver
// falls back to flat water exactly as it did before this pass existed.
#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#endif
#endif
uniform mat4 vp;
uniform vec3 eye;
uniform vec3 fogColor;
uniform vec4 fogBounds;
uniform vec3 fogOrigin;
uniform vec4 fogInfo;
uniform vec2 screen;         // the canvas, in pixels
uniform float cell;          // one diorama pixel, in canvas pixels
uniform float pxAngle;       // radians of view one screen pixel subtends
// The same bend the vertex stage applied. This stage has to undo it to get
// back to the flat world it reflects in, and re-apply it on every marched
// sample to get back to the screen. Declared in both stages, like `vp`, and
// both are highp here.
uniform vec3 curve;          // xy = the focus in world XZ, z = k; 0 = off

// How far the bend has pushed the world down at world XZ `q` -- the vertex
// stage's own displacement, as a number this stage can add and subtract.
// Zero when the curve is off, which is the shader's "skip it" everywhere.
float bendDrop(vec2 q) {
  if (curve.z <= 0.0) return 0.0;
  vec2 d = q - curve.xy;
  return dot(d, d) * curve.z;
}

// the sun's own pass, exactly as the scene shader reads it
uniform Image sunMap;
uniform float sunDark;
uniform float sunBias;
uniform vec2 sunTexel;
uniform vec3 dayTint;

// the frame as it stood before the water went down, and its depth. The
// depth sampler is qualified because GLSL ES defaults samplers to LOWP no
// matter what floats are set to, and eight bits of depth is a march with
// nothing to land on. The frame copy is honest 8-bit colour and can stay.
#ifndef SKY_ONLY
uniform Image reflectTex;
uniform LOVE_HIGHP_OR_MEDIUMP Image depthTex;
uniform float rays;          // 0 = sky only, 1 = march the screen too
#endif

// The cast, mirrored in the water plane (Voxel3D.beginCast).
//
// OUTSIDE the SKY_ONLY guard, unlike the march's own buffers: this is a
// texture lookup at a fixed uv, not a walk, so the rung that cannot afford
// to march can still afford to have people in its water.
//
// Declared and bound whatever castOn says: an unbound sampler is a
// driver-dependent crash rather than a fallback, the same reason sunMap is
// always given something.
uniform LOVE_HIGHP_OR_MEDIUMP Image castTex;
uniform float castOn;        // 0 = there is no cast canvas this frame
uniform float castAlpha;
uniform float castWobble;
uniform vec3 lookFlat;       // the way the horizon lies from this camera
uniform float lean;          // and how far the reflection tilts toward it
uniform float leanElev;      // the elevation it aims at, in radians
uniform float waveHeight;    // the tallest column, in whole world pixels
uniform float waveSlope;     // how far a column's neighbours tilt its normal
uniform float waveSlopeLean; // and how far the horizon lean may open that up
uniform float waveT;
uniform vec4 faceShade;      // the mesh's own direction shading: E, W, S, N
uniform vec2 atlasSize;      // the tileset atlas, in texels
uniform float fresnelFloor;
uniform float fresnelCeil;
uniform float fresnelPower;
uniform float rayStep;
uniform float rayGrow;
uniform float rayThick;
uniform float edgeFade;

// the sky, as Sky paints it
uniform Image skyRamp;
uniform float skyCount;
uniform float skyEdge;       // the sky's bottom, in canvas pixels
uniform float skyStart;      // where the checker begins inside a band
uniform float skyOn;         // 0 indoors: there is no sky to reflect

// and what hangs in it
uniform vec3 bodyDir;
uniform float bodyOn;
uniform float bodyMoon;
uniform float bodyAng;       // the disc's angular radius, in radians
uniform vec3 bodyCore;
uniform vec3 bodyMain;
uniform vec3 bodyDark;
uniform float glowAmt;
uniform float glowReach;     // in radians, like bodyAng
uniform vec3 glowColor;

#ifdef VOXEL_GRID
uniform float gridDark;
uniform float gridWidth;
#endif

// ------- the sun's pass (the scene shader's, verbatim)

// One shadow tap: 1 where the sun reaches, 0 where something blocks it --
// EXCEPT that water declines one kind of blocker.
//
// The sun pass marks the cast in the blue channel (ShadowMap.sprites), and
// water ignores those. A character standing at a lake's edge laid a hard
// cut-out of its own sprite across the surface, and on something that is
// already showing the sky, the shoreline and the trees behind it, a
// silhouette of somebody reads as a sticker on the water rather than as a
// shadow in it. Everything the WORLD casts -- trees, buildings, cliffs,
// ledges -- still shades it, which is the half that was worth having.
float sunLit(vec2 uv, float z) {
  vec4 c = Texel(sunMap, uv);
  return max(step(z, c.r + c.g * (1.0 / 255.0)), c.b);
}

float sunlight(vec3 p) {
  if (sunDark <= 0.0) return 1.0;
  if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0 || p.z > 1.0) {
    return 1.0;
  }
  vec2 e = min(p.xy, 1.0 - p.xy);
  float edge = smoothstep(0.0, 0.06, min(e.x, e.y));
  if (edge <= 0.0) return 1.0;
  float z = p.z - sunBias;
  float lit = sunLit(p.xy + sunTexel * vec2(-0.5, -0.5), z)
            + sunLit(p.xy + sunTexel * vec2( 0.5, -0.5), z)
            + sunLit(p.xy + sunTexel * vec2(-0.5,  0.5), z)
            + sunLit(p.xy + sunTexel * vec2( 0.5,  0.5), z);
  return 1.0 - sunDark * edge * (1.0 - lit * 0.25);
}

#ifdef VOXEL_GRID
// The wireframe, ruled on the COLUMNS rather than on the flat sheet they
// stand on.
//
// The scene shader reads a mesh's own model space, and for water that is the
// base plane -- so it would draw a grid across a flat sheet and ignore the
// bars entirely, which is the one thing that would give away that they are
// bars. What has to be outlined is what is actually SEEN: the column the ray
// landed on, at the height it landed at, so every voxel of water reads as
// its own block with its own edges.
//
// `p` is that hit; `base` is the smooth plane under it, and the derivative
// comes from THERE. `p` jumps a whole column between neighbouring fragments,
// so fwidth() of it reports a step rather than a scale and every column edge
// would blow out into a band. The plane underneath is smooth, and is the
// same scale in x and z that the columns are built on.
//
// `axis` is the direction the face does not vary along -- the top's own y,
// or a side's x or z. Its distance to the nearest plane is a constant zero,
// and taken at face value it floods the whole face solid; pushed out of
// reach it simply drops out, exactly as the scene shader's own seam handles
// the axis a face's normal points along.
float columnSeam(vec3 p, vec3 base, float axis) {
  vec3 w = fwidth(base);
  float wide = max(w.x, w.z);
  // the plane has no vertical extent of its own to measure, so y borrows
  // the horizontal scale -- it sets a line's THICKNESS and nothing else
  w.y = wide;
  vec3 d = abs(fract(p + 0.5) - 0.5);
  vec3 px = d / max(w, vec3(1e-6));
  if (axis < 0.5) { px.y += 1e6; }
  else if (axis < 1.5) { px.x += 1e6; }
  else { px.z += 1e6; }
  float near = min(min(px.x, px.y), px.z);
  // Fade out where a column is too small on screen to hold a line at all,
  // or the far water turns into a flat wash of seams rather than a grid.
  //
  // It holds on further than the scene shader's own does. That one is ruling
  // seams across whole 16px walls and roofs; these are one world pixel
  // apart, so the fade starts biting while the water is still perfectly
  // readable -- and at the lowest rung, where the middle distance is most of
  // the frame, it took the grid off nearly all of it. Full lines by a pixel
  // and a half of screen space, gone under three quarters of one.
  float span = 1.0 / max(wide, 1e-6);
  float fade = clamp((span - 0.75) * 1.35, 0.0, 1.0);
  return fade * clamp(gridWidth * 0.5 + 0.5 - near, 0.0, 1.0);
}
#endif

// ------- the sky, by direction

vec3 bandAt(float i) {
  return Texel(skyRamp,
               vec2((clamp(i, 0.0, skyCount - 1.0) + 0.5) / skyCount, 0.5)).rgb;
}

// Where a DIRECTION lands on the sky's own gradient, as a band coordinate
// in [0, count]: 0 is straight overhead, count the horizon.
//
// Measured by putting the direction through the very matrix the frame is
// drawn with, as a point at infinity -- which is how Voxel3D finds both the
// vanishing line and the sun's place on the canvas. So the reflected sky and
// the painted sky are answering the same question with the same arithmetic,
// and they agree at the waterline for free at any pitch, fov or zoom.
//
// A direction whose w comes out negative is BEHIND the camera plane, which
// for an upward reflection means near-vertical: the top band, overhead.
float skyPos(vec3 d) {
  vec4 c = vp * vec4(d, 0.0);
  if (c.w <= 1e-6) return 0.0;
  float py = (c.y / c.w * 0.5 + 0.5) * screen.y;
  float row = floor(py / cell) * cell;
  return clamp(row / max(skyEdge, 1.0), 0.0, 1.0) * skyCount;
}

// `parity` is the diorama checkerboard this fragment sits on -- the same
// one Sky's own dither is cut from, so the reflected gradient breaks up in
// the same 8-bit way rather than being the one smooth thing in the frame.
vec3 skyAt(vec3 d, float parity) {
  float pos = skyPos(d);
  float base = min(floor(pos), skyCount - 1.0);
  vec3 c = bandAt(base);
  if (base < skyCount - 1.0 && (pos - base) > skyStart && parity < 0.5) {
    c = bandAt(base + 1.0);
  }
  return c;
}

float crater(vec2 p, vec2 c, float r) {
  vec2 dd = p - c;
  return step(dot(dd, dd), r * r);
}

// The sun or moon, and the twilight warmth around it, laid over the bands.
//
// By ANGLE, not by screen position: the reflected direction usually
// projects off the top of the frame entirely, where screen distances stop
// meaning anything. bodyAng is Sky.discRadius run back through the camera's
// field of view, so this disc is the same size as the painted one.
vec3 bodyAt(vec3 d, vec3 c, float parity) {
  if (bodyOn <= 0.0) return c;
  float ang = acos(clamp(dot(d, bodyDir), -1.0, 1.0));
  if (glowAmt > 0.0) {
    float g = glowAmt * pow(clamp(1.0 - ang / glowReach, 0.0, 1.0), 2.0);
    float lvl = floor(g * 4.0);
    if (g * 4.0 - lvl > 0.5 && parity < 0.5) { lvl += 1.0; }
    c = mix(c, glowColor, min(lvl / 3.0, 1.0) * 0.65);
  }
  if (ang > bodyAng) return c;
  float t = ang / bodyAng;
  // the dithered rim, exactly as the painted disc keeps one parity of its
  // outer ring of cells
  if (t > 0.86 && parity < 0.5) return c;
  vec3 disc = (t <= 0.5) ? bodyCore : bodyMain;
  if (bodyMoon > 0.5) {
    // disc-local coordinates: a frame built off world up, so the craters
    // sit on the moon the same way round every night
    vec3 t1 = normalize(cross(vec3(0.0, 1.0, 0.0), bodyDir));
    vec2 dc = vec2(dot(d, t1), dot(d, cross(bodyDir, t1))) / bodyAng;
    float k = 0.0;
//@CRATERS
    if (k > 0.0) { disc = bodyDark; }
  }
  return disc;
}

#ifndef SKY_ONLY
// ------- the screen-space march

// A point as (uv, depth, valid), through the very matrix the frame was drawn
// with. The uv and the depth are the same numbers the hardware wrote -- the
// clip-space Y flip is already baked into `vp`, and a canvas texture's v runs
// the same way its pixel rows do, so one 0.5x+0.5 answers for both.
//
// The point arrives in the FLAT world -- the space the ray is straight in --
// and is bent here, by the same displacement the vertex stage applied, so it
// lands exactly where the geometry it is being compared against landed. That
// split is the whole trick: the reflection is worked out in a world that has
// not been tipped, and every sample of it is tipped on the way to the screen,
// so the march reads the depth buffer it actually has.
vec4 project(vec3 p) {
  p.y -= bendDrop(p.xz);
  vec4 c = vp * vec4(p, 1.0);
  if (c.w <= 1e-6) return vec4(0.0, 0.0, 0.0, 0.0);
  return vec4(c.xy / c.w * 0.5 + 0.5, c.z / c.w * 0.5 + 0.5, 1.0);
}

// Walk the reflected ray until it passes behind the depth buffer. Returns
// the colour found in .rgb and how much of it to believe in .a -- 0 for a
// ray that left the frame, ran out of steps, or crossed something it went
// straight through rather than landed on.
vec4 march(vec3 origin, vec3 dir) {
  vec4 miss = vec4(0.0, 0.0, 0.0, 0.0);
  vec3 a = origin;
  vec4 pa = project(a);
  if (pa.w < 0.5) return miss;
  float len = rayStep;
  for (int i = 0; i < RAY_STEPS; i++) {
    vec3 b = a + dir * len;
    vec4 pb = project(b);
    if (pb.w < 0.5) return miss;
    if (pb.x < 0.0 || pb.x > 1.0 || pb.y < 0.0 || pb.y > 1.0) return miss;
    float scene = Texel(depthTex, pb.xy).r;
    if (pb.z > scene) {
      // how much depth this one step covered: the yardstick for whether
      // the crossing is a surface or a thin thing the ray shot past
      float span = max(abs(pb.z - pa.z), 1e-7);
      if (pb.z - scene > span * rayThick) return miss;
      // binary-refine onto the contact
      vec3 lo = a;
      vec3 hi = b;
      for (int k = 0; k < RAY_REFINE; k++) {
        vec3 m = (lo + hi) * 0.5;
        vec4 pm = project(m);
        if (pm.z > Texel(depthTex, pm.xy).r) { hi = m; } else { lo = m; }
      }
      vec4 hit = project(hi);
      if (hit.w < 0.5) return miss;
      // Ease out at the frame's rim, where the reflection is about to run
      // off the only evidence there is -- and with distance travelled, so a
      // long ray hands back to the sky instead of ending on a hard edge.
      //
      // The distance term is doing two jobs. It hides the march's own tail,
      // where the steps are longest and a grazing crossing is least likely
      // to be a real surface -- and it is also true: distant water reflects
      // haze rather than detail, and the haze is what the bands underneath
      // already are. The small floor keeps a genuine far hit as a trace
      // rather than deleting it.
      vec2 e = min(hit.xy, 1.0 - hit.xy);
      float edge = smoothstep(0.0, edgeFade, min(e.x, e.y));
      float far = 1.0 - clamp(float(i) / float(RAY_STEPS), 0.0, 1.0);
      return vec4(Texel(reflectTex, hit.xy).rgb, edge * (0.15 + 0.85 * far));
    }
    a = b;
    pa = pb;
    len *= rayGrow;
  }
  return miss;
}
#endif

// ------- the surface, as a field of pixel-tall columns

// How high the column at world pixel `q` stands, in WHOLE world pixels.
//
// Whole, because that is what makes them BARS: a column is a voxel like
// every other voxel in this mode, one unit on a side, and a surface that
// stepped in fractions would just be a smooth wave with extra arithmetic.
// Three crossing wave trains, so the field has no readable repeat inside a
// lake's worth of pixels.
//
// The SMOOTH surface underneath, 0 to 1 -- the thing the columns are a
// quantisation of. Summed from Water.WAVE_TRAINS, which is where the trains
// and the reasoning behind their weights live; pasted in rather than sent,
// so the speed derived from those same numbers cannot drift from the field
// they describe.
float waveRaw(vec2 q) {
  float h = 0.0;
//@TRAINS
  return h * 0.5 + 0.5;
}

// and the voxel surface: that field, in whole world pixels.
float waveAt(vec2 q) {
  if (waveHeight <= 0.0) return 0.0;
  return floor(waveRaw(q) * waveHeight + 0.5);
}

// The tilt this column reflects with -- taken from the SMOOTH field, not
// from the stepped one, and this is the difference between a moon on the
// water and confetti.
//
// Floored heights are integers, so their differences are integers too: a
// column's neighbours are level with it or a whole pixel off, and nothing in
// between. Build the normal out of THOSE and the reflected ray can only ever
// point in about five directions -- straight up, or rotated by twice the
// arctangent of one step, or of two. A flat sky does not mind; the sun and
// the moon are discs barely two degrees across, and a ray that jumps in
// eighteen-degree increments simply steps over them. The lake goes dark and
// the odd column that happens to land dead on flares -- which is exactly
// what "the moon doesn't reflect right" looks like.
//
// The columns are an approximation of a real surface, and light reflects off
// the surface being approximated. So the SHAPE stays quantised -- it is what
// you see, and it is the whole point -- while the normal is read off the
// smooth field the shape is made from. Still one answer per column, because
// `q` is an integer: pixel-quantised in space, continuous in value, which
// puts the glitter path back without softening a single edge.
//
// Forward differences over one pixel: three samples, and the answer only has
// to say which way this piece of the surface leans.
vec3 waveNormal(vec2 q, float tilt) {
  float h = waveRaw(q);
  float e = waveRaw(q + vec2(1.0, 0.0)) - h;
  float s = waveRaw(q + vec2(0.0, 1.0)) - h;
  return normalize(vec3(-e * tilt, 1.0, -s * tilt));
}

// Walk the view ray down through the wave slab and return the column it
// actually meets -- RELIEF MAPPING, and the whole reason the bars read as
// solid rather than as a pattern painted on a flat sheet.
//
// The mesh is still one flat quad per tile, so what gets rasterised is the
// point where the ray crosses the BASE plane. The visible surface is
// somewhere above that, and the two differ by more the lower the camera
// sits. So the ray is walked BACKWARD to the top of the slab and then
// stepped down: the first column whose top it falls below is what the eye is
// looking at, and everything shorter behind that column is hidden by it for
// free, because the march simply never reaches it.
//
// A step that lands below a column's top having just ARRIVED in that column
// is looking at its side; one that was already there and fell through is
// looking at its top. That is the whole of the face test, and it is what
// gives a crest a lit face and a shaded one.
//
// `axis` names which way the face it found points -- 0 top, 1 east/west, 2
// north/south -- because the wireframe needs to know the one direction the
// face does not vary along (see columnSeam).
void relief(vec3 base, vec3 dir, out vec3 hit, out vec2 col, out float face,
            out float axis) {
  col = floor(base.xz);
  hit = base;
  face = 1.0;
  axis = 0.0;
  float dy = -dir.y;
  // a ray running level along the surface has no slab to walk through, and
  // dividing by its descent would send the start point to infinity
  if (waveHeight <= 0.0 || dy < 0.02) return;
  float across = length(dir.xz);
  float reach = waveHeight / dy;
  // How far across the surface the whole slab displaces the answer. Under
  // half a pixel it cannot pick a different column than the one already
  // under the fragment, so the march would spend its samples arriving where
  // it started -- which is exactly the case at the steep rungs, where the
  // camera looks nearly straight down the columns and there is no side of a
  // bar to see anyway.
  float span = reach * across;
  if (span < 0.5) {
    hit.y = base.y + waveAt(col);
    return;
  }
  // and the other end: `reach` grows as one over the descent, so a grazing
  // ray asks for hundreds of world pixels of march from a fixed number of
  // samples.
  //
  // What one sample is worth is a SCREEN pixel of surface, so that is the
  // stride (see WAVE_STRIDE). A screen pixel covers this much of the water:
  // the distance to the eye times the angle one pixel subtends, opened out
  // by the obliquity -- a surface seen edge-on runs away far faster per
  // pixel than one seen face-on. Floored at a world pixel, because up close
  // a finer stride than the columns themselves buys nothing and skipping
  // them costs everything.
  float dist = length(base - eye);
  float stride = max(WAVE_STRIDE, dist * pxAngle / dy);
  float maxSpan = float(WAVE_STEPS) * stride;
  if (span > maxSpan) { reach = maxSpan / max(across, 1e-4); }
  vec3 top = base - dir * reach;
  vec2 wasCol = floor(top.xz);
  for (int i = 1; i <= WAVE_STEPS; i++) {
    vec3 p = mix(top, base, float(i) / float(WAVE_STEPS));
    vec2 q = floor(p.xz);
    float y = base.y + waveAt(q);
    if (p.y <= y) {
      col = q;
      hit = vec3(p.x, y, p.z);
      vec2 d = q - wasCol;
      if (abs(d.x) + abs(d.y) < 0.5) {
        face = 1.0;                                  // fell through the top
        axis = 0.0;
      } else if (abs(d.x) > abs(d.y)) {
        face = (d.x > 0.0) ? faceShade.y : faceShade.x;   // west : east
        axis = 1.0;
      } else {
        face = (d.y > 0.0) ? faceShade.w : faceShade.z;   // north : south
        axis = 2.0;
      }
      return;
    }
    wasCol = q;
  }
}

// The water's own art, read at the column the ray landed on rather than at
// the fragment's own place on the flat quad -- otherwise the bars parallax
// away and the pixels they are made of stay behind on the plane.
//
// Read off the COLUMN, not off the fragment.
//
// One world pixel is one atlas texel exactly, and the mesher lays a tile's
// eight texels across its eight world pixels -- so the column at world
// (cx, cz) wears texel (cx mod 8, cz mod 8) and nothing else. That makes the
// lookup exact, and far more importantly STABLE: the art a column shows
// depends only on where that column stands in the world, so it cannot swim
// as the camera moves and two fragments that landed on the same column
// cannot disagree about it.
//
// Offsetting the fragment's own uv by the parallax instead makes the art
// depend on how far the march happened to travel -- and wherever the march
// skipped a column, neighbouring fragments picked texels several apart. That
// is what peppered the surface with noise, and why it cleared up in patches:
// the patches are where the march was not skipping.
//
// The tile origin is the FRAGMENT's, so the lookup can never leave the tile
// this quad was built to sample -- the same bleed the mesher's INSET stops.
vec2 waveUV(vec2 tc, vec2 col) {
  vec2 texel = 1.0 / atlasSize;
  vec2 tile = 8.0 * texel;
  vec2 org = floor(tc / tile) * tile;
  return org + (mod(col, 8.0) + 0.5) * texel;
}

// The float parameters are pinned to mediump BECAUSE the stage default is
// not: LOVE's own header forward-declares effect() under its default, and
// at least one mobile compiler (Samsung's Xclipse, in so many words) holds
// that a definition whose parameter precisions differ from its prototype's
// is a second function of the same name, and refuses the pair. The params
// can afford it -- the colour is a colour, and tc/sc arrived through
// LOVE's mediump plumbing whatever this signature says -- and the maths
// below runs on the stage default the moment the values touch a local.
vec4 effect(mediump vec4 color, Image tex, mediump vec2 tc, mediump vec2 sc) {
  // THE DEPTH TEST, done here because the buffer that would have done it is
  // detached for the length of this pass so it can be READ (see the header).
  // Same comparison, same buffer, same result: a building in front of a pond
  // still hides it.
  //
  // Normalised by LOVE's own screen size, not by the `screen` uniform: `sc`
  // arrives in canvas PIXELS, and on a highdpi surface (Android's density
  // is routinely 2.625) a canvas holds that many pixels per canvas UNIT,
  // which is what `screen` counts. Divided by units, uv runs to 2.6 and
  // clamps, and the test reads edge texels for two thirds of the frame --
  // discarding water in blocks and letting the haze backdrop through, which
  // on a phone looked like lakes with pieces missing. love_ScreenSize.xy is
  // the bound canvas's own pixel size, the same units sc is measured in, on
  // every display. (`screen` stays in units: skyPos reads it against cell
  // and skyEdge, which are unit-measured with it.)
  //
  // The buffer now holds THIS SURFACE too (VoxelScene draws the water flat
  // before the pass that reflects it), which is what makes one lake able to
  // hide another -- and it means every fragment here is testing against its
  // own depth. That raises the bar on the fragment's own z: gl_FragCoord is
  // allowed to be MEDIUMP on GLES (and is, on Adreno), and fp16 near the far
  // end of the range steps by about half a thousandth -- which the old test
  // against the terrain far behind the surface never felt, and a comparison
  // of the surface against itself loses outright. Every fragment failed, the
  // pass discarded the whole lake, and Android showed the flat draw
  // underneath. So the depth is recomputed HERE, in highp, from the same
  // vBent and vp the vertex stage used -- full precision on every driver.
  //
  // The slack is sized to what remains after that, which is not rounding:
  // the buffer holds depth interpolated LINEARLY IN SCREEN SPACE, while the
  // recomputation projects the perspective-interpolated vBent -- the exact
  // answer. The two agree at the vertices and drift apart across a quad's
  // interior, by more the bigger the quad stands on screen; on a phone
  // (fit scale 6, water quads hundreds of pixels tall) the drift crosses
  // 1e-5 mid-quad, which discarded the middle of every tile row and looked
  // like flat water with reflective seams. Anything GENUINELY in front of a
  // water pixel is whole world units nearer -- upward of 1e-3 in depth --
  // so 2e-4 clears the drift with room while still catching every occluder.
#ifndef SKY_ONLY
  vec2 uv = sc / love_ScreenSize.xy;
  vec4 selfC = vp * vec4(vBent, 1.0);
  float selfZ = selfC.z / selfC.w * 0.5 + 0.5;
  if (selfZ > Texel(depthTex, uv).r + 2e-4) discard;
#endif

  // THE COLUMN THIS FRAGMENT IS LOOKING AT. Every water pixel is a bar of
  // its own standing a whole number of pixels tall, and the ray decides
  // which one it meets -- so what follows is answered per COLUMN and not per
  // screen pixel: one colour to a bar, at the resolution the water art is
  // drawn at, with no smooth shading anywhere across it. (The depth test
  // above is the one thing that stays per fragment: that is the hardware's
  // own question and it is asked in screen space.)
  //
  // Answered on the FLAT sheet, which is where the bars are a slab of even
  // thickness over a level plane -- the one thing relief() is built on. The
  // bend translates every bar straight down by its own column's drop, so the
  // field keeps its shape and only its height moves; undo that here and the
  // walk is the walk it was written for. Try it in the world as DRAWN
  // instead and the slab is a bowl: the backward step up the ray climbs the
  // bowl's near side as fast as it climbs out of the water, the walk starts
  // inside the sheet, and it hands back a column a pixel or three off -- per
  // fragment, differently, which is a patch of noise rather than parallax.
  vec3 sheet = vec3(vBent.x, vBent.y + bendDrop(vBent.xz), vBent.z);
  vec3 view = normalize(sheet - eye);
  vec3 hit;
  vec2 col;
  float face;
  float axis;
  relief(sheet, view, hit, col, face, axis);
  // and the bar's centre, so a column is sampled and reflected from one
  // place rather than from wherever inside it the fragment happened to land
  vec3 surf = vec3(col.x + 0.5, hit.y, col.y + 0.5);

  vec4 p = Texel(tex, waveUV(tc, col));
  if (p.a < 0.5) discard;
  // `face` is the column's own side shading, which is what makes a crest
  // read as a solid thing with a lit flank rather than as a bright patch
  vec3 base = p.rgb * vShade * face * sunlight(vSun) * dayTint;

  // the reflection follows the WAVES' own shape -- the tilt this column
  // takes from the neighbours it stands beside -- rather than an invented
  // wobble, so the sky and the sun break along the bars instead of across
  // them. Opened up by the lean, which is about to squash it (see below).
  vec3 n = waveNormal(col, waveSlope * (1.0 + lean * waveSlopeLean));
  vec3 r = reflect(view, n);
  // the same reflection off a LEVEL surface, which is what the lean below
  // moves: the difference between the two is this column's own contribution
  vec3 rFlat = reflect(view, vec3(0.0, 1.0, 0.0));
  // The horizon lean (see LEAN_FROM in Water.lua): zero at the rung whose
  // horizon is in frame, so the waterline join is untouched; taking the ray
  // down to the elevation THAT rung reflects at as the camera tips over,
  // where there is no join to break and a straight-up reflection has nothing
  // in it. Applied to the sky, the body AND the march, because the same
  // seventy-five-degree ray that misses the sun also leaves the frame.
  //
  // What is leaned is the LEVEL reflection, with this column's own deflection
  // put back on top afterwards. Leaning the perturbed ray instead sets its
  // elevation outright, which overwrites the very variation the waves are
  // there to provide: at full lean every column on the lake reflects the
  // same elevation, the sky comes out one flat band and the moon -- a disc
  // two degrees wide that the ray now never sweeps past -- vanishes
  // completely. Which is exactly what it did.
  //
  // The ray keeps its own BEARING and is only tipped in elevation, so a
  // reflection still points where the water is pointing it -- and a ray so
  // near vertical that it has no bearing left borrows the camera's.
  if (lean > 0.0) {
    float fl = length(rFlat.xz);
    vec3 bearing = (fl > 1e-3) ? vec3(rFlat.x / fl, 0.0, rFlat.z / fl)
                               : lookFlat;
    float e = mix(asin(clamp(rFlat.y, -1.0, 1.0)), leanElev, lean);
    r = normalize(bearing * cos(e) + vec3(0.0, sin(e), 0.0) + (r - rFlat));
  }

  // The checkerboard the sky's bands and the sunset's glow are dithered on,
  // cut from the WATER's own columns rather than from the screen. Same
  // reasoning the window glint follows in the scene shader: a pattern
  // anchored to the screen has the world sliding through it at zoom speed
  // whenever the camera pans, which strobes. Anchored to the surface,
  // panning moves nothing and only the waves do.
  float parity = mod(col.x + col.y, 2.0);
  vec3 refl = base;
  if (skyOn > 0.5) {
    refl = bodyAt(r, skyAt(r, parity), parity);
  }
#ifndef SKY_ONLY
  if (rays > 0.5) {
    vec4 hit = march(surf, r);
    refl = mix(refl, hit.rgb, hit.a);
  }
#endif

  // Schlick, floored and softened (see FRESNEL_* in Water.lua): the angle
  // still decides, a grazing camera still gets a mirror, and a steep one
  // still gets a pond rather than a flat sticker.
  float ct = clamp(dot(-view, n), 0.0, 1.0);
  float f = fresnelFloor
            + (fresnelCeil - fresnelFloor) * pow(1.0 - ct, fresnelPower);
  vec3 rgb = mix(base, refl, clamp(f, 0.0, 1.0));

  // THE CAST, mirrored in this plane (see CAST_ALPHA). Read at this
  // fragment's own place on the screen, because that is where the mirrored
  // camera has already put it -- nothing here has to work out where a
  // reflection belongs, which is the whole reason this is drawn with a
  // camera rather than by nudging sprites about.
  //
  // The uv is LOVE's own screen size for the same reason the depth test
  // above uses it: `sc` arrives in canvas pixels, and on a highdpi surface
  // that is not the same count as `screen`, which is measured in units.
  //
  // Dragged by the wave normal so a figure ripples with the surface holding
  // it rather than lying flat on top of it, and the canvas's ALPHA decides
  // where there is anything to composite at all.
  if (castOn > 0.5) {
    vec2 cuv = sc / love_ScreenSize.xy + n.xz * castWobble;
    vec4 person = Texel(castTex, cuv);
    rgb = mix(rgb, person.rgb, clamp(person.a * castAlpha, 0.0, 1.0));
  }

#ifdef VOXEL_GRID
  rgb *= 1.0 - gridDark * columnSeam(hit, sheet, axis);
#endif
  if (fogInfo.x > 0.0) {
    float distance = fogInfo.w > 0.5 ? length(hit.xz - fogOrigin.xz) : length(hit - eye);
    if (fogInfo.w > 1.5) {
      vec2 side = mix(fogOrigin.xz - fogBounds.xy,fogBounds.zw - fogOrigin.xz,step(fogOrigin.xz,hit.xz));
      vec2 progress = abs(hit.xz - fogOrigin.xz) / max(side,vec2(1.0));
      distance = max(progress.x,progress.y);
    }
    float haze = (1.0 - exp(-fogInfo.x * max(0.0, distance - fogInfo.y)))
                 * exp(-max(hit.y, 0.0) * fogInfo.z);
    rgb = mix(rgb, fogColor, haze);
  }
  return vec4(rgb, 1.0) * color;
}
#endif
]]

-- Crater list is pasted as source: uniform arrays hit a driver bug.
local function craterSource()
  local out = {}
  for _, c in ipairs(Sky.MOON_CRATERS) do
    out[#out + 1] = ("    k += crater(dc, vec2(%.4f, %.4f), %.4f);")
      :format(c[1], c[2], Sky.CRATER_FRAC)
  end
  return table.concat(out, "\n")
end

Water._craterSource = craterSource -- named for the suite

local function trainSource()
  local out = {}
  for i, t in ipairs(Water.WAVE_TRAINS) do
    if i == 1 then
      local s = Water.WAVE_SWELL
      local b = Water.WAVE_BEND
      out[#out + 1] = (
        "  h += sin(dot(q, vec2(%.4f, %.4f)) + waveT * %.4f\n"
        .. "           + %.4f * sin(dot(q, vec2(%.4f, %.4f)) + waveT * %.4f))\n"
        .. "       * %.4f * (1.0 - %.4f * (0.5 + 0.5 *\n"
        .. "           sin(dot(q, vec2(%.4f, %.4f)) + waveT * %.4f)));")
        :format(t[1], t[2], t[3],
                b[4], b[1], b[2], b[3],
                t[4], s[4], s[1], s[2], s[3])
    else
      out[#out + 1] = ("  h += sin(dot(q, vec2(%.4f, %.4f)) + waveT * %.4f)"
                       .. " * %.4f;"):format(t[1], t[2], t[3], t[4])
    end
  end
  return table.concat(out, "\n")
end

Water._trainSource = trainSource -- named for the suite

local function source(grid, skyOnly)
  local src = SHADER_SRC:gsub("//@CRATERS", (craterSource():gsub("%%", "%%%%")))
  src = src:gsub("//@TRAINS", (trainSource():gsub("%%", "%%%%")))
  local head = ("#define RAY_STEPS %d\n#define RAY_REFINE %d\n"
                .. "#define WAVE_STEPS %d\n#define WAVE_STRIDE %.1f\n")
    :format(Water.RAY_STEPS, Water.RAY_REFINE, Water.WAVE_STEPS,
            Water.WAVE_STRIDE)
  if grid then head = head .. "#define VOXEL_GRID 1\n" end
  if skyOnly then head = head .. "#define SKY_ONLY 1\n" end
  return head .. src
end

Water._source = source -- named for the suite

local shaders = {
  full = { [false] = nil, [true] = nil },
  sky = { [false] = nil, [true] = nil },
}

function Water.shader(grid, skyOnly)
  grid = grid and true or false
  local family = skyOnly and shaders.sky or shaders.full
  if family[grid] == nil then
    if not (love.graphics and love.graphics.newShader) then
      shaders[grid] = false
    else
      local ok, sh = pcall(love.graphics.newShader, source(grid, skyOnly))
      if not ok and V and V.mod and V.mod.log then
        V.mod.log:warn("water shader did not compile: %s -- lakes draw flat",
                       tostring(sh))
      end
      family[grid] = (ok and sh) or false
    end
  end
  return family[grid] or nil
end

local active = nil -- the shader this pass bound, or nil

local function waveTime()
  local ok, frame = pcall(function()
    return V.require("TileClock").animFrame()
  end)
  if not (ok and type(frame) == "number") then return 0 end
  local period = 60 / math.max(1, Water.WAVE_FPS)
  return (math.floor(frame / period) * period / 60) * Water.waveRate()
end

Water._waveTime = waveTime

function Water.begin(ctx, skyOnly)
  if not ctx then return false end
  skyOnly = skyOnly and true or false
  if not skyOnly and not (ctx.reflect and ctx.depth) then return false end
  if skyOnly then
    local ramp, count = Sky.ramp()
    local edge = ctx.skyEdge
    if not (ramp and count and edge and edge > 0) then return false end
  end
  local level = Water.level()
  if level <= 0 then return false end
  local sh = ctx.grid and Water.shader(true, skyOnly) or nil
  if not sh then sh = Water.shader(false, skyOnly) end
  if not sh then return false end

  love.graphics.setShader(sh)
  love.graphics.setColor(1, 1, 1, 1)
  local function send(name, ...)
    pcall(sh.send, sh, name, ...)
  end

  send("vp", "row", ctx.vp)
  send("eye", ctx.eye)
  send("curve", ctx.curve)
  send("screen", { ctx.screen[1], ctx.screen[2] })
  send("cell", math.max(1, ctx.cell or 1))
  send("pxAngle", (ctx.fov or 1) / math.max(1, ctx.screen[2]))
  if not skyOnly then
    send("reflectTex", ctx.reflect)
    send("depthTex", ctx.depth)
  end

  local map = ShadowMap.active()
  send("sunVP", "row", map and ShadowMap.uvVP or Mat4.identity())
  local tex = ShadowMap.texture()
  if not tex then
    tex = ctx.reflect or Sky.ramp()
  end
  if tex then send("sunMap", tex) end
  local Voxel3D = V.require("Voxel3D")
  send("sunDark", map and Voxel3D.SHADOW_ALPHA or 0)
  send("sunBias", ShadowMap.bias)
  local texel = 1 / ShadowMap.res
  send("sunTexel", { texel, texel })
  send("dayTint", Voxel3D.tint or { 1, 1, 1 })
  local fog=Voxel3D.fog
  send("fogColor", fog and fog.color or {0,0,0})
  send("fogBounds", fog and fog.bounds or {0,0,0,0})
  send("fogOrigin", fog and fog.origin or {0,0,0})
  send("fogInfo", fog and {fog.density or 0,fog.start or 0,fog.heightK or 0,fog.bounds and 2 or fog.origin and 1 or 0} or {0,0,0,0})

  local castTex = ctx.cast
  send("castOn", castTex and 1 or 0)
  send("castAlpha", Water.CAST_ALPHA)
  send("castWobble", Water.CAST_WOBBLE)
  local castBound = castTex or ctx.reflect or Sky.ramp()
  if castBound then send("castTex", castBound) end

  if not skyOnly then send("rays", level >= 2 and 1 or 0) end
  send("lookFlat", ctx.lookFlat or { 0, 0, -1 })
  send("lean", Water.lean(ctx.descent))
  send("leanElev", Water.LEAN_ELEV)
  send("waveHeight", Water.WAVE_HEIGHT)
  send("waveSlope", Water.WAVE_SLOPE)
  send("waveSlopeLean", Water.WAVE_SLOPE_LEAN)
  send("waveT", waveTime())
  local fs = Voxel3D.FACE_SHADE
  send("faceShade", { fs[1], fs[2], fs[5], fs[6] }) -- east, west, south, north
  send("fresnelFloor", Water.FRESNEL_FLOOR)
  send("fresnelCeil", Water.FRESNEL_CEIL)
  send("fresnelPower", Water.FRESNEL_POWER)
  send("rayStep", Water.RAY_STEP)
  send("rayGrow", Water.RAY_GROW)
  send("rayThick", Water.RAY_THICK)
  send("edgeFade", Water.EDGE_FADE)
  if ctx.grid then
    local VoxelGrid = V.require("VoxelGrid")
    send("gridDark", VoxelGrid.DARK)
    send("gridWidth", VoxelGrid.width())
  end

  Water.sendSky(sh, ctx)
  active = sh
  return true
end

function Water.sendSky(sh, ctx)
  local function send(name, ...)
    pcall(sh.send, sh, name, ...)
  end
  local ramp, count = Sky.ramp()
  local edge = ctx.skyEdge
  if not (ramp and count and edge and edge > 0) then
    send("skyRamp", ctx.reflect)
    send("skyCount", 1)
    send("skyEdge", 1)
    send("skyStart", 2)
    send("skyOn", 0)
    send("bodyOn", 0)
    send("glowAmt", 0)
    return
  end
  send("skyRamp", ramp)
  send("skyCount", count)
  send("skyEdge", edge)
  send("skyStart", Sky.DITHER and Sky.DITHER_START or 2)
  send("skyOn", 1)

  local replaced = V.companion and V.companion.celestialWasReplaced and V.companion:celestialWasReplaced()
  local body = not replaced and DayNight.body() or nil
  if not body then
    send("bodyOn", 0)
    send("glowAmt", 0)
    return
  end
  local amt, glowColor = DayNight.glow()
  local h = ctx.screen[2]
  local cell = math.max(1, ctx.cell or 1)
  local perRadian = h / math.max(1e-4, ctx.fov or 1)
  local rpx = Sky.discRadius(h, cell,
                             { moon = body.moon, glowAmt = amt })
  local shades = Sky.discShades(body.moon)
  local function shade(i)
    local c = shades[i] or shades[#shades] or { 255, 255, 255 }
    return { c[1] / 255, c[2] / 255, c[3] / 255 }
  end
  local twilight = (amt or 0) > 0.25 and not body.moon
  send("bodyOn", 1)
  send("bodyMoon", body.moon and 1 or 0)
  send("bodyDir", { body.dx, body.dy, body.dz })
  send("bodyAng", rpx / perRadian)
  send("bodyCore", shade(1))
  send("bodyMain", shade(twilight and 3 or 2))
  send("bodyDark", shade(3))
  send("glowAmt", (not body.moon) and (amt or 0) or 0)
  send("glowColor", glowColor
       and { glowColor[1] / 255, glowColor[2] / 255, glowColor[3] / 255 }
       or { 1, 0.88, 0.66 })
  send("glowReach", (ctx.screen[1] * Sky.GLOW_REACH) / perRadian)
end

function Water.draw(mesh, texture, model)
  if not (active and mesh) then return end
  if texture then mesh:setTexture(texture) end
  pcall(active.send, active, "model", "row", model or Mat4.identity())
  if texture and texture.getDimensions then
    local ok, w, h = pcall(texture.getDimensions, texture)
    if ok and w and h then
      pcall(active.send, active, "atlasSize", { w, h })
    end
  end
  love.graphics.draw(mesh)
end

function Water.finish()
  active = nil
end

function Water.invalidate()
  for _, family in pairs(shaders) do
    for k, sh in pairs(family) do
      if sh and sh.release then pcall(sh.release, sh) end
      family[k] = nil
    end
  end
  active = nil
end

return Water
