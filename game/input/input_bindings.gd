class_name InputBindings
extends RefCounted
## Player remaps on top of the controller layouts in InputSetup.
##
## Each override replaces every binding of one kind for one action:
##   "pad_modern" / "pad_classic": controller bindings, kept per layout.
##   "keys": keyboard bindings (two slots, main and alt), shared by both layouts.
## A binding is stored as a short code: "btn:0", "axis:5:+", "key:87".
## An empty list means "unbound". Overrides are saved in user://settings.cfg.

const KEY_SLOTS := 2

## Actions in the order the remap screen lists them, with player-facing names.
const LABELS := {
	"accelerate": "Accelerate",
	"brake": "Brake / reverse",
	"steer_left": "Steer left",
	"steer_right": "Steer right",
	"fire_gun": "Machine gun",
	"fire_special": "Special weapon",
	"special_prev": "Previous special",
	"special_next": "Next special",
	"turbo": "Turbo",
	"look_back": "Look back",
	"pause": "Pause",
	"tuning": "Tuning panel",
	"debug": "Debug readout",
	"combo_up": "Combo up",
	"combo_down": "Combo down",
	"combo_left": "Combo left",
	"combo_right": "Combo right",
	"combo_hold": "Combo hold",
}

const _BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_GUIDE: "Xbox", JOY_BUTTON_START: "Menu",
	JOY_BUTTON_LEFT_STICK: "Left stick click", JOY_BUTTON_RIGHT_STICK: "Right stick click",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
	JOY_BUTTON_MISC1: "Share",
}

## kind -> { action: Array[String] }
static var overrides := {}


static func pad_kind(preset: String) -> String:
	return "pad_" + preset


# --- Codes ----------------------------------------------------------------------------

static func encode(ev: InputEvent) -> String:
	if ev is InputEventJoypadButton:
		return "btn:%d" % ev.button_index
	if ev is InputEventJoypadMotion:
		return "axis:%d:%s" % [ev.axis, "+" if ev.axis_value >= 0.0 else "-"]
	if ev is InputEventKey:
		var k: int = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
		return "key:%d" % k
	return ""


static func decode(code: String, device: int = -1) -> InputEvent:
	var p := code.split(":")
	match p[0]:
		"btn":
			if p.size() == 2 and p[1].is_valid_int():
				var b := InputEventJoypadButton.new()
				b.device = device
				b.button_index = int(p[1]) as JoyButton
				return b
		"axis":
			if p.size() == 3 and p[1].is_valid_int():
				var m := InputEventJoypadMotion.new()
				m.device = device
				m.axis = int(p[1]) as JoyAxis
				m.axis_value = -1.0 if p[2] == "-" else 1.0
				return m
		"key":
			if p.size() == 2 and p[1].is_valid_int():
				var k := InputEventKey.new()
				k.physical_keycode = int(p[1]) as Key
				return k
	return null


static func is_pad(ev: InputEvent) -> bool:
	return ev is InputEventJoypadButton or ev is InputEventJoypadMotion


## Player-facing name for a code, e.g. "RT", "D-pad left", "Space".
static func describe(code: String) -> String:
	if code == "":
		return "-"
	var ev := decode(code)
	if ev is InputEventJoypadButton:
		return _BUTTON_NAMES.get(ev.button_index, "Button %d" % ev.button_index)
	if ev is InputEventJoypadMotion:
		var plus: bool = ev.axis_value > 0.0
		match ev.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_LEFT_X:
				return "Left stick right" if plus else "Left stick left"
			JOY_AXIS_LEFT_Y:
				return "Left stick down" if plus else "Left stick up"
			JOY_AXIS_RIGHT_X:
				return "Right stick right" if plus else "Right stick left"
			JOY_AXIS_RIGHT_Y:
				return "Right stick down" if plus else "Right stick up"
		return "Axis %d %s" % [ev.axis, "+" if plus else "-"]
	if ev is InputEventKey:
		var name := OS.get_keycode_string(ev.physical_keycode)
		return name if name != "" else "Key %d" % ev.physical_keycode
	return "?"


# --- Reading the live bindings ------------------------------------------------------

## Controller codes currently bound to an action (buttons first, then axes).
static func pad_codes(slot: int, action: String) -> Array:
	var buttons := []
	var axes := []
	for ev in InputMap.action_get_events(InputSetup.action(slot, action)):
		if ev is InputEventJoypadButton:
			buttons.append(encode(ev))
		elif ev is InputEventJoypadMotion:
			axes.append(encode(ev))
	return buttons + axes


## Keyboard codes for an action, padded with "" to KEY_SLOTS entries.
static func key_codes(slot: int, action: String) -> Array:
	var out := []
	for ev in InputMap.action_get_events(InputSetup.action(slot, action)):
		if ev is InputEventKey and out.size() < KEY_SLOTS:
			out.append(encode(ev))
	while out.size() < KEY_SLOTS:
		out.append("")
	return out


## One line for menus: "RT", "D-pad left / Left stick left", "W / Up".
static func pad_text(slot: int, action: String) -> String:
	return _join(pad_codes(slot, action))


static func key_text(slot: int, action: String) -> String:
	return _join(key_codes(slot, action))


static func _join(codes: Array) -> String:
	var names := []
	for c in codes:
		if c != "":
			names.append(describe(c))
	return "-" if names.is_empty() else " / ".join(names)


# --- Applying -----------------------------------------------------------------------

## Applies saved overrides on top of the preset already in the InputMap.
static func apply(slot: int, device: int, preset: String) -> void:
	_apply_kind(slot, device, overrides.get(pad_kind(preset), {}), true)
	_apply_kind(slot, device, overrides.get("keys", {}), false)


static func _apply_kind(slot: int, device: int, table: Dictionary, pad: bool) -> void:
	for a in table:
		var act := InputSetup.action(slot, a)
		if not InputMap.has_action(act):
			continue
		for ev in InputMap.action_get_events(act):
			if is_pad(ev) == pad and (pad or ev is InputEventKey):
				InputMap.action_erase_event(act, ev)
		for code in table[a]:
			var ev := decode(code, device)
			if ev != null and is_pad(ev) == pad:
				InputMap.action_add_event(act, ev)


# --- Changing -----------------------------------------------------------------------

## Binds a controller input to an action for this layout. If another action already
## uses it, that action takes over this action's old binding (a swap).
## Returns the action that was swapped, or "".
static func set_pad(slot: int, preset: String, action: String, code: String) -> String:
	var kind := pad_kind(preset)
	var old := pad_codes(slot, action)
	if old.has(code):
		_store(kind, action, [code])
		return ""
	var swapped := ""
	for other in InputSetup.ACTIONS:
		if other == action:
			continue
		var theirs := pad_codes(slot, other)
		if theirs.has(code):
			theirs.erase(code)
			if not old.is_empty() and not theirs.has(old[0]):
				theirs.push_front(old[0])
			_store(kind, other, theirs)
			swapped = other
	_store(kind, action, [code])
	return swapped


## Binds a key to one of an action's key slots, swapping with any other action
## that used it. Returns the action that was swapped, or "".
static func set_key(slot: int, action: String, index: int, code: String) -> String:
	var mine := key_codes(slot, action)
	var previous: String = mine[index]
	if previous == code:
		return ""
	# Already in this action's other slot: just swap the two slots.
	var same := mine.find(code)
	if same >= 0:
		mine[same] = previous
		mine[index] = code
		_store("keys", action, _compact(mine))
		return ""
	var swapped := ""
	for other in InputSetup.ACTIONS:
		if other == action:
			continue
		var theirs := key_codes(slot, other)
		var at := theirs.find(code)
		if at >= 0:
			theirs[at] = previous if not theirs.has(previous) else ""
			_store("keys", other, _compact(theirs))
			swapped = other
	mine[index] = code
	_store("keys", action, _compact(mine))
	return swapped


## Removes a key from one slot of an action.
static func clear_key(slot: int, action: String, index: int) -> void:
	var mine := key_codes(slot, action)
	mine[index] = ""
	_store("keys", action, _compact(mine))


## Drops all controller remaps for one layout and all keyboard remaps.
static func reset(preset: String) -> void:
	overrides.erase(pad_kind(preset))
	overrides.erase("keys")


static func has_overrides(preset: String) -> bool:
	return not overrides.get(pad_kind(preset), {}).is_empty() or not overrides.get("keys", {}).is_empty()


static func _store(kind: String, action: String, codes: Array) -> void:
	if not overrides.has(kind):
		overrides[kind] = {}
	overrides[kind][action] = codes.duplicate()


static func _compact(codes: Array) -> Array:
	var out := []
	for c in codes:
		if c != "":
			out.append(c)
	return out


# --- Saving -------------------------------------------------------------------------

static func save_to(cfg: ConfigFile) -> void:
	for kind in overrides:
		for a in overrides[kind]:
			cfg.set_value("bindings_" + kind, a, ",".join(PackedStringArray(overrides[kind][a])))


static func load_from(cfg: ConfigFile) -> void:
	overrides = {}
	for section in cfg.get_sections():
		if not section.begins_with("bindings_"):
			continue
		var kind := section.trim_prefix("bindings_")
		for a in cfg.get_section_keys(section):
			if not InputSetup.ACTIONS.has(a):
				continue
			var codes := []
			for c in str(cfg.get_value(section, a, "")).split(",", false):
				if decode(c) != null:
					codes.append(c)
			_store(kind, a, codes)
