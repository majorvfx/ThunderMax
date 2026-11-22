class_name VehicleStats
extends RefCounted
## Tuning numbers for one vehicle, loaded from res://data/vehicles/<id>.json.
##
## Engine-agnostic: plain numbers only, no scene or node references, so the same
## data file drives the Godot build now and an Unreal build later.
## Units: metres, seconds, degrees, kilograms.

# Identity
var id := ""
var display_name := ""
var vehicle_class := "medium"
var description := ""
var paint := "rust"

# Health
var max_health := 100.0

# Drive
var max_speed := 30.0            ## m/s at full throttle, no turbo
var accel := 20.0                ## m/s^2 from a standstill
var accel_falloff := 0.5         ## 0 = linear pull to top speed, 1 = acceleration fades to 0 at top speed
var brake_decel := 45.0          ## m/s^2 when braking
var reverse_max_speed := 11.0
var reverse_accel := 14.0
var coast_decel := 7.0           ## m/s^2 with no pedal held

# Steering
var turn_rate_deg := 160.0       ## yaw degrees per second at full lock, low speed
var high_speed_turn_scale := 0.75  ## turn rate multiplier at top speed
var pivot_turn := 0.3            ## fraction of turn rate available when stopped
var full_turn_speed := 4.0       ## m/s at which full turn rate is available
var steer_ramp_time := 0.16      ## seconds for digital steering (D-pad, keys) to reach full lock
var steer_return_time := 0.08    ## seconds for digital steering to centre or flip
var analog_steer_curve := 1.4    ## >1 softens small stick movements
var yaw_response := 14.0         ## how fast actual yaw follows the target (1/s)

# Grip and drift
var grip := 10.0                 ## sideways slide damping (1/s); higher = more planted
var drift_grip := 2.2            ## sideways damping while power-sliding
var drift_min_speed := 12.0      ## m/s needed to start a power slide (brake + steer)
var drift_turn_boost := 1.35
var drift_brake_scale := 0.25
var tight_turn_boost := 1.7      ## turn-rate multiplier while the tight turn button is held
var tight_turn_drag := 5.0       ## m/s^2 of speed scrubbed off during a tight turn

# Air and body
var gravity_scale := 1.6
var air_control := 0.3
var air_upright := 3.0
var upright_strength := 8.0
var mass := 1400.0
var body_width := 1.9            ## collision box (m)
var body_height := 0.75
var body_length := 4.3
var wheel_track := 0.85          ## wheel distance from the centre line (m)
var wheel_base := 1.3            ## wheel distance from the middle, front and back (m)
var ride_height := 0.6           ## suspension rest length (m)
var suspension_hz := 2.2
var suspension_damping := 0.55

# Combat
var ram_power := 1.0             ## damage dealt multiplier when ramming
var ram_armor := 1.0             ## damage taken divisor when rammed

# Turbo
var turbo_capacity := 100.0
var turbo_drain := 35.0          ## per second while boosting
var turbo_regen := 4.0           ## per second when not boosting
var turbo_speed_mult := 1.4      ## top speed multiplier while boosting
var turbo_thrust := 18.0         ## m/s^2 rocket push on top of the engine; doesn't fade with speed
var turbo_kick := 4.0            ## m/s shove the moment the turbo lights (the nitrous hit)
var turbo_kick_cost := 6.0       ## meter spent on each light-up, so tapping isn't free
var turbo_air_thrust := 16.0     ## m/s^2 forward push from the rocket while airborne
var turbo_air_lift := 7.0        ## m/s^2 upward push while falling, so a boosted jump carries further

## Numbers exposed in the in-game tuning panel: [key, min, max, step]
const TUNABLE := [
	["max_speed", 10.0, 60.0, 0.5],
	["accel", 5.0, 60.0, 0.5],
	["accel_falloff", 0.0, 1.0, 0.05],
	["brake_decel", 10.0, 100.0, 1.0],
	["coast_decel", 0.0, 30.0, 0.5],
	["turn_rate_deg", 40.0, 360.0, 5.0],
	["high_speed_turn_scale", 0.2, 1.5, 0.05],
	["pivot_turn", 0.0, 1.0, 0.05],
	["steer_ramp_time", 0.0, 0.6, 0.01],
	["steer_return_time", 0.0, 0.4, 0.01],
	["analog_steer_curve", 1.0, 3.0, 0.1],
	["yaw_response", 2.0, 40.0, 0.5],
	["grip", 1.0, 30.0, 0.5],
	["drift_grip", 0.2, 10.0, 0.1],
	["drift_turn_boost", 1.0, 2.5, 0.05],
	["tight_turn_boost", 1.0, 3.0, 0.05],
	["tight_turn_drag", 0.0, 20.0, 0.5],
	["gravity_scale", 0.5, 4.0, 0.1],
	["air_control", 0.0, 1.0, 0.05],
	["upright_strength", 1.0, 30.0, 0.5],
	["suspension_hz", 0.8, 5.0, 0.1],
	["suspension_damping", 0.1, 1.5, 0.05],
	["turbo_speed_mult", 1.0, 2.0, 0.05],
	["turbo_thrust", 0.0, 60.0, 1.0],
	["turbo_kick", 0.0, 15.0, 0.5],
	["turbo_air_thrust", 0.0, 40.0, 1.0],
	["turbo_air_lift", 0.0, 15.0, 0.5],
]


static func from_dict(d: Dictionary) -> VehicleStats:
	var s := VehicleStats.new()
	s.apply_dict(d)
	return s


## Applies known keys from a dictionary. Nested sections ("drive": {...}) are flattened.
func apply_dict(d: Dictionary) -> void:
	var known := _property_names()
	for key in d.keys():
		var value: Variant = d[key]
		if typeof(value) == TYPE_DICTIONARY:
			if String(key) != "signature":   # the car's own special is read by SpecialWeapons
				apply_dict(value)
			continue
		var k := String(key)
		if k == "name":
			k = "display_name"
		elif k == "class":
			k = "vehicle_class"
		if not known.has(k):
			continue
		var current: Variant = get(k)
		if typeof(current) == TYPE_FLOAT:
			set(k, float(value))
		elif typeof(current) == TYPE_STRING:
			set(k, str(value))


## Flat dictionary of every tunable number, for saving tuning sessions.
func to_tuning_dict() -> Dictionary:
	var out := {}
	for entry in TUNABLE:
		out[entry[0]] = get(entry[0])
	return out


func duplicate_stats() -> VehicleStats:
	var copy := VehicleStats.new()
	for k in _property_names():
		copy.set(k, get(k))
	return copy


func _property_names() -> Dictionary:
	var names := {}
	for p in get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names[p["name"]] = true
	return names


## The "Grip" handling preset from the tuning panel: the car sheds speed fast when
## you let off, slides less and snaps straight sooner, for a tighter old-school
## arcade feel. Each value is scaled from the car's own numbers and kept inside
## the tuning ranges.
const GRIP_PRESET := {
	"coast_decel": 2.2,
	"brake_decel": 1.15,
	"grip": 1.25,
	"drift_grip": 1.6,
	"steer_return_time": 0.6,
	"yaw_response": 1.2,
}


func apply_grip_preset() -> void:
	for entry in TUNABLE:
		var key: String = entry[0]
		if GRIP_PRESET.has(key):
			set(key, clampf(float(get(key)) * float(GRIP_PRESET[key]), entry[1], entry[2]))
