# Architecture

The game splits into three layers so most of it can move to Unreal without a rewrite of the
design.

| Layer | Folder | Depends on Godot? | In an Unreal port |
| --- | --- | --- | --- |
| Data | `data/` | No (JSON) | Same files, imported into DataTables |
| Rules | `core/` | Only for small helpers (`move_toward`, `lerpf`) | Re-typed 1:1 in C++, checked by the same tests |
| Presentation | `game/` | Yes | Rebuilt with Unreal actors, materials, UMG |

## Rules (`core/`)

- `arcade_handling.gd`: the drive model. Takes stats, a `ControlFrame` (throttle, brake, steer,
  turbo) and the current `DriveState`, returns new forward speed, slide and target yaw rate.
  No physics engine calls.
- `combat_rules.gd`: health, machine gun heat, ram and splash damage, pickup effects.
- `combo_buffer.gd`: recognises D-pad combo sequences. Feed it directions with a timestamp; it
  answers with a move id when a sequence from `data/combos.json` completes inside the window.
- `status_effects.gd`: combo energy and per-move cooldowns, plus the timed shield, freeze and
  burn effects on a car.
- `vehicle_stats.gd`: every tuning number for a vehicle, loaded from JSON.
- `game_data.gd`: JSON loading and saved tuning sessions.

## Presentation (`game/`)

- `vehicle/arcade_vehicle.gd`: a `RigidBody3D`. Each physics step it casts four suspension rays,
  converts world velocity into car space, calls `ArcadeHandling.step`, and writes the result
  back. Rams are detected from sudden velocity changes and passed to `CombatRules`.
- `vehicle/vehicle_factory.gd`: builds a car from its data file (body, collider, visual, gun,
  engine sound).
- `input/`: per-player actions (`p1_accelerate`...) with Modern and Classic Xbox layouts. Built
  for up to four players, one pad each, for split-screen in Milestone 3.
- `weapons/combo_controller.gd`: reads the combo presses from the car's `ControlFrame`, runs
  them through `ComboBuffer`, spends energy and performs the move. Bots call `request_move()`.
- `weapons/special_weapons.gd`: special weapon ammo, cycling and firing.
- `weapons/projectile.gd`, `scrap_mine.gd`, `fire_pool.gd`: the things combos and specials
  leave in the world. Projectiles sweep a ray each step so fast shots don't pass through walls.
- `ai/drone_driver.gd`: Scrap Drone brain. Produces a `ControlFrame` like a player does, so bots
  and players drive through the same code.
- `camera/chase_camera.gd`, `weapons/machine_gun.gd`, `pickups/`, `props/`, `arena/`, `ui/`,
  `audio/`, `fx/`.
- `match/yard_match.gd`: the Milestone 1 sandbox (spawning, respawns, messages, menus).

## Physics

- Jolt physics, 60 ticks per second, physics interpolation on.
- Collision layers: 1 world, 2 vehicles, 3 pickups, 4 props.
- Suspension rays only hit the world layer, so cars ride over barrels physically, not on rays.

## Unreal port notes

1. Import `data/*.json` as DataTables with the same field names.
2. Port `core/` to C++ (`UArcadeHandling` as a static function library); port the tests and
   check the handling report matches within tolerance.
3. Build a custom movement component on a physics-simulated pawn: four line traces for suspension,
   then the same car-space conversion as `arcade_vehicle.gd`.
4. Map the Enhanced Input actions to the same names as `input/input_setup.gd`.
5. Rebuild visuals with the official art (glTF/FBX from the same source files).

Decide on the port after Milestone 3, once the Godot version is fun.
