class_name StatusEffects
extends RefCounted
## Timed effects on a vehicle and its combo energy. Engine-agnostic.

var energy := 100.0
var energy_max := 100.0
var energy_regen := 6.0
var shield_time := 0.0
var frozen_time := 0.0
var burn_time := 0.0
var burn_dps := 0.0
var burn_source: Object = null
var cloak_time := 0.0        ## Blackout: can't be locked on or tracked
var overdrive_time := 0.0    ## Rivet Storm: faster, harder-hitting guns, no heat
var _cooldowns := {}


func configure(max_energy: float, regen: float) -> void:
	energy_max = max_energy
	energy_regen = regen
	energy = max_energy


func reset() -> void:
	energy = energy_max
	shield_time = 0.0
	frozen_time = 0.0
	burn_time = 0.0
	burn_dps = 0.0
	burn_source = null
	cloak_time = 0.0
	overdrive_time = 0.0
	_cooldowns.clear()


func is_shielded() -> bool:
	return shield_time > 0.0


func is_frozen() -> bool:
	return frozen_time > 0.0


func is_burning() -> bool:
	return burn_time > 0.0


func is_cloaked() -> bool:
	return cloak_time > 0.0


func is_overdriven() -> bool:
	return overdrive_time > 0.0


## Advances timers. Returns burn damage dealt this step.
func tick(dt: float) -> float:
	energy = minf(energy_max, energy + energy_regen * dt)
	shield_time = maxf(0.0, shield_time - dt)
	frozen_time = maxf(0.0, frozen_time - dt)
	cloak_time = maxf(0.0, cloak_time - dt)
	overdrive_time = maxf(0.0, overdrive_time - dt)
	for k in _cooldowns.keys():
		_cooldowns[k] = maxf(0.0, _cooldowns[k] - dt)
	if burn_time <= 0.0:
		return 0.0
	var step := minf(dt, burn_time)
	burn_time -= step
	if burn_time <= 0.0:
		burn_source = null
	return burn_dps * step


## Spends energy for a move if it is affordable and off cooldown.
func try_spend(move_id: String, cost: float, cooldown: float) -> bool:
	if _cooldowns.get(move_id, 0.0) > 0.0 or energy < cost:
		return false
	energy -= cost
	_cooldowns[move_id] = cooldown
	return true


func can_afford(cost: float) -> bool:
	return energy >= cost


func freeze(seconds: float) -> void:
	if is_shielded():
		return
	frozen_time = maxf(frozen_time, seconds)


func ignite(seconds: float, dps: float, source: Object) -> void:
	if is_shielded():
		return
	burn_dps = maxf(burn_dps, dps) if burn_time > 0.0 else dps
	burn_time = maxf(burn_time, seconds)
	burn_source = source


func shield(seconds: float) -> void:
	shield_time = maxf(shield_time, seconds)
	burn_time = 0.0
	frozen_time = 0.0


func cloak(seconds: float) -> void:
	cloak_time = maxf(cloak_time, seconds)


## Ends Blackout early (the car fired, so it gave itself away).
func reveal() -> void:
	cloak_time = 0.0


func overdrive(seconds: float) -> void:
	overdrive_time = maxf(overdrive_time, seconds)
