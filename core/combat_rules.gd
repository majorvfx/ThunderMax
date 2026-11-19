class_name CombatRules
extends RefCounted
## Engine-agnostic combat rules: health, machine gun heat, ram damage, pickups.


## Hit points for anything that can be wrecked.
class Health:
	var max_health := 100.0
	var current := 100.0

	func _init(max_hp: float = 100.0) -> void:
		max_health = max_hp
		current = max_hp

	func is_dead() -> bool:
		return current <= 0.0

	func fraction() -> float:
		return clampf(current / maxf(max_health, 0.001), 0.0, 1.0)

	## Returns the damage actually taken.
	func damage(amount: float) -> float:
		if amount <= 0.0 or is_dead():
			return 0.0
		var before := current
		current = maxf(0.0, current - amount)
		return before - current

	## Returns the health actually restored.
	func heal(amount: float) -> float:
		if is_dead():
			return 0.0
		var before := current
		current = minf(max_health, current + amount)
		return current - before

	func reset() -> void:
		current = max_health


## Machine gun: unlimited ammo, limited by heat. Overheating locks the gun until it cools.
class GunState:
	var fire_interval := 0.1
	var damage := 1.5
	var heat_per_shot := 0.045
	var cool_rate := 0.4
	var recover_below := 0.35
	var range_m := 90.0
	var aim_assist_deg := 7.0
	var spread_deg := 0.8
	var heat := 0.0
	var overheated := false
	var _cooldown := 0.0

	func configure(d: Dictionary) -> void:
		for key in d.keys():
			var k := String(key)
			if k in ["fire_interval", "damage", "heat_per_shot", "cool_rate", "recover_below", "range_m", "aim_assist_deg", "spread_deg"]:
				set(k, float(d[key]))

	## Advances the gun by dt. Returns how many shots fire this step.
	func tick(dt: float, trigger: bool) -> int:
		_cooldown = maxf(0.0, _cooldown - dt)
		var shots := 0
		if trigger and not overheated:
			while _cooldown <= 0.0 and not overheated:
				shots += 1
				_cooldown += fire_interval
				heat += heat_per_shot
				if heat >= 1.0:
					heat = 1.0
					overheated = true
		else:
			heat = maxf(0.0, heat - cool_rate * dt)
			if overheated and heat <= recover_below:
				overheated = false
		return shots


## Damage from a sudden change in velocity (a ram, a wall hit).
## dv: change in horizontal velocity this step (m/s).
static func impact_damage(dv: float, attacker_power: float, defender_armor: float, threshold: float = 7.0, scale: float = 1.2) -> float:
	if dv <= threshold:
		return 0.0
	return (dv - threshold) * scale * attacker_power / maxf(defender_armor, 0.05)


## Explosion damage with linear falloff to zero at the edge of the radius.
static func splash_damage(distance: float, radius: float, max_damage: float) -> float:
	if distance >= radius:
		return 0.0
	return max_damage * (1.0 - distance / radius)


## Pickup effects. Returns true when the pickup was used (it is left alone if it would do nothing).
static func apply_pickup(kind: String, amount: float, health: Health, drive: ArcadeHandling.DriveState, turbo_capacity: float) -> bool:
	match kind:
		"health":
			if health.current >= health.max_health:
				return false
			health.heal(amount)
			return true
		"turbo":
			if drive.turbo >= turbo_capacity:
				return false
			drive.turbo = minf(turbo_capacity, drive.turbo + amount)
			return true
	return false
