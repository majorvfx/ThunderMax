class_name RearMirror
extends Control
## Rear-view mirror at the top of the screen: a small second camera looking back
## from the car's roof, flipped like a real mirror. Off by default; it only renders
## while shown, so it costs nothing when hidden.

var target: ArcadeVehicle
var _viewport: SubViewport
var _cam: Camera3D
var _frame: Panel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -210.0
	offset_right = 210.0
	offset_top = 14.0
	offset_bottom = 144.0
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(420, 130)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.near = 0.3
	_cam.far = 300.0
	_viewport.add_child(_cam)
	_frame = Panel.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.offset_left = -4
	_frame.offset_top = -4
	_frame.offset_right = 4
	_frame.offset_bottom = 4
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.07, 0.06)
	box.border_color = Color(0.45, 0.32, 0.2)
	box.set_border_width_all(3)
	_frame.add_theme_stylebox_override("panel", box)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var view := TextureRect.new()
	view.texture = _viewport.get_texture()
	view.flip_h = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	visible = false


func toggle() -> bool:
	visible = not visible
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	return visible


func _process(_delta: float) -> void:
	if not visible or target == null:
		return
	var xf := target.get_global_transform_interpolated()
	var back := xf.basis.z
	back.y = 0.0
	if back.length_squared() < 0.001:
		return
	back = back.normalized()
	var eye := xf.origin + Vector3.UP * 1.7 + back * 0.4
	_cam.global_position = eye
	_cam.look_at(eye + back * 10.0 + Vector3.DOWN * 0.8, Vector3.UP)
