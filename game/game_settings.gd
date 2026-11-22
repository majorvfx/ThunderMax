class_name GameSettings
extends RefCounted
## Player settings, saved to user://settings.cfg (including remapped controls).
##
## Frame rate: physics always runs at 60 Hz so handling feels the same at any
## frame rate. "auto" starts at 60 fps and drops to a steady 30 if the machine
## can't hold 60, matching the classic 30 fps feel on basic hardware and iPads.

const PATH := "user://settings.cfg"
const FPS_MODES := ["auto", "30", "60"]
const QUALITIES := ["low", "medium", "high"]
const LAYOUT_VERSION := 2

static var fps_mode := "auto"
static var quality := "medium"
static var control_preset := InputSetup.DEFAULT_PRESET
static var car := "rustjaw"       ## the player's car, from data/roster.json
static var sfx_volume := 1.0
static var music_volume := 0.7
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	if OS.has_feature("mobile"):
		quality = "low"
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		if not migrate_from_thunder_max() or cfg.load(PATH) != OK:
			return
	fps_mode = str(cfg.get_value("display", "fps_mode", fps_mode))
	quality = str(cfg.get_value("display", "quality", quality))
	control_preset = str(cfg.get_value("controls", "preset", control_preset))
	# Settings saved before the D-pad Standard layout became the default move to it once.
	if int(cfg.get_value("controls", "layout_version", 1)) < LAYOUT_VERSION:
		control_preset = InputSetup.DEFAULT_PRESET
	car = str(cfg.get_value("player", "car", car))
	if not GameData.roster().has(car):
		car = "rustjaw"
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	InputBindings.load_from(cfg)
	if not FPS_MODES.has(fps_mode):
		fps_mode = "auto"
	if not QUALITIES.has(quality):
		quality = "medium"
	control_preset = InputSetup.resolve_preset(control_preset)


## Iron Carnage used to be called Thunder Max: Metal Road and saved under that
## name. The first time Iron Carnage runs, it copies the old settings (controls,
## remaps, car) and saved handling tuning across. Returns true if it found them.
static func migrate_from_thunder_max() -> bool:
	var base := OS.get_data_dir().path_join("Godot").path_join("app_userdata")
	for old_name in ["Thunder Max_ Metal Road", "Thunder Max: Metal Road", "Thunder Max"]:
		var old_dir: String = base.path_join(old_name)
		var old_cfg := old_dir.path_join("settings.cfg")
		if not FileAccess.file_exists(old_cfg):
			continue
		DirAccess.copy_absolute(old_cfg, ProjectSettings.globalize_path(PATH))
		var old_tuning := old_dir.path_join("tuning")
		var d := DirAccess.open(old_tuning)
		if d != null:
			DirAccess.make_dir_recursive_absolute(GameData.TUNING_DIR)
			for f in d.get_files():
				DirAccess.copy_absolute(old_tuning.path_join(f), ProjectSettings.globalize_path(GameData.TUNING_DIR + f))
		return true
	return false


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fps_mode", fps_mode)
	cfg.set_value("display", "quality", quality)
	cfg.set_value("controls", "preset", control_preset)
	cfg.set_value("controls", "layout_version", LAYOUT_VERSION)
	cfg.set_value("player", "car", car)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	InputBindings.save_to(cfg)
	cfg.save(PATH)


static func next_in(list: Array, current: String) -> String:
	var i := list.find(current)
	return list[(i + 1) % list.size()]


## Builds the chosen pad layout plus keyboard, then applies the player's remaps.
static func apply_controls() -> void:
	InputSetup.apply_preset(1, -1, control_preset, true)
	InputBindings.apply(1, -1, control_preset)


## Applies render quality to a viewport, its world environment and the arena lights.
static func apply_quality(viewport: Viewport, env: Environment, sun: DirectionalLight3D, lamps: Array) -> void:
	match quality:
		"low":
			viewport.scaling_3d_scale = 0.75
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			if env:
				env.glow_enabled = false
				env.fog_density = 0.006
			if sun:
				sun.shadow_enabled = false
			for l in lamps:
				(l as OmniLight3D).shadow_enabled = false
		"medium":
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			if env:
				env.glow_enabled = true
				env.fog_density = 0.008
			if sun:
				sun.shadow_enabled = true
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			for l in lamps:
				(l as OmniLight3D).shadow_enabled = false
		"high":
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_2X
			if env:
				env.glow_enabled = true
				env.fog_density = 0.008
			if sun:
				sun.shadow_enabled = true
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			for l in lamps:
				(l as OmniLight3D).shadow_enabled = true
