class_name CarSelect
extends Control
## Pick your car: a turning preview, its numbers next to the rest of the roster,
## and its own special. Left / right to choose, A or Enter to drive, B or Esc back.

signal chosen(car_id: String)
signal back_pressed

var cars: Array[String] = []
var index := 0

var _stats: Array[VehicleStats] = []
var _pivot: Node3D
var _preview_car: ArcadeVehicle
var _name: Label
var _class: Label
var _desc: Label
var _special_name: Label
var _special_desc: Label
var _bars := {}            ## stat key -> ProgressBar
var _dots: Label
var _ranges := {}          ## stat key -> [min, max] across the roster
var _fill: StyleBoxFlat    ## shared bar fill, tinted to the car's neon
var _ring: MeshInstance3D  ## floor ring under the preview, same tint

const STAT_ROWS := [
	["armor", "ARMOR"],
	["speed", "TOP SPEED"],
	["accel", "ACCELERATION"],
	["handling", "HANDLING"],
	["ram", "RAM"],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	cars = GameData.roster()
	for id in cars:
		_stats.append(GameData.load_vehicle(id, false))
	_compute_ranges()
	index = maxi(0, cars.find(GameSettings.car))
	_build()
	_show(index)


func _exit_tree() -> void:
	if _preview_car != null:
		_preview_car.free()
		_preview_car = null


static func stat_value(s: VehicleStats, key: String) -> float:
	match key:
		"armor":
			return s.max_health
		"speed":
			return s.max_speed
		"accel":
			return s.accel
		"handling":
			return s.turn_rate_deg * (0.5 + 0.05 * s.grip)
		"ram":
			return s.ram_power * s.mass
	return 0.0


func _compute_ranges() -> void:
	for row in STAT_ROWS:
		var lo := INF
		var hi := -INF
		for s in _stats:
			var v := stat_value(s, row[0])
			lo = minf(lo, v)
			hi = maxf(hi, v)
		_ranges[row[0]] = [lo, hi]


## 0.25 for the lowest in the roster up to 1.0 for the highest.
func bar_fraction(s: VehicleStats, key: String) -> float:
	var r: Array = _ranges[key]
	if r[1] - r[0] < 0.0001:
		return 0.7
	return lerpf(0.25, 1.0, (stat_value(s, key) - r[0]) / (r[1] - r[0]))


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Neon.NIGHT
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 20
	root.offset_bottom = -20
	root.add_theme_constant_override("separation", 20)
	add_child(root)

	# Left: the turning car.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.4
	root.add_child(left)
	var heading := UiStyle.heading("CHOOSE YOUR CAR", 40)
	left.add_child(heading)
	var view_box := SubViewportContainer.new()
	view_box.stretch = true
	view_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(view_box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	view_box.add_child(vp)
	_build_stage(vp)
	_dots = UiStyle.label("", 22, Neon.INK)
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_dots)

	# Right: name, numbers, special.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	_name = UiStyle.heading("", 44, Neon.INK)
	col.add_child(_name)
	_class = UiStyle.label("", 18, Neon.CYAN)
	col.add_child(_class)
	_desc = UiStyle.label("", 17, Color(0.74, 0.72, 0.88))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(360, 0)
	col.add_child(_desc)
	col.add_child(UiStyle.label(" ", 6))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for row in STAT_ROWS:
		grid.add_child(UiStyle.label(row[1], 15, Neon.DIM))
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(220, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if _fill == null:
			_fill = StyleBoxFlat.new()
			_fill.bg_color = Neon.MAGENTA
			_fill.shadow_size = 4
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.1, 0.07, 0.18)
		back.border_color = Color(0.3, 0.2, 0.5)
		back.set_border_width_all(1)
		bar.add_theme_stylebox_override("fill", _fill)
		bar.add_theme_stylebox_override("background", back)
		grid.add_child(bar)
		_bars[row[0]] = bar
	col.add_child(UiStyle.label(" ", 6))
	col.add_child(UiStyle.label("OWN SPECIAL", 15, Neon.DIM))
	_special_name = UiStyle.heading("", 26, Neon.AMBER)
	col.add_child(_special_name)
	_special_desc = UiStyle.label("", 16, Color(0.74, 0.72, 0.88))
	_special_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_special_desc.custom_minimum_size = Vector2(360, 0)
	col.add_child(_special_desc)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	col.add_child(UiStyle.label("Left / right: choose     A: drive     B: back", 16, Neon.DIM))


func _build_stage(vp: SubViewport) -> void:
	var stage := Node3D.new()
	vp.add_child(stage)
	var env := Environment.new()
	# The same dusk as the Yard, with the sun swung round to sit behind the turntable.
	var sky_mat := Neon.sky_material()
	sky_mat.set_shader_parameter("sun_dir", Vector3(-0.62, 0.06, -0.78))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.35, 0.7)
	env.ambient_light_energy = 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_color = Color(0.8, 0.85, 1.0)
	sun.light_energy = 1.1
	stage.add_child(sun)
	for rim_def in [[Vector3(-3.5, 2.5, -4), Neon.MAGENTA], [Vector3(4.5, 1.5, -2.5), Neon.CYAN]]:
		var rim := OmniLight3D.new()
		rim.position = rim_def[0]
		rim.light_color = rim_def[1]
		rim.light_energy = 3.0
		rim.omni_range = 12.0
		stage.add_child(rim)
	VehicleVisualParts.cylinder(stage, 4.2, 0.2, Vector3(0, -0.72, 0), Vector3.ZERO, VehicleVisualParts.material("steel"))
	# A neon ring on the turntable, tinted to the car on show.
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.0
	torus.outer_radius = 2.12
	torus.rings = 48
	_ring.mesh = torus
	_ring.position = Vector3(0, -0.6, 0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(_ring)
	# Back wall of failing tubes, so the car reads against something.
	for i in 7:
		var x := -6.0 + i * 2.0
		var tube_col := Neon.VIOLET if i % 2 == 0 else Neon.MAGENTA
		Neon.strip(stage, Vector3(x, -0.6, -6.0), Vector3(x + 0.6, 4.5, -6.0), tube_col, 0.05, 1.6 if i != 4 else 0.4)
	_pivot = Node3D.new()
	stage.add_child(_pivot)
	var cam := Camera3D.new()
	cam.fov = 45.0
	stage.add_child(cam)
	cam.look_at_from_position(Vector3(6.2, 2.6, 7.4), Vector3(0, 0.3, 0))
	cam.current = true


func _show(i: int) -> void:
	index = (i + cars.size()) % cars.size()
	var s := _stats[index]
	_name.text = s.display_name.to_upper()
	var tint := Neon.hex(s.accent) if s.accent != "" else Neon.MAGENTA
	_name.add_theme_color_override("font_outline_color", Color(tint, 0.6))
	_fill.bg_color = tint
	_fill.shadow_color = Color(tint, 0.4)
	_ring.material_override = Neon.tube(tint, 3.0)
	_class.text = "%s CLASS" % s.vehicle_class.to_upper()
	_desc.text = s.description
	for row in STAT_ROWS:
		(_bars[row[0]] as ProgressBar).value = bar_fraction(s, row[0])
	var sig := GameData.signature(s.id)
	_special_name.text = str(sig.get("name", "None")).to_upper()
	_special_desc.text = "%s  Recharges in %d s." % [str(sig.get("description", "")), int(sig.get("recharge_s", 0))] if not sig.is_empty() else ""
	var dots := []
	for k in cars.size():
		dots.append("[%s]" % _stats[k].display_name if k == index else _stats[k].display_name)
	_dots.text = "<   " + "    ".join(dots) + "   >"
	# Swap the preview model.
	for c in _pivot.get_children():
		c.queue_free()
	if _preview_car != null:
		_preview_car.free()
	_preview_car = ArcadeVehicle.new()
	_preview_car.setup(s, null, false)
	var visual := VehicleVisual.new()
	_pivot.add_child(visual)
	visual.build(_preview_car, s.paint)


func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotate_y(delta * 0.6)
	# Polled as just-pressed so a held stick steps once instead of spinning through.
	var left := Input.is_action_just_pressed("ui_left") or _just(InputSetup.action(1, "steer_left"))
	var right := Input.is_action_just_pressed("ui_right") or _just(InputSetup.action(1, "steer_right"))
	if left != right:
		GameAudio.play_ui("ui_click", 0.5)
		_show(index + (1 if right else -1))


func _just(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)


func _unhandled_input(event: InputEvent) -> void:
	var go := event.is_action_pressed("ui_accept")
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		confirm()
		return
	var back := event.is_action_pressed("ui_cancel")
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		back = true
	if back:
		get_viewport().set_input_as_handled()
		GameAudio.play_ui("ui_click", 0.5)
		back_pressed.emit()


## Locks in the highlighted car, remembers it for next time, and starts.
func confirm() -> void:
	GameSettings.car = cars[index]
	GameSettings.save_settings()
	GameAudio.play_ui("ui_click", 0.8)
	chosen.emit(cars[index])
