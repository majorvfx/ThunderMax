# Tuning the feel

Thunder Max's handling is our own arcade model (`core/arcade_handling.gd`). It aims for a 1990s
arcade combat feel: instant throttle, tight turns that loosen a little at speed, cars that stay
planted, hits that shove instead of flip, and jumps with a short hang.

## How to tune by feel

1. Start the Yard and press **F3** for the debug readout (speed, slide, steering, grounded).
2. Open the tuning panel with **View** (or F1). Change one number, close with **B**, drive.
3. When it feels right, **Save** (keeps it on this machine) or **Copy** (paste into
   `data/vehicles/rustjaw.json` so it ships).
4. Run the tests: they re-measure the handling and update `docs/handling_report.md`. If you
   deliberately move outside a target window, widen it in `data/handling_targets.json`.

### Comparing against another game

You can play any game you own side by side and match how ours *feels*: time to top speed with a
stopwatch, how many car lengths it takes to stop, how wide a full-lock U-turn is, how long a jump
hangs. Turn those observations into our numbers below.

We do not take code, data tables or constants from another game or from projects built from
another game's code (such as recompilations or decompilations). Our numbers come from our own
measurements and tuning sessions, so the handling stays ours.

## What each number does

| Number | Raise it to... | Lower it to... |
| --- | --- | --- |
| `max_speed` | go faster | go slower |
| `accel` | launch harder | launch softer |
| `accel_falloff` | make the last stretch to top speed slower (0 = linear pull) | keep pulling hard all the way |
| `brake_decel` | stop in fewer car lengths | brake softer |
| `coast_decel` | slow down faster off the throttle | roll further |
| `turn_rate_deg` | turn sharper everywhere | turn wider |
| `high_speed_turn_scale` | keep turning sharp at top speed | make top speed turns wider |
| `pivot_turn` | let a stopped car swing its nose more | need rolling speed to turn |
| `steer_ramp_time` | make D-pad steering build up slower (smoother) | make D-pad steering snappier |
| `steer_return_time` | slow the re-centre | snap back to centre |
| `analog_steer_curve` | make small stick moves gentler | make the stick more direct |
| `yaw_response` | make the car follow steering instantly | add a little delay and weight |
| `grip` | stay more planted | slide more |
| `drift_grip` | make power slides tighter | make power slides longer and looser |
| `drift_turn_boost` | rotate faster in a power slide | rotate slower in a power slide |
| `tight_turn_boost` | swing round harder on the tight turn button | gentler tight turns |
| `tight_turn_drag` | tight turns scrub off more speed | tight turns keep more speed |
| `gravity_scale` | shorter, punchier jumps | floatier jumps |
| `air_control` | steer more in the air | steer less in the air |
| `upright_strength` | resist tipping harder | allow more body roll |
| `suspension_hz` | stiffer ride | softer, bouncier ride |
| `suspension_damping` | settle faster after bumps | bounce more |
| `turbo_speed_mult` | faster turbo top speed | slower turbo top speed |
| `turbo_accel_mult` | harder turbo kick | softer turbo kick |

## Frame rate and feel

Physics always runs at 60 ticks per second, whatever the display frame rate. A 30 fps display
(Auto on slower machines, or forced in the pause menu) shows the same handling, smoothed by
physics interpolation, so tuning done at 60 fps holds at 30.
