class_name GameData
extends RefCounted
## Loads game data from res://data as plain dictionaries.
## Keeping data in JSON means the same files can feed an Unreal DataTable later.

const VEHICLE_DIR := "res://data/vehicles/"
const WEAPONS_PATH := "res://data/weapons.json"
const PICKUPS_PATH := "res://data/pickups.json"
const TUNING_DIR := "user://tuning/"


static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameData: missing file %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("GameData: invalid JSON in %s" % path)
	return parsed


## Loads a vehicle's stats, with any saved tuning session from the tuning panel applied on top.
static func load_vehicle(id: String, include_saved_tuning: bool = true) -> VehicleStats:
	var d: Variant = load_json(VEHICLE_DIR + id + ".json")
	if typeof(d) != TYPE_DICTIONARY:
		return null
	var stats := VehicleStats.from_dict(d)
	if include_saved_tuning:
		var saved_path := TUNING_DIR + id + ".json"
		if FileAccess.file_exists(saved_path):
			var saved: Variant = load_json(saved_path)
			if typeof(saved) == TYPE_DICTIONARY:
				stats.apply_dict(saved)
	return stats


static func save_tuning(stats: VehicleStats) -> String:
	DirAccess.make_dir_recursive_absolute(TUNING_DIR)
	var path := TUNING_DIR + stats.id + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(stats.to_tuning_dict(), "  "))
	return ProjectSettings.globalize_path(path)


static func clear_tuning(id: String) -> void:
	var path := TUNING_DIR + id + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func weapon(id: String) -> Dictionary:
	var d: Variant = load_json(WEAPONS_PATH)
	if typeof(d) == TYPE_DICTIONARY and d.has(id):
		return d[id]
	return {}


static func pickups() -> Dictionary:
	var d: Variant = load_json(PICKUPS_PATH)
	return d if typeof(d) == TYPE_DICTIONARY else {}
