-- Voxel world mode

local V = ...

local BuildBudget = V.require("BuildBudget")
local Mat4 = V.require("Mat4")
local Voxel = V.require("VoxelState")
local ShadowMap = V.require("ShadowMap")
local Shadows = V.require("Shadows")
local VoxelGrid = V.require("VoxelGrid")
local WorldCurve = V.require("WorldCurve")
local Sky = V.require("Sky")
local DayNight = V.require("DayNight")
local GlassMask = V.require("GlassMask")
local PixelCanvas = V.require("PixelCanvas")

local AtmosphereCamera = V.require("AtmosphereCamera")
local Voxel3D = { canopyFacing = false }

Voxel3D.FORMAT = {
  { "VertexPosition", "float", 3 },
  { "VertexTexCoord", "float", 2 },
  { "VertexShade", "float", 1 },
}

Voxel3D.FACE_SHADE = {
  [1] = 0.84, -- +X east (toward the sun)
  [2] = 0.72, -- -X west (away)
  [3] = 1.00, -- +Y up
  [4] = 0.55, -- -Y down
  [5] = 0.90, -- +Z south (toward the camera, and toward the sun)
  [6] = 0.68, -- -Z north (away)
}

Voxel3D.faceSun = 0

Voxel3D.debugView = nil
Voxel3D.debugOrtho = nil
Voxel3D.debugGround = nil

Voxel3D.TREE_FORMAT = {
  Voxel3D.FORMAT[1],Voxel3D.FORMAT[2],Voxel3D.FORMAT[3],
  {"VertexCanopy","float",3},
}
local battleCutScope
local SHADER = [[
  varying float weatherDistance;
  varying float vShade;
  varying float vFacadeBack;
  varying float vWorldY;      // world height before the curve (debugView depth)
  varying vec3 vSun;          // this fragment's place in the sun's view
  varying vec3 vModelSun;     // optional Stadium model-shadow view
  varying LOVE_HIGHP_OR_MEDIUMP vec3 vFoliageRay;
  varying float vFog;         // distance/height haze from Viridian Forest
#ifdef VOXEL_GRID
  // model space, one unit per voxel -- see VoxelGrid. Precision matters
  // here in a way it does not for a colour: the seam is the FRACTIONAL
  // part of a coordinate that runs to a few thousand across a big route,
  // so a mediump varying would quantise the fraction away entirely.
  varying LOVE_HIGHP_OR_MEDIUMP vec3 vGrid;
#endif
#ifdef VERTEX
]] .. V.require("CanopyBillboard").shader .. [[
  uniform mat4 vp;
  uniform mat4 model;
  uniform mat4 sunModel;      // where the SUN sees this vertex (see below)
  uniform mat4 sunVP;         // world -> the shadow map's unit cube
  uniform mat4 modelSunVP;    // Stadium-local world -> its shadow unit cube
  uniform vec3 modelSunOrigin;// map-world origin of Stadium's local arena
  uniform vec3 eye;
  uniform float pull;
  uniform vec3 curve;         // xy = the focus in world XZ, z = k; 0 = off
  uniform vec4 fogBounds;     // FULL: actual loaded rectangle with scenery margin
  uniform vec3 fogOrigin;     // optional ground-centred distance budget
  uniform vec4 fogInfo;       // density, start, heightK; density 0 = clear
  attribute float VertexShade;
  uniform float breeze;       // seconds; 0 = still air
  vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vertex_position=placedVertex(vertex_position);
    // A light breeze: anchored foliage (grass blades, canopies) leans with
    // a slow sine whose phase comes from the anchor, so neighbouring tufts
    // ripple rather than march. The lean grows with height above the
    // anchor's base, so roots stay planted; plain geometry has no anchor
    // and never moves.
    if (breeze > 0.0 && abs(VertexCanopy.z) > 0.0001) {
      float rise = clamp((vertex_position.y - abs(VertexCanopy.z)) / 6.0, 0.0, 1.0);
      float trunk = VertexCanopy.z < 0.0 ? 0.3 : 1.0;
      float phase = VertexCanopy.x * 0.37 + VertexCanopy.y * 0.23;
      float gust = 0.7 + 0.3 * sin(breeze * 0.43 + phase * 0.11);
      vertex_position.x += sin(breeze * 1.9 + phase) * 0.45 * rise * trunk * gust;
      vertex_position.z += cos(breeze * 1.3 + phase * 0.7) * 0.2 * rise * trunk * gust;
    }
    vShade = abs(VertexShade);
#ifdef VOXEL_GRID
    // MODEL space, deliberately: every mesh here is built a unit per
    // voxel in its own frame, so the seams ride the model however it is
    // posed rather than the world's grid sliding across a leaning sprite
    vGrid = vertex_position.xyz;
#endif
    vec4 w = faceCanopy(model,vertex_position,eye);
    vFoliageRay = w.xyz - eye;
    vWorldY = w.y;
    weatherDistance = max(0.0, length(w.xyz-eye)-300.0);
    // All four vertices of a marked facade lie on one Z plane, so this is
    // constant across its fragments. Work it out here where `eye` belongs;
    // the pixel stage only needs the yes/no result.
    vFacadeBack = step(VertexShade, -0.0001) * step(eye.z, w.z - 0.0001);
    // The shadow lookup runs off `sunModel`, not `model`. For terrain the
    // two are the same matrix, but a character is drawn as a slab LEANING
    // back by the camera's pitch -- a trick played on the viewer, which
    // the sun never saw: it lit the upright card. Looking up with the
    // leaned position asks whether the sun reached a place the figure is
    // not, and since the lean tips the body north and shadows now fall
    // north, every sprite's own card fell across its front. Looking up
    // with the card's position asks the question the sun actually
    // answered. (The pull below is excluded for the same reason: it is a
    // depth trick aimed at the camera's own buffer.)
    vSun = (sunVP * faceCanopy(sunModel,vertex_position,eye)).xyz;
    // Stadium owns and completes its live model shadow map before requesting
    // our environment. Translate this map-world receiver into Stadium's
    // arena-local coordinates and sample that finished map as a second light
    // layer; no cross-mod render-target or shader handoff is required.
    vModelSun = (modelSunVP * vec4(w.xyz - modelSunOrigin, 1.0)).xyz;
    // Work out haze on the flat world, before the optional presentation
    // curve.  Viridian's fog therefore stays planted in the map instead of
    // bending with the camera trick.
    vFog = 0.0;
    if (fogInfo.x > 0.0) {
      float fogDistance = fogInfo.w > 0.5 ? length(w.xz - fogOrigin.xz) : length(w.xyz - eye);
      if (fogInfo.w > 1.5) {
        vec2 side = mix(fogOrigin.xz - fogBounds.xy, fogBounds.zw - fogOrigin.xz, step(fogOrigin.xz,w.xz));
        vec2 progress = abs(w.xz - fogOrigin.xz) / max(side,vec2(1.0));
        fogDistance = max(progress.x,progress.y);
      }
      float fogRun = max(0.0, fogDistance - fogInfo.y);
      vFog = (1.0 - exp(-fogInfo.x * fogRun))
             * exp(-max(w.y, 0.0) * fogInfo.z);
    }
    // The curved world (see WorldCurve): drop every vertex by the square
    // of how far its column stands from the camera's focus. Applied AFTER
    // the shadow lookup above and clear of the wireframe's model space, so
    // both are worked out on the flat world and the bend carries them
    // along -- which is why neither has to know this exists. Along Y only,
    // so a column moves as one piece: the world tips away and the
    // buildings standing on it stay upright.
    if (curve.z > 0.0) {
      vec2 cd = w.xz - curve.xy;
      w.y -= dot(cd, cd) * curve.z;
    }
    // camera-ward pull: move the vertex along ITS OWN ray to the eye.
    // This is a pure depth bias -- the projection of a point moved along
    // its eye ray is bit-identical, so there is no screen drift at all.
    // (An earlier CPU version translated along the central view axis,
    // which preserved only the screen centre and made off-centre sprites
    // and grass swim against the ground while the camera scrolled.)
    if (pull > 0.0) {
      w.xyz += normalize(eye - w.xyz) * pull;
    }
    vec4 clip=vp*w;
    // Overlapping cards in a static tree row can be exactly coplanar.
    // A stable anchor-based depth tie-break leaves their geometry/feet intact.
    if (VertexCanopy.z > 0.0001) {
      float layer=fract(dot(VertexCanopy.xy,vec2(0.1031,0.11369)));
      clip.z-=(0.25+layer)*0.000001*clip.w;
    }
    return clip;
  }
#endif
#ifdef PIXEL
  uniform Image sunMap;
  uniform float sunDark;      // how far into black a shadow goes; 0 = off
  uniform float sunBias;
  uniform vec2 sunTexel;
  uniform float crystalLight;
  uniform float faceSun;      // 0..1: real-sun lighting for side faces (Voxel3D.faceSun)
  uniform float faceSunDraw;  // 0 for draws that keep the baked shade (faceSunNow)
  uniform float debugView;    // 0 normal, 1 clay, 2 depth, 3 art (Voxel3D.debugView)
  uniform float debugGround;  // the player's ground height; depth is measured from it
  uniform vec3 sunTravel;     // the direction the sun's light travels, normalized
  uniform Image modelSunMap;
  uniform float modelSunDark;
  uniform float modelSunBias;
  uniform vec2 modelSunTexel;

  // the two-channel pack ShadowMap writes: high byte, then low
  float sunDepth(vec2 uv) {
    vec4 c = Texel(sunMap, uv);
    // Soft scenery uses extra acne bias, but thin actor casters were already
    // snugged to the foot plane. Applying it again detaches their shadows.
    return c.r + c.g * (1.0 / 255.0) - step(0.5,c.b)*sunBias*crystalLight*0.7;
  }

  // 1.0 in full sun, 1.0 - sunDark in full shadow. Four taps half a texel
  // out on the diagonals: a 2x2 box filter, which is what turns the
  // shadow map's texel staircase into a one-pixel soft edge.
  float receiverTap(vec3 p,float z,vec2 offset,vec2 slope) {
    vec2 uv=(floor((p.xy+offset)/sunTexel)+vec2(0.5))*sunTexel;
    return step(z+dot(slope,uv-p.xy),sunDepth(uv));
  }
  // The shadow term at a given darkness. sunlight() is this with the hour's
  // darkness; the shape-view clay asks for its own fixed darkness instead.
  float sunlightAt(vec3 p, float dark) {
    // Correct each PCF tap to the receiving plane. Camera-facing leaves
    // can graze the sun at slopes far beyond the old fixed roof allowance.
    vec3 dx=dFdx(p),dy=dFdy(p);
    float det=dx.x*dy.y-dx.y*dy.x;
    vec2 slope=abs(det)>0.0000000001 ? vec2(dx.z*dy.y-dx.y*dy.z,dx.x*dy.z-dx.z*dy.x)/det : vec2(0.0);
    slope=clamp(slope,vec2(-32.0),vec2(32.0));
    // outside the sun's frustum nothing was recorded, so nothing occludes
    if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0 || p.z > 1.0) {
      return 1.0;
    }
    // Ease the shadows off at the frustum's rim. The map covers the ground
    // the camera can see out to a cap, and past the low rungs -- 75 degrees
    // especially -- the horizon is further than any box worth paying for.
    // Without this the covered region simply ENDS, drawing a hard line
    // across the middle distance where every shadow stops at once; with it
    // the far field just loses them, which reads as distance.
    vec2 e = min(p.xy, 1.0 - p.xy);
    float edge = smoothstep(0.0, 0.06, min(e.x, e.y));
    if (edge <= 0.0) return 1.0;
    float z = p.z - sunBias * (1.0 + crystalLight * 0.7);
    if (crystalLight > 0.5) {
      // A compact tent filter softens the sun's edge while keeping a dark
      // contact centre. No screen-space blur touches the sprites or UI.
      float sum = 0.0;
      for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
          float weight = (x == 0 ? 2.0 : 1.0) * (y == 0 ? 2.0 : 1.0);
          sum += weight * receiverTap(p,z,sunTexel*vec2(float(x),float(y)),slope);
        }
      }
      return 1.0 - dark * edge * (1.0 - sum / 16.0);
    }
    float lit = receiverTap(p,z,sunTexel*vec2(-0.5, -0.5),slope)
              + receiverTap(p,z,sunTexel*vec2( 0.5, -0.5),slope)
              + receiverTap(p,z,sunTexel*vec2(-0.5,  0.5),slope)
              + receiverTap(p,z,sunTexel*vec2( 0.5,  0.5),slope);
    return 1.0 - dark * edge * (1.0 - lit * 0.25);
  }

  float sunlight(vec3 p) {
    if (sunDark <= 0.0) return 1.0;
    return sunlightAt(p, sunDark);
  }

  float modelSunDepth(vec2 uv) {
    vec4 c = Texel(modelSunMap, uv);
    return c.r + c.g * (1.0 / 255.0);
  }

  float modelSunlight(vec3 p) {
    if (modelSunDark <= 0.0) return 1.0;
    if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0 || p.z > 1.0) {
      return 1.0;
    }
    float z = p.z - modelSunBias;
    float lit = step(z, modelSunDepth(p.xy + modelSunTexel * vec2(-0.5, -0.5)))
              + step(z, modelSunDepth(p.xy + modelSunTexel * vec2( 0.5, -0.5)))
              + step(z, modelSunDepth(p.xy + modelSunTexel * vec2(-0.5,  0.5)))
              + step(z, modelSunDepth(p.xy + modelSunTexel * vec2( 0.5,  0.5)));
    return 1.0 - modelSunDark * (1.0 - lit * 0.25);
  }

#ifdef VOXEL_GRID
  uniform float gridDark;     // how far toward black a seam pulls; 0 = off
  uniform float gridWidth;    // seam width, in display pixels

  // How much of this fragment a voxel seam covers, 0 to 1.
  float voxelSeam(vec3 p) {
    // how much of `p` this fragment spans on screen, per axis: the
    // conversion from model units to display pixels, measured rather than
    // derived, so it holds under any camera pitch or zoom
    vec3 w = fwidth(p);
    vec3 d = abs(fract(p + 0.5) - 0.5);      // distance to the nearest plane
    // The axis a face does not vary along is that face's own normal, and
    // its distance is a constant zero -- take it at face value and every
    // face floods solid. Push those axes out of reach instead of dividing
    // by their zero.
    vec3 live = step(1e-4, w);
    vec3 px = d / max(w, vec3(1e-6)) + (1.0 - live) * 1e6;
    float near = min(min(px.x, px.y), px.z);
    // Fade out where a voxel is too small to hold a line. Survey zoom
    // draws a world pixel at about a display pixel, and a wall seen nearly
    // edge-on squashes one to nothing at any zoom -- either way the seams
    // land closer together than they are wide, and drawn anyway they stop
    // being a wireframe and become a flat 45% dimming of the whole scene.
    // The tightest axis decides, which is the honest test of whether the
    // grid can be resolved at all.
    float span = 1.0 / max(max(w.x, max(w.y, w.z)), 1e-6);
    float fade = clamp((span - 2.0) * 0.5, 0.0, 1.0);
    // the textbook antialiased line: solid within the half-width, fading
    // over the one pixel outside it
    return fade * clamp(gridWidth * 0.5 + 0.5 - near, 0.0, 1.0);
  }
#endif

  uniform vec3 ghostColor;    // the flat silhouette colour
  uniform float ghost;        // 0 = shade normally, 1 = flatten to it
  uniform float effectSurface; // scoped translucent VFX; zero for normal world
  uniform float surfaceDetail; // optional native scenery grain, never UI/actors
  uniform float nearCut;       // first person: tree crowns open within this radius of the eye (0 = off)
  uniform float lightOn;      // 1 = scene lighting, 0 = texture true-colour
  uniform float weatherHaze;
  uniform vec3 weatherHazeColor;
  uniform vec3 weatherMul;
  uniform vec3 weatherAdd;
  uniform vec3 dayTint;       // the hour's light on the world; 1,1,1 = noon
  uniform vec3 fogColor;      // what the active map haze is made of
  uniform Image glassMask;    // opaque where the atlas texel is window glass
  uniform vec2 glassSize;     // the mask's dimensions: tc -> atlas texels
  // TEST75: camera-relative, unshadowed local breath illumination.
  uniform vec4 fireLightA;
  uniform vec4 fireLightB;
  uniform float fireLightPower;
  float breathLight() {
    vec3 segment=fireLightB.xyz-fireLightA.xyz;
    float along=clamp(dot(vFoliageRay-fireLightA.xyz,segment)/max(dot(segment,segment),0.001),0.0,1.0);
    vec3 delta=vFoliageRay-mix(fireLightA.xyz,fireLightB.xyz,along);
    float radius=mix(fireLightA.w,fireLightB.w,along);
    float f=max(0.0,1.0-length(delta)/max(radius,0.001));
    return f*f*fireLightPower;
  }
  uniform float interiorOn;
  uniform float interiorCut;
  uniform vec4 interiorBounds; // x/z bounds relative to the camera eye
  uniform float interiorFloor;
  uniform float streetLampOn;
  uniform vec3 streetLampA;
  uniform vec3 streetLampB;
  uniform vec3 streetLampC;
  uniform vec3 streetLampD;
  float streetPool(vec3 center) {
    vec3 d=vFoliageRay-center;
    float falloff=max(0.0,1.0-length(d.xz)/19.0);
    return falloff*falloff*(1.0-smoothstep(0.5,5.0,abs(d.y)));
  }
  uniform float glassNight;   // 0 = daylight .. 1 = the lamps are on
  uniform float glassPhase;   // the glint's phase: advances with TRAVEL
  uniform float glassGlint;   // and its strength: 0 while standing still
  uniform float glassOn;      // 0 for sprite-sheet draws (see Voxel3D.glass)

  // BATTLE-FOLIAGE1: used only for explicitly scoped tree mesh draws.
  uniform float foliageCutOn;
  uniform vec3 foliageTargetA; // camera-relative, matching vFoliageRay
  uniform vec3 foliageTargetB;
  uniform float foliageRadius;
  float foliageOpening(vec3 ray, vec3 target) {
    float length2 = dot(target, target);
    if (length2 < 1.0) return 0.0;
    float t = dot(ray, target) / length2;
    // Never cut scenery behind the subject, or behind the camera.
    if (t <= 0.0 || t >= 1.0) return 0.0;
    float width = 3.0 + foliageRadius * t;
    float offAxis = length(ray - target * t) / width;
    float edge = 1.0 - smoothstep(0.68, 1.0, offAxis);
    return edge * (1.0 - smoothstep(0.88, 1.0, t));
  }
  float foliageThreshold(vec2 pixel) {
    // Stable ordered coverage: only the soft rim is stippled. The centre
    // is fully clear even through many overlapping leaf cards; no blend
    // sorting or transparent geometry writing depth over the Pokemon.
    vec2 p = mod(floor(pixel), 4.0);
    vec2 lo = mod(p, 2.0);
    vec2 hi = floor(p / 2.0);
    float a = 2.0 * lo.x + 3.0 * lo.y - 4.0 * lo.x * lo.y;
    float b = 2.0 * hi.x + 3.0 * hi.y - 4.0 * hi.x * hi.y;
    return (4.0 * a + b + 0.5) / 16.0;
  }
]] .. V.require("BattleOcclusion").shader .. [[
  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    if (interiorCut > 0.5 && (vFoliageRay.x < interiorBounds.x+0.03 || vFoliageRay.z < interiorBounds.y+0.03
      || vFoliageRay.x > interiorBounds.z-0.03 || vFoliageRay.z > interiorBounds.w-0.03)) discard;
    if (battleCutOn > 0.5 && vFoliageRay.y > battleCutFloor
        && (battleBlocked(vFoliageRay,battleCutA) || battleBlocked(vFoliageRay,battleCutB))) discard;
    if (foliageCutOn > 0.5) {
      float opening = max(foliageOpening(vFoliageRay, foliageTargetA),
                          foliageOpening(vFoliageRay, foliageTargetB));
      if (opening > foliageThreshold(sc)) discard;
    }
    // First person: the eye can stand under (or in) a tree crown that overhangs a walkable cell.
    // The crown opens round the eye - clear inside 85% of the radius, stippled out to its rim -
    // instead of filling the lens with leaves; the trunk's foot below the eye stays.
    if (nearCut > 0.5 && vFoliageRay.y > -6.0) {
      float nd = length(vFoliageRay);
      if (nd < nearCut && smoothstep(nearCut * 0.85, nearCut, nd) < foliageThreshold(sc)) discard;
    }

    // Enterable overworld buildings carry their south/front skin as a
    // one-sided surface. During a door transition the camera can briefly
    // stand north of that skin; discard its back instead of filling the
    // lens with mirrored facade/door art. Genuine rear and side walls keep
    // ordinary positive shade values and remain double-sided.
    if (vFacadeBack > 0.5) discard;
    vec4 p = Texel(tex, tc);
    if (surfaceDetail > 0.5 && debugView < 2.5) {
      vec3 cell=floor(vFoliageRay.xyz*2.0);
      float grain=fract(sin(dot(cell,vec3(12.9898,78.233,37.719)))*43758.5453)-0.5;
      float fade=1.0/(1.0+length(fwidth(vFoliageRay.xyz))*2.0);
      p.rgb*=1.0+grain*0.06*fade;
    }
    // Effects carry continuous coverage, independently of their emissive RGB.
    // Keep this ahead of the world sprite cutout and all scene illumination.
    if (effectSurface > 0.5) return p * color;
    // sprite sheets key GB OBJ color 0 to alpha 0; discarding rather than
    // blending keeps those texels out of the depth buffer, so a model never
    // carves a transparent hole out of whatever stands behind it
    if (p.a < 0.5) discard;
    // UNLIT is an exact texture pass, not merely a zero-weight blend with
    // the lit result. Some GLSL drivers still evaluate both sides of mix(),
    // including the shadow lookup, and have shown pieces of that result on
    // battle cards even when lightOn was zero. Returning here guarantees an
    // UNLIT card cannot receive face light, the day tint, voxel seams, glass
    // or any cast/self shadow.
    if (lightOn < 0.5) {
      return vec4(mix(p.rgb, ghostColor, ghost), 1.0) * color;
    }
#ifdef UNLIT_ONLY
    // A separately compiled card shader. Unlike a uniform branch in the
    // scene shader, this program contains no live day/shadow calculation for
    // a driver to evaluate or fold incorrectly. Ghost remains for hit flashes.
    return vec4(mix(p.rgb, ghostColor, ghost), 1.0) * color;
#endif
    // Shape views (Voxel3D.debugView). Only lit world geometry reaches here.
    // Cut-outs were already discarded above, so their outline is kept.
    // art: the texel exactly as stored (no grain, no vertex colour, no light)
    if (debugView > 2.5) return vec4(p.rgb, 1.0);
    if (debugView > 0.5) {
      if (debugView < 1.5) {
        // clay: the face's own direction against a fixed key light from the
        // upper left-front; tops full, sides 0.8 toward the light, 0.45 away
        vec3 cn = cross(dFdx(vFoliageRay), dFdy(vFoliageRay));
        float cnn = dot(cn, cn);
        vec3 dn = cnn > 1e-20 ? cn * inversesqrt(cnn) : vec3(0.0, 1.0, 0.0);
        if (dot(dn, vFoliageRay) > 0.0) dn = -dn;
        float topF = smoothstep(0.85, 0.95, dn.y);
        float toKey = dot(dn, normalize(vec3(-0.6, 0.0, 0.8)));
        float sideF = mix(0.30, 0.70, smoothstep(-0.5, 0.5, toKey));
        float clayShade = mix(sideF, 0.92, topF);
        // cast shadow at a fixed 45% darkness, whatever the hour
        float castShadow = sunlightAt(vSun, 0.45);
        // higher ground lightens a little, so levels separate
        float relC = vWorldY - debugGround;
        float tint = mix(0.80, 1.0, clamp(relC / 96.0, 0.0, 1.0));
        return vec4(vec3(clayShade * castShadow * tint), 1.0);
      }
      // depth: grey by height relative to the player's ground. -64 px black,
      // the player's floor mid-dark (0.4), +96 px white, linear. A darker
      // line every 16 px and a thicker one at the player's own floor
      // (relY = 0), on standing faces only: a level floor lies wholly on
      // its own line and would otherwise turn solid dark.
      float relY = vWorldY - debugGround;
      float g = clamp((relY + 64.0) / 160.0, 0.0, 1.0);
      float slope = step(0.02, fwidth(vWorldY));
      float lw = max(0.5, fwidth(vWorldY));
      float dl = min(fract(relY / 16.0), 1.0 - fract(relY / 16.0)) * 16.0;
      float ln = 1.0 - smoothstep(0.5 * lw, lw, dl);
      float w0 = max(1.5, 1.5 * fwidth(vWorldY));
      float z0 = 1.0 - smoothstep(0.5 * w0, w0, abs(relY));
      return vec4(vec3(g * (1.0 - 0.45 * ln * slope) * (1.0 - 0.5 * z0 * slope)), 1.0);
    }
    // the hour's tint multiplies like the sun terms do: it is LIGHT, the
    // same warm or moonlit cast on every surface, not a palette swap
    float sun = sunlight(vSun);
    // Cool skylight remains in the shade; a shadow need not erase the
    // material colour. Day/night tint still applies to the complete result.
    vec3 sunFill = mix(vec3(sun), vec3(sun) + (1.0-sun)*vec3(0.20,0.30,0.40), crystalLight);
    float faceLight = mix(vShade, max(vShade, 0.64), crystalLight);
    // Sun-facing light for world geometry. The face normal comes from screen
    // derivatives of the eye-relative position (flat per triangle, so no
    // speckle inside a face). glassOn, faceSunDraw and interiorOn gate it:
    // sprite-sheet passes, faceSunNow(false) draws and interiors keep the
    // baked shade. Top faces keep their current brightness.
    float sunAmt = faceSun * glassOn * faceSunDraw * (1.0 - step(0.5, interiorOn));
    if (sunAmt > 0.0) {
      vec3 nc = cross(dFdx(vFoliageRay), dFdy(vFoliageRay));
      float nn = dot(nc, nc);
      if (nn > 1e-20) {
        vec3 fn = nc * inversesqrt(nn);
        if (dot(fn, vFoliageRay) > 0.0) fn = -fn;   // face the eye
        float side = 1.0 - smoothstep(0.85, 0.95, fn.y);
        float h = dot(fn, -sunTravel);              // -1..1, 1 = facing the sun
        float sunFace = mix(0.64, 1.0, smoothstep(-0.25, 0.85, h));
        faceLight = mix(faceLight, mix(faceLight, sunFace, side), sunAmt);
      }
    }
    vec3 litRgb = p.rgb * faceLight * sunFill
                * modelSunlight(vModelSun) * dayTint;
    vec3 rgb = litRgb;
    if (interiorOn > 0.5) {
      vec2 edge=min(vFoliageRay.xz-interiorBounds.xy,interiorBounds.zw-vFoliageRay.xz);
      float ground=1.0-smoothstep(0.0,14.0,vFoliageRay.y-interiorFloor);
      float contact=(1.0-smoothstep(0.0,12.0,max(0.0,min(edge.x,edge.y))))*ground;
      // Broad indirect fill, soft perimeter contact, and warm side-window
      // light. Pixel artwork stays sharp; only the illumination is smooth.
      rgb=mix(rgb,p.rgb*faceLight*vec3(0.88,0.86,0.80),0.24);
      rgb*=1.0-0.22*contact;
      float side=1.0-smoothstep(0.0,55.0,max(0.0,edge.x));
      rgb+=p.rgb*vec3(0.15,0.105,0.045)*side;
    }
    if (fireLightPower > 0.001) {
      rgb += p.rgb * vec3(1.65,0.90,0.23) * breathLight();
    }
    if (streetLampOn > 0.001) {
      float pool=min(1.0,streetPool(streetLampA)+streetPool(streetLampB)
        +streetPool(streetLampC)+streetPool(streetLampD));
      rgb += p.rgb * vec3(0.65,0.42,0.17) * pool * streetLampOn;
    }
#ifdef VOXEL_GRID
    // darken what is there rather than painting a colour, so a seam across
    // dark grass and one across a white roof each stay in their own palette
    rgb *= 1.0 - gridDark * voxelSeam(vGrid);
#endif
    // WINDOW GLASS, marked per atlas texel by the mask (see GlassMask).
    // By day a thin diagonal glint crosses the panes WHILE THE VIEW MOVES
    // -- the phase is fed by the camera's own travel and the strength dies
    // within a beat of standing still, because a reflection is something
    // the viewpoint does: still camera, still glass. It lifts the texel
    // toward sky-white and leaves the art visible through it. After dark
    // the pane is LIT: the texel's own shine pattern carried into a warm
    // lamp colour, replacing the shaded answer above -- so a lit window
    // ignores the sun, every shadow and the hour's tint, exactly as a
    // window with a lamp behind it does.
    // glassOn gates the whole thing per DRAW: the mask is shaped like the
    // tileset atlas, and only meshes textured FROM that atlas may consult
    // it -- a character samples its own sprite sheet, whose coordinates
    // land on the mask's pane rectangles by accident and would stripe the
    // cast with lamplight at night.
    float glass = Texel(glassMask, tc).a * glassOn;
    if (glass > 0.0) {
      // the sweep lives in the PANE's own space (atlas texels), not the
      // screen's: a pattern anchored to the screen has the world sliding
      // through it at zoom speed whenever the camera pans, which strobed --
      // worst where the pan and the phase ran opposite ways. Anchored to
      // the glass, panning moves nothing; only the phase does, a fraction
      // of a texel per step, the same in every walking direction.
      float sweep = sin(tc.x * glassSize.x * 0.8 - glassPhase);
      float glint = pow(max(sweep, 0.0), 20.0) * 0.55 * glassGlint;
      vec3 pane = mix(rgb, vec3(0.93, 0.97, 1.0), glint * glass);
      float shine = dot(p.rgb, vec3(0.299, 0.587, 0.114));
      vec3 lamp = vec3(1.0, 0.84, 0.5) * (0.5 + 0.55 * shine);
      rgb = mix(pane, lamp, glassNight * glass);
    }
    // Haze is air between the camera and the finished surface, so it lands
    // after lighting, shadows, seams and glass but before the ghost overlay.
    rgb = mix(rgb, fogColor, vFog);
    // The hidden player is a SHAPE, not a dimmed picture of itself. Tinting
    // through `color` could only multiply the sprite's own pixels, which
    // darkens each one by its own amount and keeps the character's internal
    // detail; replacing the colour outright is what makes it read as one
    // solid silhouette. Last in the chain, so neither the sun nor a voxel
    // seam can mottle it.
    rgb = clamp(rgb * weatherMul + weatherAdd, 0.0, 1.0);
    rgb = mix(rgb, weatherHazeColor, min(0.28, 1.0-exp(-weatherHaze*weatherDistance)));
    rgb = mix(rgb, ghostColor, ghost);
    return vec4(rgb, 1.0) * color;
  }
#endif
]]

local shaders = { [false] = nil, [true] = nil }
local unlitShader = nil -- nil = untried, false = unavailable
local backdropShader = nil -- optional soft focus for low-res flat plates
local effectLightOn = 1
local activeShader = nil -- the shader draws are currently sent to
local sceneShader = nil -- the lit variant this pass opened with
local drawUniforms = V.require('DrawUniforms').new()
Voxel3D.breeze = true -- foliage sway (see the vertex shader)
local flattenColor = nil -- tightly scoped hit-flash state for shader swaps
local flattenAmount = 0

local slots = {}
local canvas, canvasW, canvasH = nil, 0, 0 -- the slot this pass bound
local held = nil -- and the whole record for it
local active = false

local DEPTH_FORMATS = { "depth24", "depth24stencil8", "depth32f", "depth16" }

local function newDepth(w, h)
  if not (love.graphics and love.graphics.newCanvas) then return nil end
  local c = nil
  for _, format in ipairs(DEPTH_FORMATS) do
    local ok, made = PixelCanvas.new(w, h,
                                     { format = format, readable = true })
    if ok and made then c = made break end
  end
  if not c then return nil end
  pcall(c.setFilter, c, "nearest", "nearest")
  pcall(c.setWrap, c, "clamp", "clamp")
  pcall(c.setDepthSampleMode, c)
  return c
end

local function depthTarget()
  if held and held.depth then
    return { held.canvas, depthstencil = held.depth }
  end
  return { canvas, depth = true }
end

local function releaseSlot(slotHeld)
  for _, key in ipairs({ "canvas", "depth", "mirror", "cast" }) do
    local obj = slotHeld[key]
    if obj and obj.release then pcall(obj.release, obj) end
    slotHeld[key] = nil
  end
end

local IDENTITY = Mat4.identity()

local function derivativesOK()
  if not (love.graphics and love.graphics.getSupported) then return false end
  local ok, caps = pcall(love.graphics.getSupported)
  return ok and caps and caps.shaderderivatives == true
end

function Voxel3D.shader(grid)
  grid = grid and true or false
  if shaders[grid] == nil then
    if grid and not derivativesOK() then
      shaders[grid] = false
    else
      local src = grid and ("#define VOXEL_GRID 1\n" .. SHADER) or SHADER
      local ok, sh = pcall(love.graphics.newShader, src)
      shaders[grid] = ok and sh or false
    end
  end
  return shaders[grid] or nil
end

function Voxel3D.unlitShader()
  if unlitShader == nil then
    local ok, sh = pcall(love.graphics.newShader,
                         "#define UNLIT_ONLY 1\n" .. SHADER)
    unlitShader = ok and sh or false
  end
  return unlitShader or nil
end

local BACKDROP_BLUR = [[
  uniform vec2 texel;
  uniform float radius;

  vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec4 clip = transform_projection * vertex_position;
    clip.z = clip.w;
    return clip;
  }

  vec4 effect(vec4 color, Image image, vec2 uv, vec2 screen) {
    vec2 d = texel * radius;
    vec4 sum = Texel(image, uv) * 4.0;
    sum += Texel(image, uv + vec2( d.x, 0.0)) * 2.0;
    sum += Texel(image, uv + vec2(-d.x, 0.0)) * 2.0;
    sum += Texel(image, uv + vec2(0.0,  d.y)) * 2.0;
    sum += Texel(image, uv + vec2(0.0, -d.y)) * 2.0;
    sum += Texel(image, uv + vec2( d.x,  d.y));
    sum += Texel(image, uv + vec2(-d.x,  d.y));
    sum += Texel(image, uv + vec2( d.x, -d.y));
    sum += Texel(image, uv + vec2(-d.x, -d.y));
    return color * (sum / 16.0);
  }
]]

Voxel3D.BACKDROP_BLUR_RADIUS = 0.70

function Voxel3D.backdropShader()
  if backdropShader == nil then
    local ok, sh = pcall(love.graphics.newShader, BACKDROP_BLUR)
    backdropShader = ok and sh or false
  end
  return backdropShader or nil
end

-- LOVE 12's Metal path flips Image texture coords; love.system is unavailable to mods.
function Voxel3D.metalRenderer()
  if not (love and love.getVersion) then return false end
  local versionOK, major = pcall(love.getVersion)
  if not versionOK or type(major) ~= "number" or major < 12 then
    return false
  end
  if not (love and love.graphics and love.graphics.getRendererInfo) then
    return false
  end
  local ok, name, version, vendor, device =
    pcall(love.graphics.getRendererInfo)
  if not ok then return false end
  local info = table.concat({ tostring(name), tostring(version),
                              tostring(vendor), tostring(device) }, " "):lower()
  return info:find("metal", 1, true) ~= nil
      or (info:find("apple", 1, true) ~= nil
          and info:find("opengl es", 1, true) ~= nil)
end

function Voxel3D.available()
  if not (love.graphics and love.graphics.newCanvas
          and love.graphics.setDepthMode) then
    return false
  end
  return Voxel3D.shader() ~= nil
end

function Voxel3D.newMesh(verts, map, format)
  if #verts == 0 then return nil end
  local P=Voxel3D.probe
  if P then
    local n,ax,ay,az=0,0,0,0
    local b={1e9,-1e9,1e9,-1e9,1e9,-1e9,1e9,-1e9,1e9,-1e9}
    for _,v in ipairs(verts) do if v[1]>=P[1] and v[1]<=P[2] and v[3]>=P[3] and v[3]<=P[4] and v[2]>=P[5] then n=n+1;ax,ay,az=ax+v[1],ay+v[2],az+v[3]
      for k=1,5 do b[k*2-1]=math.min(b[k*2-1],v[k]);b[k*2]=math.max(b[k*2],v[k]) end end end
    if n>0 then print('[EM probe]',n,'of',#verts,'centre',math.floor(ax/n),math.floor(ay/n),math.floor(az/n),'x',b[1],b[2],'y',b[3],b[4],'z',b[5],b[6],'u',b[7],b[8],'v',b[9],b[10],'fmt',tostring(format)) end
  end
  BuildBudget.check()
  if not format and verts[1][9] then format=Voxel3D.TREE_FORMAT end
  if format==Voxel3D.TREE_FORMAT then
    for _,v in ipairs(verts) do v[7],v[8],v[9]=v[7] or 0,v[8] or 0,v[9] or 0 end
  end
  local ok, mesh = pcall(love.graphics.newMesh, format or Voxel3D.FORMAT, verts,
                         "triangles", "static")
  if not ok then return nil, tostring(mesh) end
  if map and #map > 0 then
    local indexed,err=pcall(mesh.setVertexMap,mesh,map)
    if not indexed then mesh:release();return nil,tostring(err) end
  end
  return mesh
end

Voxel3D.FACE_CORNERS = {
  [1] = { { 1, 0, 0 }, { 1, 0, 1 }, { 1, 1, 1 }, { 1, 1, 0 } }, -- +X
  [2] = { { 0, 0, 1 }, { 0, 0, 0 }, { 0, 1, 0 }, { 0, 1, 1 } }, -- -X
  [3] = { { 0, 1, 0 }, { 1, 1, 0 }, { 1, 1, 1 }, { 0, 1, 1 } }, -- +Y
  [4] = { { 0, 0, 1 }, { 1, 0, 1 }, { 1, 0, 0 }, { 0, 0, 0 } }, -- -Y
  [5] = { { 0, 0, 1 }, { 1, 0, 1 }, { 1, 1, 1 }, { 0, 1, 1 } }, -- +Z
  [6] = { { 1, 0, 0 }, { 0, 0, 0 }, { 0, 1, 0 }, { 1, 1, 0 } }, -- -Z
}

-- n is 0-based.

Voxel3D.camera = nil

Voxel3D.companionCameraDelta = nil

local function finiteDelta(value)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then
    return 0
  end
  return value
end

local function normalize3(value, fallback)
  local x, y, z = value[1] or 0, value[2] or 0, value[3] or 0
  local length = math.sqrt(x * x + y * y + z * z)
  if length < 1e-6 then return fallback[1], fallback[2], fallback[3] end
  return x / length, y / length, z / length
end

local function cross3(ax, ay, az, bx, by, bz)
  return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

local function rotateAxis(x, y, z, ax, ay, az, angle)
  if math.abs(angle) < 1e-9 then return x, y, z end
  local c, s = math.cos(angle), math.sin(angle)
  local dot = x * ax + y * ay + z * az
  local cx, cy, cz = cross3(ax, ay, az, x, y, z)
  return x * c + cx * s + ax * dot * (1 - c),
         y * c + cy * s + ay * dot * (1 - c),
         z * c + cz * s + az * dot * (1 - c)
end

local function cameraWithDelta(camera)
  local delta = Voxel3D.companionCameraDelta
  if not delta then return camera end
  local eye, focus = camera.eye, camera.focus
  if not (type(eye) == "table" and type(focus) == "table") then return camera end
  local px, py, pz = delta.positionDelta.x, delta.positionDelta.y,
    delta.positionDelta.z
  local ex, ey, ez = eye[1] + px, eye[2] + py, eye[3] + pz
  local dx, dy, dz = focus[1] - eye[1], focus[2] - eye[2], focus[3] - eye[3]
  local distance = math.max(1e-3, math.sqrt(dx * dx + dy * dy + dz * dz))
  dx, dy, dz = dx / distance, dy / distance, dz / distance

  local rotation = delta.rotationDelta
  dx, dy, dz = rotateAxis(dx, dy, dz, 0, 1, 0, rotation.yaw)
  local rx, ry, rz = cross3(dx, dy, dz, 0, 1, 0)
  rx, ry, rz = normalize3({ rx, ry, rz }, { 1, 0, 0 })
  local baseUp = camera.up or { 0, 1, 0 }
  local ux, uy, uz = normalize3(baseUp, { 0, 1, 0 })
  dx, dy, dz = rotateAxis(dx, dy, dz, rx, ry, rz, rotation.pitch)
  ux, uy, uz = rotateAxis(ux, uy, uz, rx, ry, rz, rotation.pitch)

  ux, uy, uz = rotateAxis(ux, uy, uz, dx, dy, dz, rotation.roll)

  local baseFov = finiteDelta(camera.fov)
  if baseFov <= 0 then baseFov = math.rad(65) end
  local fovDelta = delta.fovDelta
  local fov = math.max(math.rad(20), math.min(math.rad(120),
    baseFov + math.max(-math.rad(30),
      math.min(math.rad(30), fovDelta))))
  return {
    eye = { ex, ey, ez },
    focus = { ex + dx * distance, ey + dy * distance, ez + dz * distance },
    up = { ux, uy, uz },
    fov = fov,
    curve = camera.curve,
  }
end

Voxel3D.lookFlat = { 0, 0, -1 }
Voxel3D.descent = 0

local function setLook(eye, focus)
  local dx = focus[1] - eye[1]
  local dy = focus[2] - eye[2]
  local dz = focus[3] - eye[3]
  local len = math.sqrt(dx * dx + dy * dy + dz * dz)
  if len < 1e-6 then return end
  Voxel3D.descent = math.max(0, math.min(1, -dy / len))
  local flat = math.sqrt(dx * dx + dz * dz)
  if flat < 1e-6 then return end
  Voxel3D.lookFlat = { dx / flat, 0, dz / flat }
end

function Voxel3D.viewProjection(cx, cy, vw, vh, pw, ph)
  Voxel3D.atmosphereCameraCandidate=nil
  local o = Voxel3D.debugOrtho
  if o then
    local scale = o.scale or 2
    local ox, oy, oz = o.x or 0, o.y or 0, o.z or 0
    local D = 2000
    local eye, focus = { ox, oy + D, oz + D }, { ox, oy, oz }
    Voxel3D.eye, Voxel3D.focus = eye, focus
    setLook(eye, focus)
    local hw = (pw or vw) / (2 * scale)
    local hh = (ph or vh) / (2 * scale) * 0.70710678
    local proj = Mat4.ortho(-hw, hw, -hh, hh, 1, 3 * D)
    proj = Mat4.mul(Mat4.scale(1, -1, 1), proj)
    return Mat4.mul(proj, Mat4.lookAt(eye, focus, { 0, 1, 0 }))
  end
  local cam = Voxel3D.camera
  local externalEye=cam and (cam.view or cam.proj or cam.eyeIndex~=nil or cam.stereo==true)
  local cameraMode=Voxel.isFirstPerson() and 'first_person' or (Voxel.isThirdPerson() and 'third_person' or 'diorama')
  if cam then
    cam = cameraWithDelta(cam)
    local eye, focus = cam.eye, cam.focus
    Voxel3D.eye = eye
    Voxel3D.focus = focus
    setLook(eye, focus)
    local dx = eye[1] - focus[1]
    local dy = eye[2] - focus[2]
    local dz = eye[3] - focus[3]
    local dist = math.max(1, math.sqrt(dx * dx + dy * dy + dz * dz))
    Voxel3D.fovY = cam.fov
    local proj = Mat4.perspective(cam.fov, vw / vh,
                                  math.max(1, dist * 0.05), dist * 4 + 4096)
    proj = Mat4.mul(Mat4.scale(1, -1, 1), proj)
    if not externalEye then Voxel3D.atmosphereCameraCandidate=AtmosphereCamera.build(eye,focus,cam.up or {0,1,0},math.max(1,dist*.05),dist*4+4096,cam.fov,cameraMode) end
    return Mat4.mul(proj, Mat4.lookAt(eye, focus, cam.up or { 0, 1, 0 }))
  end

  local a = Voxel.angle
  local focal = Voxel.FOCAL
  local depthStyle=false
  local okDepth,depth=pcall(function()
    if V.require("Generation").isGen3() then return true end
    local game=require("src.core.Game")
    return V.require("CommunityVisuals").crystalDepth(game.world and game.world.map)
  end)
  depthStyle=okDepth and depth
  local dist = focal * vh * (depthStyle and 1.18 or 1)
  local fov = 2 * math.atan(1 / (2 * focal))
  Voxel3D.fovY = fov

  local ground=Voxel3D.orbitGround or 0
  local focus = { cx, ground, cy }
  local eye = { cx, ground + dist * math.cos(a), cy + dist * math.sin(a) }
  Voxel3D.eye = eye
  Voxel3D.focus = focus
  setLook(eye, focus)
  local up = { 0, math.sin(a), -math.cos(a) }

  local proj = Mat4.perspective(fov, vw / vh,
                                math.max(1, dist * 0.05), dist * 4 + 4096)
  proj = Mat4.mul(Mat4.scale(1, -1, 1), proj)
  Voxel3D.atmosphereCameraCandidate=AtmosphereCamera.build(eye,focus,up,math.max(1,dist*.05),dist*4+4096,fov,cameraMode)
  return Mat4.mul(proj, Mat4.lookAt(eye, focus, up))
end

function Voxel3D.horizonY(h)
  local m, eye, focus = Voxel3D.vp, Voxel3D.eye, Voxel3D.focus
  if not (m and eye and focus and h and h > 0) then return nil end
  local dx = focus[1] - eye[1]
  local dz = focus[3] - eye[3]
  local len = math.sqrt(dx * dx + dz * dz)
  if len < 1e-6 then return nil end
  dx, dz = dx / len, dz / len
  local y = m[5] * dx + m[7] * dz
  local w = m[13] * dx + m[15] * dz
  if w <= 1e-6 then return nil end
  return (y / w * 0.5 + 0.5) * h
end

Voxel3D.tint = { 1, 1, 1 }

Voxel3D.glassMask = nil
Voxel3D.glassNight = 0

Voxel3D.glassPhase = 0
Voxel3D.glassGlint = 0

Voxel3D.fog = nil

function Voxel3D.skyBody(w, h)
  local m = Voxel3D.vp
  local b = m and DayNight.body()
  if not b then return nil end
  local x = m[1] * b.dx + m[2] * b.dy + m[3] * b.dz
  local y = m[5] * b.dx + m[6] * b.dy + m[7] * b.dz
  local ww = m[13] * b.dx + m[14] * b.dy + m[15] * b.dz
  if ww <= 1e-6 then return nil end
  local amt, color = DayNight.glow()
  return {
    x = (x / ww * 0.5 + 0.5) * w,
    y = (y / ww * 0.5 + 0.5) * h,
    moon = b.moon,
    glowAmt = amt,
    glowColor = color,
  }
end

-- Returns false when the pass could not start: then do not call endScene.
function Voxel3D.beginScene(w, h, cx, cy, vw, vh, sky, slot, modelShadow, borrowed)
  drawUniforms.reset()
  Voxel3D.atmosphereCameraCandidate=nil
  Sky.resetDeferredBody()
  Sky.allowDeferredBody = not borrowed and sky and sky.bands ~= nil
  local grid = VoxelGrid.enabled()
  local sh = grid and Voxel3D.shader(true) or nil
  if not sh then
    grid, sh = false, Voxel3D.shader()
  end
  if not sh then return false end
  -- Hosted passes borrow bound targets: never allocate, clear or release them.
  if borrowed then
    canvas, canvasW, canvasH = borrowed.color, w, h
  else
    local name = slot or "world"
    local slotHeld = slots[name]
    if not (slotHeld and slotHeld.w == w and slotHeld.h == h) then
      local ok, c = PixelCanvas.new(w, h)
      if not ok then return false end
      c:setFilter("nearest", "nearest")
      if slotHeld then releaseSlot(slotHeld) end
      slotHeld = { canvas = c, w = w, h = h, depth = newDepth(w, h) }
      slots[name] = slotHeld
    end
    held = slotHeld
    canvas, canvasW, canvasH = held.canvas, w, h
    local ok = pcall(love.graphics.setCanvas, depthTarget())
    if not ok and held.depth then
      pcall(held.depth.release, held.depth)
      held.depth = nil
      ok = pcall(love.graphics.setCanvas, depthTarget())
    end
    if not ok then
      pcall(love.graphics.setCanvas)
      return false
    end
  end
  Voxel3D.vp = borrowed and borrowed.vp or Voxel3D.viewProjection(cx, cy, vw, vh, w, h)
  Voxel3D.cell = w / math.max(1, vw or w)
  Voxel3D.skyEdge = (sky and sky.bands)
                    and Sky.region(h, Voxel3D.horizonY(h)) or nil
  if borrowed then
  elseif sky then
    love.graphics.clear(sky[1], sky[2], sky[3], sky[4] or 1, true, true)
    Sky.paint(w, h, sky, Voxel3D.horizonY(h), Voxel3D.cell,
              sky.bands and Voxel3D.skyBody(w, h) or nil)
  else
    love.graphics.clear(0, 0, 0, 0, true, true)
  end
  love.graphics.setDepthMode("lequal", true)
  love.graphics.setMeshCullMode("none")
  love.graphics.setShader(sh)
  love.graphics.setColor(1, 1, 1, 1)
  pcall(sh.send, sh, "vp", "row", Voxel3D.vp)
  pcall(sh.send, sh, "eye", Voxel3D.eye)
  local map = not borrowed and ShadowMap.active()
  pcall(sh.send, sh, "sunVP", "row", map and ShadowMap.uvVP or IDENTITY)
  local tex = ShadowMap.texture()
  if tex then pcall(sh.send, sh, "sunMap", tex) end
  pcall(sh.send, sh, "sunDark", map and Voxel3D.SHADOW_ALPHA or 0)
  local hdOK,hd=pcall(function()
    if V.require("Generation").isGen3() then return true end
    local game=require("src.core.Game")
    return game.world and V.require("CommunityVisuals").crystalHD(game.world.map)
  end)
  pcall(sh.send,sh,"crystalLight",hdOK and hd and 1 or 0)
  pcall(sh.send, sh, "faceSun", Voxel3D.faceSun or 0)
  pcall(sh.send, sh, "faceSunDraw", 1)
  pcall(sh.send, sh, "debugView",
    Voxel3D.debugView == "clay" and 1 or Voxel3D.debugView == "depth" and 2
    or Voxel3D.debugView == "art" and 3 or 0)
  pcall(sh.send, sh, "debugGround", Voxel3D.debugGround or 0)
  local okSun, travel = pcall(ShadowMap.sunDir)
  if okSun and travel then pcall(sh.send, sh, "sunTravel", travel) end
  pcall(sh.send, sh, "sunBias", ShadowMap.bias)
  local texel = 1 / ShadowMap.res
  pcall(sh.send, sh, "sunTexel", { texel, texel })
  local external = type(modelShadow) == "table" and modelShadow or nil
  pcall(sh.send, sh, "modelSunVP", "row",
    external and external.sunVP or IDENTITY)
  pcall(sh.send, sh, "modelSunOrigin",
    external and external.origin or { 0, 0, 0 })
  if external and external.map then
    pcall(sh.send, sh, "modelSunMap", external.map)
  elseif tex then
    pcall(sh.send, sh, "modelSunMap", tex)
  end
  pcall(sh.send, sh, "modelSunDark",
    external and not Shadows.off() and (tonumber(external.sunDark) or 0) or 0)
  pcall(sh.send, sh, "modelSunBias",
    external and (tonumber(external.sunBias) or 0) or 0)
  pcall(sh.send, sh, "modelSunTexel",
    external and external.sunTexel or { 1, 1 })
  if grid then
    pcall(sh.send, sh, "gridDark", VoxelGrid.DARK)
    pcall(sh.send, sh, "gridWidth", VoxelGrid.width())
  end
  pcall(sh.send, sh, "ghost", 0)
  pcall(sh.send, sh, "ghostColor", Voxel3D.GHOST_COLOR)
  flattenColor, flattenAmount = nil, 0
  effectLightOn = 1
  pcall(sh.send, sh, "effectSurface", 0)
  pcall(sh.send, sh, "lightOn", 1)
  pcall(sh.send, sh, "dayTint", Voxel3D.tint or { 1, 1, 1 })
  local weather = (not borrowed and sky and V.companion and V.companion.atmosphereSnapshot)
    and V.companion:atmosphereSnapshot() or {}
  pcall(sh.send, sh, "weatherHaze", weather.haze and weather.haze.density or 0)
  pcall(sh.send, sh, "weatherHazeColor", weather.haze and weather.haze.color or {0,0,0})
  pcall(sh.send, sh, "weatherMul", weather.tint and weather.tint.multiplier or {1,1,1})
  pcall(sh.send, sh, "weatherAdd", weather.tint and weather.tint.additive or {0,0,0})
  local fog = Voxel3D.fog
  pcall(sh.send, sh, "fogColor", (fog and fog.color) or { 0, 0, 0 })
  pcall(sh.send, sh, "fogBounds", (fog and fog.bounds) or {0,0,0,0})
  pcall(sh.send, sh, "fogOrigin", (fog and fog.origin) or {0,0,0})
  pcall(sh.send, sh, "fogInfo", fog and
        { fog.density or 0, fog.start or 0, fog.heightK or 0, fog.bounds and 2 or fog.origin and 1 or 0 }
        or { 0, 0, 0, 0 })
  local mask = Voxel3D.glassMask or GlassMask.blank()
  if mask then
    pcall(sh.send, sh, "glassMask", mask)
    local ok, mw, mh = pcall(mask.getDimensions, mask)
    pcall(sh.send, sh, "glassSize", { ok and mw or 1, ok and mh or 1 })
  end
  pcall(sh.send, sh, "glassNight", Voxel3D.glassNight or 0)
  local fire=slot=="battle" and Voxel3D.battleFireLight or nil
  local fireEye=Voxel3D.eye or {0,0,0}
  pcall(sh.send,sh,"fireLightPower",fire and fire.strength or 0)
  for _,item in ipairs({{"fireLightA",fire and fire.a},{"fireLightB",fire and fire.b}}) do
    local p=item[2]
    pcall(sh.send,sh,item[1],p and {p[1]-fireEye[1],p[2]-fireEye[2],p[3]-fireEye[3],p[4]} or {0,0,0,1})
  end
  local room=Voxel3D.interior
  pcall(sh.send,sh,"interiorOn",room and 1 or 0)
  pcall(sh.send,sh,"interiorCut",room and 1 or 0)
  if room then
    local b,e=room.bounds,Voxel3D.eye
    pcall(sh.send,sh,"interiorBounds",{b[1]-e[1],b[2]-e[3],b[3]-e[1],b[4]-e[3]})
    pcall(sh.send,sh,"interiorFloor",-e[2])
  end
  local lamps=Voxel3D.streetLamps
  pcall(sh.send,sh,"streetLampOn",lamps and (Voxel3D.glassNight or 0) or 0)
  if lamps then
    for i,name in ipairs({"streetLampA","streetLampB","streetLampC","streetLampD"}) do
      local p=lamps[i];local e=Voxel3D.eye or {0,0,0}
      pcall(sh.send,sh,name,{p[1]-e[1],p[2]-e[2],p[3]-e[3]})
    end
  end
  pcall(sh.send, sh, "glassPhase", Voxel3D.glassPhase or 0)
  pcall(sh.send, sh, "glassGlint", Voxel3D.glassGlint or 0)
  pcall(sh.send, sh, "glassOn", 1)
  local placed = Voxel3D.camera
  Voxel3D.curveK = Voxel3D.debugOrtho and 0 or (placed and placed.curve) or WorldCurve.k(vh)
  Voxel3D.curveX, Voxel3D.curveZ = cx, cy
  pcall(sh.send, sh, "curve", { cx, cy, Voxel3D.curveK })
  local m = Voxel3D.vp
  Voxel3D.focusW = m[13] * cx + m[14] * 0 + m[15] * cy + m[16]
  sceneShader = sh
  activeShader = sh
  battleCutScope=nil
  pcall(sh.send, sh, "battleCutOn", 0)
  pcall(sh.send, sh, "foliageCutOn", 0)
  active = true
  return true
end

function Voxel3D.depth(mode)
  if not active then return end
  pcall(love.graphics.setDepthMode, mode == "always" and "always" or "lequal",
        true)
end

Voxel3D.GHOST_COLOR = { 0.26, 0.26, 0.28 }
Voxel3D.GHOST_ALPHA = 0.5

function Voxel3D.flatten(color, amount)
  if not (active and activeShader) then return end
  local sh = activeShader
  if color then
    flattenColor = color
    flattenAmount = math.max(0, math.min(1, amount or 1))
    pcall(sh.send, sh, "ghostColor", flattenColor)
    pcall(sh.send, sh, "ghost", flattenAmount)
  else
    flattenColor, flattenAmount = nil, 0
    pcall(sh.send, sh, "ghost", 0)
  end
end

function Voxel3D.beginWater(paint)
  if not (active and canvas and held and held.depth) then return nil end
  if not held.mirror then
    local ok, c = PixelCanvas.new(held.w, held.h)
    if not (ok and c) then return nil end
    pcall(c.setFilter, c, "nearest", "nearest")
    pcall(c.setWrap, c, "clamp", "clamp")
    held.mirror = c
  end
  love.graphics.setShader()
  local ok = pcall(love.graphics.setCanvas,
                   { held.mirror, depthstencil = held.depth })
  if not ok then
    pcall(love.graphics.setCanvas, depthTarget())
    return nil
  end
  love.graphics.setDepthMode("always", false)
  love.graphics.clear(0, 0, 0, 0, false, false)
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas)
  love.graphics.setBlendMode("alpha")
  if paint and activeShader then
    love.graphics.setDepthMode("lequal", false)
    love.graphics.setShader(activeShader)
    pcall(paint)
    love.graphics.setShader()
  end
  love.graphics.setDepthMode()
  if not pcall(love.graphics.setCanvas, canvas) then
    pcall(love.graphics.setCanvas, depthTarget())
    return nil
  end
  return held.mirror, held.depth
end

function Voxel3D.beginCast()
  if not (active and canvas and held) then return nil end
  if not held.cast then
    local ok, c = PixelCanvas.new(held.w, held.h)
    if not (ok and c) then return nil end
    pcall(c.setFilter, c, "nearest", "nearest")
    pcall(c.setWrap, c, "clamp", "clamp")
    held.cast = c
  end
  if not pcall(love.graphics.setCanvas, held.cast) then
    pcall(love.graphics.setCanvas, depthTarget())
    return nil
  end
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setDepthMode("always", false)
  return held.cast
end

function Voxel3D.endCast()
  if not active then return end
  pcall(love.graphics.setCanvas, depthTarget())
  pcall(love.graphics.setDepthMode, "lequal", true)
  love.graphics.setColor(1, 1, 1, 1)
end

function Voxel3D.endWater()
  if not active then return end
  pcall(love.graphics.setCanvas, depthTarget())
  pcall(love.graphics.setDepthMode, "lequal", true)
  love.graphics.setColor(1, 1, 1, 1)
  if activeShader then love.graphics.setShader(activeShader) end
end

function Voxel3D.depthReadable()
  return (active and held and held.depth) and true or false
end

function Voxel3D.seams(on)
  if not (active and activeShader) then return end
  pcall(activeShader.send, activeShader, "gridDark",
        on and VoxelGrid.DARK or 0)
end

function Voxel3D.blend(mode)
  if not active then return end
  if mode == "add" then
    pcall(love.graphics.setBlendMode, "add", "alphamultiply")
    pcall(love.graphics.setDepthMode, "lequal", false)
  else
    pcall(love.graphics.setBlendMode, "alpha", "alphamultiply")
    pcall(love.graphics.setDepthMode, "lequal", true)
  end
end

local effectScopeShader
function Voxel3D.withEffect(mode, draw)
  if not (active and activeShader) then return false end
  assert(mode == "alpha" or mode == "add", "invalid effect blend mode")
  local g = love.graphics
  local previousShader, previousScope = activeShader, effectScopeShader
  local previousLight = effectLightOn
  g.push("all")
  local usedShader
  local ok, err = pcall(function()
    Voxel3D.lighting(false)
    usedShader = activeShader
    usedShader:send("effectSurface", 1)
    effectScopeShader = usedShader
    g.setBlendMode(mode, "alphamultiply")
    g.setDepthMode("lequal", false)
    if g.setMeshCullMode then g.setMeshCullMode("none") end
    draw()
  end)
  if usedShader then
    pcall(usedShader.send, usedShader, "effectSurface", previousScope == usedShader and 1 or 0)
  end
  effectScopeShader = previousScope
  activeShader = previousShader
  effectLightOn = previousLight
  if previousShader then pcall(previousShader.send, previousShader, "lightOn", previousLight) end
  g.pop()
  if not ok then error(err, 0) end
  return true
end

function Voxel3D.glassMaskNow(mask)
  Voxel3D.glassMask=mask
  if not (active and activeShader) then return end
  local m=mask or GlassMask.blank()
  if m then pcall(activeShader.send,activeShader,"glassMask",m); local ok,w,h=pcall(m.getDimensions,m); pcall(activeShader.send,activeShader,"glassSize",{ok and w or 1,ok and h or 1}) end
end

function Voxel3D.glass(on)
  if not (active and activeShader) then return end
  pcall(activeShader.send, activeShader, "glassOn", on and 1 or 0)
end

Voxel3D.SHADOW_KX = ShadowMap.KX -- west drift per pixel of height
Voxel3D.SHADOW_KZ = ShadowMap.KZ -- north drift per pixel of height
Voxel3D.SHADOW_EPS = 0.25 -- float above the ground to dodge z-fighting
Voxel3D.SHADOW_ALPHA = 0.40 -- how far into black a shadowed surface goes

function Voxel3D.draw(mesh, texture, model, pull, sunModel)
  if not (active and mesh) then return end
  local Instances=V.require('ModelInstances')
  local batch=mesh;mesh=Instances.mesh(mesh)
  local sh = activeShader
  if not sh then return end
  drawUniforms.send(sh,"surfaceDetail",Voxel3D.surfaceDetail and 1 or 0)
  drawUniforms.send(sh,"nearCut",Voxel3D.nearCut or 0)
  drawUniforms.send(sh,"canopyFacing",Voxel3D.canopyFacing and 1 or 0)
  drawUniforms.send(sh,"battleCutOn",battleCutScope and 1 or 0)
  if battleCutScope then
    pcall(sh.send,sh,"battleCutFloor",battleCutScope.floor)
    pcall(sh.send,sh,"battleCutA",battleCutScope[1])
    pcall(sh.send,sh,"battleCutB",battleCutScope[2])
  end
  if texture then mesh:setTexture(texture) end
  pcall(sh.send, sh, "model", "row", model or IDENTITY)
  pcall(sh.send, sh, "sunModel", "row", sunModel or model or IDENTITY)
  drawUniforms.send(sh,"pull",pull or 0)
  drawUniforms.send(sh,"breeze",Voxel3D.breeze and (love.timer.getTime() % 3600) or 0)
  Instances.draw(batch,sh)
end

function Voxel3D.battleOcclusion(arena,ground,textures)
  battleCutScope=V.require("BattleOcclusion").build(Voxel3D.eye,arena,ground,textures)
end


function Voxel3D.dayTint(tint)
  if not (active and activeShader) then return end
  pcall(activeShader.send, activeShader, "dayTint",
        tint or Voxel3D.tint or { 1, 1, 1 })
end

function Voxel3D.lighting(on)
  if not (active and activeShader) then return end
  effectLightOn = on == false and 0 or 1
  if on == false then
    local flat = Voxel3D.unlitShader()
    if flat then
      pcall(flat.send, flat, "vp", "row", Voxel3D.vp)
      pcall(flat.send, flat, "eye", Voxel3D.eye)
      pcall(flat.send, flat, "curve",
            { Voxel3D.curveX or 0, Voxel3D.curveZ or 0,
              Voxel3D.curveK or 0 })
      pcall(flat.send, flat, "ghost", flattenAmount)
      pcall(flat.send, flat, "ghostColor",
            flattenColor or Voxel3D.GHOST_COLOR)
      love.graphics.setShader(flat)
      activeShader = flat
      return
    end
    pcall(activeShader.send, activeShader, "lightOn", 0)
    return
  end

  if sceneShader then
    love.graphics.setShader(sceneShader)
    activeShader = sceneShader
  end
  pcall(activeShader.send, activeShader, "lightOn", 1)
end

function Voxel3D.coverRect(iw, ih, cw, ch, topOffset)
  if not (iw and ih and cw and ch and iw > 0 and ih > 0
          and cw > 0 and ch > 0) then return nil end
  local scale = math.max(cw / iw, ch / ih)
  local available = math.max(0, ih - ch / scale)
  local crop = math.max(0, math.min(available, tonumber(topOffset) or 0))
  return (cw - iw * scale) / 2, -crop * scale, scale, crop
end

function Voxel3D.backdropTransform(iw, ih, x, y, scale, metal)
  if metal then return x, y + ih * scale, scale, -scale end
  return x, y, scale, scale
end

function Voxel3D.backdrop(image, topOffset)
  if not (active and image and image.getDimensions) then return false end
  local ok, iw, ih = pcall(image.getDimensions, image)
  if not ok or not (iw and ih and iw > 0 and ih > 0) then return false end
  local x, y, scale = Voxel3D.coverRect(
    iw, ih, canvasW, canvasH, topOffset)
  if not scale then return false end
  local blur = Voxel3D.backdropShader()
  love.graphics.setShader(blur)
  if blur then
    pcall(blur.send, blur, "texel", { 1 / iw, 1 / ih })
    pcall(blur.send, blur, "radius", Voxel3D.BACKDROP_BLUR_RADIUS)
  end
  love.graphics.setDepthMode()
  love.graphics.setColor(1, 1, 1, 1)
  local dx, dy, sx, sy = Voxel3D.backdropTransform(
    iw, ih, x, y, scale, Voxel3D.metalRenderer())
  love.graphics.draw(image, dx, dy, 0, sx, sy)
  love.graphics.setDepthMode("lequal", true)
  if sceneShader then
    love.graphics.setShader(sceneShader)
    activeShader = sceneShader
  end
  return true
end

function Voxel3D.project(wx, wy, wz)
  local m = Voxel3D.vp
  if not m then return nil end
  wy = wy - WorldCurve.drop(Voxel3D.curveK or 0, Voxel3D.curveX or 0,
                            Voxel3D.curveZ or 0, wx, wz)
  local cx = m[1] * wx + m[2] * wy + m[3] * wz + m[4]
  local cy = m[5] * wx + m[6] * wy + m[7] * wz + m[8]
  local cw = m[13] * wx + m[14] * wy + m[15] * wz + m[16]
  if cw <= 1e-6 then return nil end
  local x = (cx / cw * 0.5 + 0.5) * canvasW
  local y = (cy / cw * 0.5 + 0.5) * canvasH
  local cz = m[9] * wx + m[10] * wy + m[11] * wz + m[12]
  return x, y, (Voxel3D.focusW or cw) / cw, (cz / cw) * 0.5 + 0.5
end

function Voxel3D.interiorClip(on)
  if activeShader then pcall(activeShader.send,activeShader,"interiorCut",on and Voxel3D.interior and 1 or 0)end
end

function Voxel3D.endScene()
  Voxel3D.interior = nil
  Voxel3D.streetLamps = nil
  Voxel3D.battleFireLight = nil
  if not active then return nil end
  love.graphics.setShader()
  love.graphics.setDepthMode()
  love.graphics.setMeshCullMode("none")
  love.graphics.setCanvas()
  active, activeShader, sceneShader = false, nil, nil
  return canvas
end

function Voxel3D.canvas()
  return canvas
end

function Voxel3D.size()
  return canvasW, canvasH
end

function Voxel3D.invalidate()
  Voxel3D.companionCameraDelta = nil
  for name, slotHeld in pairs(slots) do
    releaseSlot(slotHeld)
    slots[name] = nil
  end
  canvas, canvasW, canvasH = nil, 0, 0
  held = nil
  ShadowMap.invalidate()
  Sky.invalidate()
  V.require("Water").invalidate()
  GlassMask.invalidate()
end

return Voxel3D
