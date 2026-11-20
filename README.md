# Thunder Max: Metal Road

An original vehicular-combat arena game: dark, serious, with a little dark humor.
Built in Godot 4, structured so the game rules and data can move to Unreal later.

This build is **Milestone 1 (first playable)** plus the first part of **Milestone 2 (core
combat)**: one car, one arena, the machine gun, D-pad combo moves with an energy meter, pickup
special weapons, drones that fight back, Xbox controller support, and the arcade handling model
with a live tuning panel. All art and audio are placeholders made in code.

![Title](docs/screenshots/title.png)

## Run it

1. Install **Godot 4.7** (standard build, not .NET) from <https://godotengine.org/download>.
2. Open Godot, choose **Import**, and select this folder's `project.godot`.
3. Plug in your Xbox controller (USB or Bluetooth), then press **F5** (or the Play button).

To skip the editor, run the game directly:
`Godot_v4.7.2-stable_win64.exe --path "C:\path\to\ThunderMax"` (a `.bat` file with that line
works as a desktop shortcut).

Press **A** or **Enter** on the title screen. You start in the Foundry Yard in Rustjaw, with
three Scrap Drones running laps. Get close and they turn on you. Wreck them, grab pickups and
weapon crates, set off the fuel drums.

## Controls

Five pad layouts; switch between them in the pause menu (**Controls**). Your choice is saved.
**Standard** is the default. The first four are the classic 1990s arcade-combat pad layouts,
moved to the Xbox pad button for button (Cross = A, Circle = B, Square = X, Triangle = Y,
L1/R1 = LB/RB, L2/R2 = LT/RT, Select = View, Start = Menu). In those four **the D-pad drives**
(up is gas, down is brake, left and right steer) **and enters the combo moves**. Every action
can also be remapped (see **Remapping** below); the tables show the defaults.

| Action | Standard (default) | Alternate 1 | Alternate 2 | Shoulders |
| --- | --- | --- | --- | --- |
| Gas | X / D-pad up | A / D-pad up | A / D-pad up | RT / D-pad up |
| Brake, then reverse | B / D-pad down | LT / D-pad down | LT / D-pad down | RB / D-pad down |
| Steer | D-pad left / right (or left stick) | same | same | same |
| Turbo | Y | Y | Y | LB |
| Tight turn | A | RT | RT | LT |
| Next special | RB | RB | RB | Y |
| Previous special | LB | LB | LB | B |
| Fire special | LT | B | X | A |
| Machine guns | RT | X | B | X |
| Combo moves | D-pad | D-pad | D-pad | D-pad |
| Combo hold (for held moves) | RT | RT | RT | RT |
| Pause | View (or tap Menu) | same | same | same |
| Change view (chase, far chase, hood) | Menu + D-pad up / down | same | same | same |
| Radar | Menu + D-pad left | same | same | same |
| Rear-view mirror | Menu + D-pad right | same | same | same |
| Enemies left | Menu + A | same | same | same |
| Look back | Right stick click | same | same | same |
| Handling tuning panel | Left stick click | same | same | same |

**Modern** is our own stick-and-trigger layout: RT gas, LT brake, left stick steers, A turbo,
B tight turn, RB machine guns, X special, LB / Y previous / next special, right stick click look
back, Menu pause, and View held with the D-pad for views, radar and mirror. The D-pad is for
combos only.

| Action | Keyboard |
| --- | --- |
| Gas / brake / steer | W, S, A, D (or the arrow keys) |
| Tight turn | X |
| Machine guns / fire special | Space / F |
| Previous / next special | Q / E |
| Turbo / look back | Shift / C |
| Combo moves / combo hold | I, K, J, L (up, down, left, right) / Ctrl |
| Change view / radar / mirror / enemies left | V / R / M / Tab |
| Pause / tuning panel / debug readout / fullscreen | Esc / F1 / F3 / F11 |

D-pad steering ramps in over a fraction of a second instead of snapping to full lock, and the
left stick also steers in every layout. While Menu is held, D-pad presses are view controls,
not combo presses (they still nudge the gas, brake or steering).

**Tight turn** swings the car round hard: hold it and steer. At full speed it whips you round
180 degrees in under a second, scrubbing off speed as it goes, so you can face whoever is
chasing you. **Power slide:** hold brake and steer at speed for a longer, looser drift.

### Combo moves

Tap a D-pad sequence quickly (each press within about half a second of the last). Each move
costs combo energy (the ENERGY bar at the bottom of the status panel), which refills on its
own. The notches on the bar are 25 energy apart. Your presses show as arrows at the bottom of
the screen while you enter them, and the pause menu lists every move.

| Move | Xbox inputs | Keyboard | Energy | What it does |
| --- | --- | --- | --- | --- |
| Scrap Mine | Right, Left, Down | L, J, K | 25 | Drops a spiked mine behind you. It blows up the next car to touch it (three out at a time). |
| Cold Snap | Left, Right, Up | J, L, I | 35 | Coolant round that freezes the car it hits for about 2 seconds. Aims at your lock-on target. |
| Spring Jack | Up, Up, Left | I, I, J | 25 | Hydraulic jump. Hop walls, dodge mines. Ground only. |
| Rivet Storm | Hold RT + Up, Down, Left, Right, Right, Left, Down, Up | Hold Ctrl + I, K, J, L, L, J, K, I | 50 | For 4 seconds the guns fire twice as fast, hit 1.5 times harder and never overheat. |
| Fire Jug | Right, Left, Up | L, J, I | 35 | Lobs a jug of fuel ahead that leaves a burning pool. Cars in it catch fire. |
| Tailgunner | Left, Right, Down | J, L, K | 25 | Heavy round out the back, aimed at whoever is behind you. |
| Blackout | Right, Down, Left, Up | L, K, J, I | 40 | Black smog: for 4 seconds nothing can lock on to you, Seekers lose you and drones can't find you. Firing ends it. |
| Bulwark | Up, Up, Right | I, I, L | 50 | Force field: no damage for 3 seconds. Puts out fire and thaws ice. |

**Held moves:** Rivet Storm only works with RT held while you enter the code. Holding RT also
keeps a short code inside the long one (Right, Left, Down is in there) from dropping a mine
partway through. Short moves still work with RT held, so in the Modern layout you can keep
accelerating while you use them.

A frozen car can't drive, fire specials or use combos. The combo directions and the hold are
their own actions (Combo up/down/left/right, Combo hold), so they can be remapped like
everything else. In the D-pad layouts the same presses also drive (an Up in a code is a quick
tap of gas); only the exact sequences above fire a move, and every one has an Up or Down in it,
so steering taps alone never fire one. In Standard, RT is also the machine guns, so the guns
fire while you hold it for Rivet Storm.

Names, inputs, costs and effects all live in `data/combos.json`, so new moves can be added
there.

### Special weapons

Weapon crates (yellow band) give two shots of a random special. Hold up to six of each, switch
with previous / next special, and fire with the special button.

| Special | What it does |
| --- | --- |
| Seeker | Homing missile; follows your lock-on target. |
| Firebrand | Fast incendiary round; sets the target alight. |
| Sledge | Slow, heavy rocket that fires straight and shoves what it hits. |

Their numbers live in `data/specials.json`.

![Bulwark and a combo in progress](docs/screenshots/combo_bulwark.png)

### Remapping

Pause, then choose **Remap controls**. Every action has a controller column and two keyboard
columns (main and alt key). Pick a cell with the D-pad or mouse, press **A** / **Enter**, then
press the new button, trigger, stick direction or key. If another action already used it, the two
swap, so nothing is ever left doubled up. **Backspace** clears a key; **Esc**, or waiting five
seconds, cancels. Controller remaps are kept separately for each layout, and keyboard
remaps apply to both. **Reset to defaults** (press twice) restores the current layout and the
keyboard. Everything is saved to `user://settings.cfg` straight away.

Analog steering follows whatever stick is bound to Steer left / right, so you can move steering
to the right stick.

![Remap controls](docs/screenshots/remap_controls.png)

## What's in Milestone 2 so far

- **Eight combo moves** on the D-pad with an energy meter, including a held long code (see above).
- **Three special weapons** from weapon crates, with ammo per weapon and cycling.
- **Status effects**: shielded, frozen, burning, cloaked and Rivet Storm, shown on the car and
  on the HUD.
- **Scrap Drones fight back**: they hunt you when you're close, fire their guns in bursts,
  drop mines or fire a Tailgunner round when you chase them, raise Bulwark when hurt, and throw
  Cold Snaps. They lose you while you're under Blackout.

Still to come in Milestone 2: more cars with their own specials, a second arena with
destructible scenery, and bot difficulty levels.

![Cold Snap](docs/screenshots/cold_snap.png)

## What's in Milestone 1

- **Rustjaw**, a plow-nosed coupe, with raycast suspension and our own arcade handling model.
- **The Foundry Yard**, a 160 m walled steelworks: a raised furnace deck with ramps, container
  cover, a kicker jump in the east lane, fuel drums that explode, and a hidden pocket in the
  north-west corner.
- **Twin Rivet Guns** with unlimited ammo and an overheat bar, light aim assist and a lock-on
  bracket.
- **Scrap Drones**: driverless cars that lap the yard.
- **Pickups**: Patch Kits (armor), Nitro Cans (turbo) and, from Milestone 2, weapon crates.
- **Ram damage** from hard hits, rumble on big hits, wreck and respawn.
- **Frame rate**: physics always runs at 60 Hz. Display is Auto (60, dropping to a steady 30 on
  slower machines), 30, or 60. Graphics presets Low, Medium, High.
- **Tuning panel** (View button) to change handling numbers live, save them, or copy them out.

## Tuning the handling

Open the tuning panel with **View**. Pick a number with the D-pad, change it with left/right,
close with **B**, and drive. **Save** keeps your numbers in your user folder for next time; **Copy**
puts them on the clipboard so they can go into `data/vehicles/rustjaw.json` for everyone.
See [docs/FEEL_TUNING.md](docs/FEEL_TUNING.md) for what each number does and how to tune by feel.

The current measured numbers are in [docs/handling_report.md](docs/handling_report.md).

## Tests

```sh
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd
```

The suite checks the rules (damage, heat, pickups, input layouts, remapping, combo recognition,
energy and status effects), measures the handling on a test pad against
`data/handling_targets.json`, fires every combo move and a special on the test pad, and runs a
smoke test in the arena (drones keep lapping, drones hunt and damage the player, the gun wrecks a
drone, pickups heal). It rewrites `docs/handling_report.md`.

## Project layout

| Folder | What lives there |
| --- | --- |
| `core/` | Engine-agnostic rules: handling model, combat rules, combo recognition, status effects, stats, data loading |
| `data/` | Vehicles, weapons, combo moves, specials, pickups and handling targets as JSON |
| `game/` | Godot layer: vehicle body, camera, input, arena, UI, audio, effects |
| `assets/audio/` | Placeholder sounds and music (regenerate with `tools/make_placeholder_audio.py`) |
| `tests/` | Headless test suite |
| `tools/` | Placeholder audio generator, screenshot tool |
| `docs/` | Architecture, Unreal port notes, tuning guide, handling report, screenshots |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit and how the Unreal
port would work.

## Exporting

Add export templates in Godot (Editor > Manage Export Templates), then Project > Export.
In each preset, set **Resources > Filters to export non-resource files** to `data/*.json`
so the game data ships with the build.

- **Windows / Linux / Steam Deck:** standard desktop presets.
- **iPad:** needs a Mac with Xcode and an Apple developer account. Xbox controllers pair with
  iPad over Bluetooth and work in-game. Touch controls are not in this build. The Mobile
  renderer and Low graphics preset are meant for iPad.

## Placeholders

Every model, texture, sound and the music loop in this build is a placeholder generated in
code. Official art and audio will replace them; the vehicle and arena code doesn't depend on
the placeholder shapes.
