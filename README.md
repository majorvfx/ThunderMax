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

Two pad layouts; switch between them in the pause menu. Your choice is saved. **Classic** is
the default: the D-pad steers and also enters the combo moves.
Every action can also be remapped (see **Remapping** below); the table shows the defaults.

| Action | Classic (default) | Modern | Keyboard |
| --- | --- | --- | --- |
| Accelerate | A | RT | W / Up |
| Brake, then reverse | X | LT | S / Down |
| Steer | D-pad or left stick | Left stick | A, D / Left, Right |
| Machine gun | B | RB | Space |
| Special weapon | Y | X | F |
| Turbo | LT | A | Shift |
| Look back | RT | B | C |
| Previous / next special | LB / RB | LB / Y | Q / E |
| Combo moves | D-pad | D-pad | I, K, J, L (up, down, left, right) |
| Combo hold (for held moves) | RT | RT | Ctrl |
| Pause | Menu | Menu | Esc |
| Handling tuning panel | View | View | F1 |
| Debug readout | | | F3 |
| Fullscreen | | | F11 |

**Classic** puts the driving on the face buttons the way 1990s pads did, and D-pad steering
ramps in over a fraction of a second instead of snapping to full lock. The left stick steers
too. **Modern** uses the analog triggers for throttle and brake and the stick for steering.

**Power slide:** hold brake and steer at speed. A dedicated drift control is planned for a
later milestone.

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
everything else. In the Classic layout the D-pad also steers; only the exact sequences above
fire a move, and every one has an Up or Down in it, so steering taps alone never fire one.

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
seconds, cancels. Controller remaps are kept separately for Modern and Classic, and keyboard
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
