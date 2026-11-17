# Demo smoke checklist (15 minutes, run on the exported Windows build)
Automated (every run): `tests/run_tests.gd` (unit), `tests/smoke_boot.gd` (main scene boots 120 frames), Windows export succeeds.

Manual, by the owner on Windows:
1. Launch: title menu shows, Continue/New Game/Quit work with mouse, keys and pad.
2. New game: tutorial tips appear in order; first 5 minutes understandable.
3. Farm loop: plant, water, sleep, harvest, sell at bin; money goes up.
4. Enter/exit houses and store; doors, lighting, bed sleep.
5. Lockpick a drawer, get heat, see Constable Bumble; fence loot at Shady Sal.
6. Buy car at Honest Hank's, drive, exit, traffic and police car behave.
7. Fish at the pond; delivery job from Parcel Pete.
8. ESC menu: volume sliders, resume; save, quit, Continue restores state.
9. Audio: SFX, footsteps, engine, day/night music; no clipping.
10. Performance: Low and High modes hold a steady frame rate; no crashes in 15 min.
Record failures in docs/PLAYTEST.md.
