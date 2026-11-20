class_name Hud
extends Control
## Player HUD drawn in one pass: health, turbo, gun heat, combo energy, special
## weapons, speed, wrecks, a lock-on bracket, combo input trail, status effects,
## messages and an optional debug readout.

var vehicle: ArcadeVehicle
var gun: MachineGun
var camera: Camera3D
var governor: FrameGovernor
var wrecks := 0
var show_radar := false
var show_debug := false
var hint_time := 12.0

var _messages: Array = []   ## [text, time_left]
var _font: Font
var _move_text := ""
var _move_time := 0.0
var _move_bad := false
var _shield_flash := 0.0

const C_TEXT := Color(0.92, 0.88, 0.8)
const C_DIM := Color(0.6, 0.56, 0.5)
const C_HEALTH := Color(0.75, 0.16, 0.08)
const C_TURBO := Color(0.95, 0.62, 0.15)
const C_HEAT := Color(0.85, 0.85, 0.8)
const C_PANEL := Color(0.05, 0.04, 0.035, 0.72)
const C_EDGE := Color(0.45, 0.25, 0.12)
const C_ENERGY := Color(0.55, 0.8, 0.95)
const C_ICE := Color(0.55, 0.85, 1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func message(text: String, seconds: float = 2.6) -> void:
	_messages.append([text, seconds])
	if _messages.size() > 4:
		_messages.pop_front()


## Big centred callout when a combo move fires (or fails).
func flash_move(text: String, bad: bool = false) -> void:
	_move_text = text
	_move_time = 1.1
	_move_bad = bad


func shield_hit() -> void:
	_shield_flash = 0.25


func _process(delta: float) -> void:
	_move_time = maxf(0.0, _move_time - delta)
	_shield_flash = maxf(0.0, _shield_flash - delta)
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
	var ph := 146.0 * scale_ui
	draw_rect(Rect2(pad, pad, pw, ph), C_PANEL)
	draw_rect(Rect2(pad, pad, pw, ph), C_EDGE, false, 2.0)
	draw_string(_font, Vector2(pad + 12 * scale_ui, pad + 26 * scale_ui), vehicle.stats.display_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, C_TEXT)
	var bx := pad + 12 * scale_ui
	var bw := pw - 24 * scale_ui
	_bar(Vector2(bx, pad + 38 * scale_ui), bw, 16 * scale_ui, vehicle.health.fraction(), C_HEALTH, "ARMOR", fs - 4)
	_bar(Vector2(bx, pad + 64 * scale_ui), bw, 12 * scale_ui, vehicle.drive.turbo / maxf(vehicle.stats.turbo_capacity, 1.0), C_TURBO, "TURBO", fs - 4)
	var heat_col := Color(1.0, 0.3, 0.1) if gun != null and gun.gun.overheated else C_HEAT
	_bar(Vector2(bx, pad + 86 * scale_ui), bw, 10 * scale_ui, gun.gun.heat if gun != null else 0.0, heat_col, "GUN HEAT" if gun == null or not gun.gun.overheated else "OVERHEATED", fs - 4)
	var st := vehicle.status
	_bar(Vector2(bx, pad + 108 * scale_ui), bw, 14 * scale_ui, st.energy / maxf(st.energy_max, 1.0), C_ENERGY, "ENERGY", fs - 4)
	# Energy notches at each 25 so you can see what a move costs.
	for i in range(1, 4):
		var nx := bx + bw * float(i) / 4.0
		draw_line(Vector2(nx, pad + 108 * scale_ui), Vector2(nx, pad + 122 * scale_ui), Color(0, 0, 0, 0.6), 1.0)

	var below := _draw_status(Vector2(pad, pad + ph + 26 * scale_ui), fs)
	_draw_specials(Vector2(pad, s.y - pad - 70 * scale_ui), scale_ui, fs)
	_draw_combo_trail(Vector2(s.x * 0.5, s.y - pad - 70 * scale_ui), scale_ui)
	if st.is_frozen():
		draw_rect(Rect2(Vector2.ZERO, s), Color(C_ICE, 0.12))
	if _shield_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.55, 0.15, _shield_flash * 0.5), false, 14.0 * scale_ui)
	if _move_time > 0.0:
		var a := clampf(_move_time * 2.0, 0.0, 1.0)
		var col := Color(1.0, 0.35, 0.2, a) if _move_bad else Color(C_TURBO, a)
		draw_string(_font, Vector2(0, s.y * 0.36), _move_text, HORIZONTAL_ALIGNMENT_CENTER, s.x, big, col)

	if show_radar:
		_draw_radar(Vector2(s.x - pad - 80 * scale_ui, pad + 150 * scale_ui), 70.0 * scale_ui)

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
		var hint := "%s controls  -  %s: pause  -  hold %s + D-pad: views, radar, mirror" % [
			InputSetup.PRESET_NAMES.get(GameSettings.control_preset, ""),
			InputBindings.pad_text(1, "pause"), InputBindings.pad_text(1, "view_mod")]
		draw_string(_font, Vector2(0, s.y - pad - 8 * scale_ui), hint, HORIZONTAL_ALIGNMENT_CENTER, s.x, fs - 4, Color(C_DIM, alpha))

	if show_debug:
		_draw_debug(Vector2(pad, below + 4 * scale_ui), fs - 4)


## Draws shield, freeze and burn timers under the panel; returns the y below them.
func _draw_status(pos: Vector2, fs: int) -> float:
	var st := vehicle.status
	var y := pos.y
	if st.is_shielded():
		draw_string(_font, Vector2(pos.x, y), "BULWARK  %.1f" % st.shield_time, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_TURBO)
		y += fs + 6
	if st.is_frozen():
		draw_string(_font, Vector2(pos.x, y), "FROZEN  %.1f" % st.frozen_time, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_ICE)
		y += fs + 6
	if st.is_burning():
		draw_string(_font, Vector2(pos.x, y), "BURNING", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.4, 0.1))
		y += fs + 6
	if st.is_cloaked():
		draw_string(_font, Vector2(pos.x, y), "BLACKOUT  %.1f" % st.cloak_time, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.75, 0.72, 0.68))
		y += fs + 6
	if st.is_overdriven():
		draw_string(_font, Vector2(pos.x, y), "RIVET STORM  %.1f" % st.overdrive_time, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.85, 0.3))
		y += fs + 6
	return y


func _draw_specials(pos: Vector2, scale_ui: float, fs: int) -> void:
	var sp := vehicle.specials
	if sp == null:
		return
	var w := 300.0 * scale_ui
	var h := 52.0 * scale_ui
	draw_rect(Rect2(pos, Vector2(w, h)), C_PANEL)
	draw_rect(Rect2(pos, Vector2(w, h)), C_EDGE, false, 2.0)
	if sp.selected == "" or sp.count(sp.selected) <= 0:
		draw_string(_font, pos + Vector2(12, 32) * scale_ui, "NO SPECIAL  -  find a weapon crate", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 4, C_DIM)
		return
	draw_string(_font, pos + Vector2(12, 32) * scale_ui, sp.display_name(sp.selected).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 4, C_TEXT)
	draw_string(_font, pos + Vector2(150, 32) * scale_ui, "x%d" % sp.count(sp.selected), HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 4, C_TURBO)
	var others := sp.total() - sp.count(sp.selected)
	if others > 0:
		draw_string(_font, pos + Vector2(200, 32) * scale_ui, "+%d more" % others, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 4, C_DIM)


## Arrows for the D-pad presses of a combo in progress, so players can see their input.
func _draw_combo_trail(center: Vector2, scale_ui: float) -> void:
	if vehicle.combos == null:
		return
	var presses := vehicle.combos.buffer.pending()
	if presses.is_empty() or vehicle.combos._clock - vehicle.combos.buffer._last_time > vehicle.combos.buffer.window:
		return
	var r := 12.0 * scale_ui
	var step := 34.0 * scale_ui
	var x0 := center.x - step * (presses.size() - 1) * 0.5
	for i in presses.size():
		var c := Vector2(x0 + step * i, center.y)
		var dir := Vector2.ZERO
		match presses[i]:
			"up": dir = Vector2.UP
			"down": dir = Vector2.DOWN
			"left": dir = Vector2.LEFT
			"right": dir = Vector2.RIGHT
		var side := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array([c + dir * r, c - dir * r * 0.6 + side * r * 0.8, c - dir * r * 0.6 - side * r * 0.8])
		draw_colored_polygon(pts, C_ENERGY)


## Top-down radar, your heading up. Drones are red (hidden under Blackout), live
## pickups are pale dots. Range 90 m; anything further sits on the rim.
func _draw_radar(center: Vector2, r: float) -> void:
	draw_circle(center, r, C_PANEL)
	draw_arc(center, r, 0.0, TAU, 48, C_EDGE, 2.0)
	draw_arc(center, r * 0.5, 0.0, TAU, 32, Color(C_EDGE, 0.35), 1.0)
	var xf := vehicle.global_transform
	var fwd := -xf.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		return
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var range_m := 90.0
	var blip := func(world: Vector3, col: Color, size: float) -> void:
		var d := world - xf.origin
		var p := Vector2(d.dot(right), -d.dot(fwd)) / range_m * r
		if p.length() > r - 4.0:
			p = p.normalized() * (r - 4.0)
		draw_circle(center + p, size, col)
	for n in get_tree().get_nodes_in_group("pickups"):
		if n is Node3D and n.has_method("is_active") and n.is_active():
			blip.call((n as Node3D).global_position, Color(0.9, 0.85, 0.7, 0.8), 2.5)
	for n in get_tree().get_nodes_in_group("vehicles"):
		var v := n as ArcadeVehicle
		if v == null or v == vehicle or not v.is_alive() or v.status.is_cloaked():
			continue
		blip.call(v.global_position, Color(1.0, 0.3, 0.15), 4.0)
	# You: an arrow pointing up.
	var tip := center + Vector2(0, -7)
	draw_colored_polygon(PackedVector2Array([tip, center + Vector2(-5, 6), center + Vector2(5, 6)]), C_TURBO)


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
