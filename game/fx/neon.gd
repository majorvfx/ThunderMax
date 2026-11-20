class_name Neon
extends RefCounted
## The Neon Wasteland look: an '80s idea of the future, left to rot. Dark steel and
## rust under a magenta dusk, lit by neon tubes that nobody turned off.
##
## One palette for the arena, the cars and the UI, so the look can be retuned in
## one place.

const MAGENTA := Color(1.0, 0.16, 0.55)
const CYAN := Color(0.1, 0.9, 1.0)
const AMBER := Color(1.0, 0.62, 0.1)
const ACID := Color(0.55, 1.0, 0.2)
const VIOLET := Color(0.55, 0.3, 1.0)
const RED := Color(1.0, 0.12, 0.15)

const NIGHT := Color(0.03, 0.02, 0.07)       ## deepest background
const PANEL := Color(0.04, 0.03, 0.09, 0.9)  ## UI panels
const INK := Color(0.9, 0.93, 1.0)           ## bright text
const DIM := Color(0.55, 0.52, 0.7)          ## secondary text

static var _mats := {}
static var _fonts := {}


static func hex(code: String) -> Color:
	return Color.html(code) if Color.html_is_valid(code) else MAGENTA


## Glowing tube material. `energy` above ~2 blooms when glow is on.
static func tube(color: Color, energy: float = 3.0) -> StandardMaterial3D:
	var key := "%s:%.2f" % [color.to_html(false), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color.lightened(0.25)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


## A thin glowing strip from `a` to `b` (local to `parent`).
static func strip(parent: Node3D, a: Vector3, b: Vector3, color: Color, thickness: float = 0.06, energy: float = 3.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(thickness, thickness, maxf(a.distance_to(b), 0.01))
	box.material = tube(color, energy)
	mi.mesh = box
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD
	mi.transform = Transform3D(Basis.looking_at(dir, up), (a + b) * 0.5)
	return mi


## Slanted, spaced-out display face for headings: the '80s chrome-lettering feel
## from the stock font, no extra font files.
static func display_font(slant: float = 0.18, spacing: int = 3) -> Font:
	var key := "%.2f:%d" % [slant, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = 0.6
	f.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-slant, 1.0), Vector2.ZERO)
	f.spacing_glyph = spacing
	_fonts[key] = f
	return f


## Night sky with a banded retro sun low in the north, a wireframe mountain ridge
## and a few stars. Works on every renderer.
static func sky_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.02, 0.01, 0.06);
uniform vec3 mid_color : source_color = vec3(0.16, 0.03, 0.22);
uniform vec3 horizon_color : source_color = vec3(0.85, 0.16, 0.42);
uniform vec3 sun_top : source_color = vec3(1.0, 0.86, 0.3);
uniform vec3 sun_bottom : source_color = vec3(1.0, 0.18, 0.55);
uniform vec3 ridge_color : source_color = vec3(0.05, 0.02, 0.1);
uniform vec3 ridge_line : source_color = vec3(0.1, 0.9, 1.0);
uniform vec3 sun_dir = vec3(0.0, 0.1, -1.0);
uniform float sun_size = 0.24;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float ridge(float az) {
	// Jagged peaks: a few layered triangle waves, our own shape.
	float h = 0.0;
	h += abs(fract(az * 1.7) - 0.5) * 0.10;
	h += abs(fract(az * 4.3 + 0.37) - 0.5) * 0.05;
	h += abs(fract(az * 9.1 + 0.71) - 0.5) * 0.02;
	return h - 0.012;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float y = d.y;
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.18, y));
	col = mix(col, top_color, smoothstep(0.18, 0.6, y));
	if (y < 0.0) {
		col = mix(horizon_color * 0.35, ridge_color, smoothstep(0.0, -0.1, y));
	}
	// Stars, high up only.
	if (y > 0.25) {
		vec2 cell = floor(vec2(atan(d.x, d.z), asin(y)) * 260.0);
		float s = step(0.996, hash(cell));
		col += vec3(s) * smoothstep(0.25, 0.5, y) * 0.8;
	}
	// The sun: banded across its lower half.
	vec3 sd = normalize(sun_dir);
	float ang = acos(clamp(dot(d, sd), -1.0, 1.0));
	if (ang < sun_size) {
		float v = (y - (sd.y - sun_size)) / (2.0 * sun_size);
		vec3 sc = mix(sun_bottom, sun_top, clamp(v, 0.0, 1.0));
		float band = 1.0;
		if (v < 0.55) {
			float stripes = fract(v * 11.0);
			float gap = mix(0.45, 0.05, v / 0.55);
			band = step(gap, stripes);
		}
		float edge = smoothstep(sun_size, sun_size - 0.01, ang);
		col = mix(col, sc * 1.15, edge * band);
	}
	col += sun_bottom * 0.25 * exp(-ang * 3.0);
	// Mountain ridge in front of the sun, with a neon outline.
	float az = atan(d.x, -d.z) / 6.28318;
	float h = ridge(az);
	if (y < h && y > -0.2) {
		col = ridge_color;
		float line = smoothstep(0.004, 0.0, abs(y - h));
		float grid = step(0.97, fract(az * 90.0)) * step(0.0, y) * 0.35;
		col += ridge_line * (line * 1.6 + grid * smoothstep(-0.02, h, y));
	}
	COLOR = col;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
