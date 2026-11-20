class_name Hud
extends Control
## Player HUD drawn in one pass: health, turbo, gun heat, speed, wrecks,
## a lock-on bracket, messages and an optional debug readout.

var vehicle: ArcadeVehicle
var gun: MachineGun
var camera: Camera3D
var governor: FrameGovernor
var wrecks := 0
var show_debug := false
var hint_time := 12.0

var _messages: Array = []   ## [text, time_left]
var _font: Font

const C_TEXT := Color(0.92, 0.88, 0.8)
const C_DIM := Color(0.6, 0.56, 0.5)
const C_HEALTH := Color(0.75, 0.16, 0.08)
const C_TURBO := Color(0.95, 0.62, 0.15)
const C_HEAT := Color(0.85, 0.85, 0.8)
const C_PANEL := Color(0.05, 0.04, 0.035, 0.72)
const C_EDGE := Color(0.45, 0.25, 0.12)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func message(text: String, seconds: float = 2.6) -> void:
	_messages.append([text, seconds])
	if _messages.size() > 4:
		_messages.pop_front()


func _process(delta: float) -> void:
	for m in _messages:
		m[1] -= delta
	_messages = _messages.filter(func(m): return m[1] > 0.0)
	hint_time = maxf(0.0, hint_time - delta)
	queue_redraw()


func _draw() -> void:
	if vehicle == null:
		return
	var s := size
	var scale_ui := clampf(s.y / 720.0, 0.75, 2.0)
	var fs := int(18 * scale_ui)
	var big := int(34 * scale_ui)
	var pad := 18.0 * scale_ui

	# Status panel, top left.
	var pw := 300.0 * scale_ui
	var ph := 118.0 * scale_ui
	draw_rect(Rect2(pad, pad, pw, ph), C_PANEL)
	draw_rect(Rect2(pad, pad, pw, ph), C_EDGE, false, 2.0)
	draw_string(_font, Vector2(pad + 12 * scale_ui, pad + 26 * scale_ui), vehicle.stats.display_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, C_TEXT)
	var bx := pad + 12 * scale_ui
	var bw := pw - 24 * scale_ui
	_bar(Vector2(bx, pad + 38 * scale_ui), bw, 16 * scale_ui, vehicle.health.fraction(), C_HEALTH, "ARMOR", fs - 4)
	_bar(Vector2(bx, pad + 64 * scale_ui), bw, 12 * scale_ui, vehicle.drive.turbo / maxf(vehicle.stats.turbo_capacity, 1.0), C_TURBO, "TURBO", fs - 4)
	var heat_col := Color(1.0, 0.3, 0.1) if gun != null and gun.gun.overheated else C_HEAT
	_bar(Vector2(bx, pad + 86 * scale_ui), bw, 10 * scale_ui, gun.gun.heat if gun != null else 0.0, heat_col, "GUN HEAT" if gun == null or not gun.gun.overheated else "OVERHEATED", fs - 4)

	# Wrecks, top right.
	var wtxt := "WRECKS  %d" % wrecks
	draw_string(_font, Vector2(s.x - pad - 220 * scale_ui, pad + 30 * scale_ui), wtxt, HORIZONTAL_ALIGNMENT_RIGHT, 220 * scale_ui, big - 8, C_TEXT)
	if governor != null:
		var fps_txt := "%d FPS  (%s)" % [Engine.get_frames_per_second(), governor.label()]
		draw_string(_font, Vector2(s.x - pad - 260 * scale_ui, pad + 54 * scale_ui), fps_txt, HORIZONTAL_ALIGNMENT_RIGHT, 260 * scale_ui, fs - 6, C_DIM)

	# Speed, bottom right.
	var kmh := absf(vehicle.drive.speed) * 3.6
	draw_string(_font, Vector2(s.x - pad - 220 * scale_ui, s.y - pad - 14 * scale_ui), "%d" % int(kmh), HORIZONTAL_ALIGNMENT_RIGHT, 160 * scale_ui, big + 10, C_TEXT)
	draw_string(_font, Vector2(s.x - pad - 56 * scale_ui, s.y - pad - 14 * scale_ui), "KM/H", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 4, C_DIM)
	if vehicle.drive.boosting:
		draw_string(_font, Vector2(s.x - pad - 220 * scale_ui, s.y - pad - 64 * scale_ui), "TURBO", HORIZONTAL_ALIGNMENT_RIGHT, 216 * scale_ui, fs, C_TURBO)

	# Crosshair and lock-on.
	var c := s * Vector2(0.5, 0.47)
	draw_line(c - Vector2(10, 0) * scale_ui, c - Vector2(4, 0) * scale_ui, C_TEXT, 2.0)
	draw_line(c + Vector2(4, 0) * scale_ui, c + Vector2(10, 0) * scale_ui, C_TEXT, 2.0)
	draw_line(c - Vector2(0, 10) * scale_ui, c - Vector2(0, 4) * scale_ui, C_TEXT, 2.0)
	if gun != null and gun.current_target != null and camera != null and is_instance_valid(gun.current_target):
		var wp := gun.current_target.global_position + Vector3.UP * 0.4
		if not camera.is_position_behind(wp):
			var sp := camera.unproject_position(wp)
			var r := 26.0 * scale_ui
			_bracket(sp, r, Color(1.0, 0.35, 0.15))

	# Messages.
	var my := s.y * 0.22
	for m in _messages:
		var alpha := clampf(m[1], 0.0, 1.0)
		draw_string(_font, Vector2(0, my), m[0], HORIZONTAL_ALIGNMENT_CENTER, s.x, fs + 6, Color(C_TEXT, alpha))
		my += (fs + 14) * 1.0

	# Controls hint at the start.
	if hint_time > 0.0:
		var alpha := clampf(hint_time, 0.0, 1.0)
		var hint := "%s controls  -  %s: pause  -  %s: tuning panel" % [
			InputSetup.PRESET_NAMES.get(GameSettings.control_preset, ""),
			InputBindings.pad_text(1, "pause"), InputBindings.pad_text(1, "tuning")]
		draw_string(_font, Vector2(0, s.y - pad - 8 * scale_ui), hint, HORIZONTAL_ALIGNMENT_CENTER, s.x, fs - 4, Color(C_DIM, alpha))

	if show_debug:
		_draw_debug(Vector2(pad, pad + ph + 20 * scale_ui), fs - 4)


func _bar(pos: Vector2, w: float, h: float, frac: float, col: Color, label: String, fs: int) -> void:
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.1, 0.08, 0.07, 0.9))
	draw_rect(Rect2(pos, Vector2(w * clampf(frac, 0.0, 1.0), h)), col)
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0, 0, 0, 0.8), false, 1.0)
	draw_string(_font, pos + Vector2(4, h - 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(fs - 2, 9), Color(1, 1, 1, 0.75))


func _bracket(p: Vector2, r: float, col: Color) -> void:
	var l := r * 0.45
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := p + Vector2(sx * r, sy * r)
			draw_line(corner, corner - Vector2(sx * l, 0), col, 2.0)
			draw_line(corner, corner - Vector2(0, sy * l), col, 2.0)


func _draw_debug(pos: Vector2, fs: int) -> void:
	var d := vehicle.drive
	var lines := [
		"speed %.1f m/s  (%.0f km/h)" % [d.speed, d.speed * 3.6],
		"slide %.2f m/s" % d.lateral,
		"steer %.2f  %s" % [d.steer, "digital" if vehicle.frame.steer_digital else "analog"],
		"yaw target %.0f deg/s" % rad_to_deg(d.yaw_rate),
		"grounded %s  drift %s  boost %s" % [vehicle.grounded, d.drifting, d.boosting],
		"throttle %.2f  brake %.2f" % [vehicle.frame.throttle, vehicle.frame.brake],
		"pads: %s" % str(Input.get_connected_joypads().map(func(id): return Input.get_joy_name(id))),
	]
	draw_rect(Rect2(pos - Vector2(6, fs + 4), Vector2(420, (fs + 6) * lines.size() + 10)), C_PANEL)
	var y := pos.y
	for line in lines:
		draw_string(_font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_TEXT)
		y += fs + 6
