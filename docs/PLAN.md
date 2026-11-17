# Plan (source of truth for what to build next)

All features chosen by the owner are kept; this only orders them. Tone: lighthearted, funny. PC only. Singleplayer first. Stylised low-poly 3D, third-person.

## Phase 0 - Prototype (DONE, v0.3)
Farm loop, tree chopping, store, sell bin, day/night, save/load, toon graphics, Low/High modes.

## Phase 1 - Vertical slice (CURRENT)
Mark each item [x] when done and tested.
### Sprint 1 - Buildings and people
- [x] Enterable buildings (player house, store, 3+ town homes) with interiors, doors, indoor lighting (v1: placeholder box rooms, 5 interiors; needs furniture/art pass)
- [x] Bed moved indoors (sleep = advance day)
- [x] NPCs with daily routines (wake, work, home, sleep) using game clock (3 townsfolk; data-driven per-NPC schedules still to do)
- [x] Tests for door/enter/exit and NPC schedule
### Sprint 2 - Robbery and reputation
- [x] Lockpick minigame, loot containers in homes, carry limit (v1: timing lockpick via E, prompt-text meter; drawer in each town home; carry limit 4; visual HUD meter still to do)
- [x] Witness/alarm system, heat levels (v1: view-cone suspicion meter per NPC while picking, heat 0-3 decaying 1/day, HUD label; police response + hiding still to do)
- [x] Lawful/Outlaw reputation, fence NPC buys stolen goods (v1: Shady Sal behind town buys loot at 50% +4%/Outlaw point; rep -10..10 saved; farm sales +0.5, fencing -1/item, alarm -1/heat; HUD shows title; police/hiding still to do)
- [x] Police response (v1: Constable Bumble patrols town at heat 3, chases on sight at 6.4 speed, arrest = lose loot + 25% cash fine, heat drops to 1; hiding indoors makes him lose you; crouch/shadow hiding and closets still to do)
### Sprint 3 - Cars
- [x] Buyable drivable car (v1: Honest Hank's dealer at (14,0,10.5), $400 sedan, E to enter/exit, WASD + Space handbrake, bicycle-model steering, thud on collision, parked position saved; fuel/engine sound/headlights still to do)
- [x] Traffic basics (v1: 3 ambient TrafficCars loop two lanes of the town road, brake for anything ahead, wrap at ends; police car chase still to do)
- [x] Police car chase at heat 3 (v1: PoliceCar squad car spawns on the road ahead when heat 3 and player is driving, pure pursuit steering cruise 15 vs player top 18, catch = arrest, despawns when you hide or get 70m away; sirens/roadblocks/collisions still to do)
### Sprint 4 - Fishing and first job
- [x] Fishing minigame at pond, fish sell prices (v1: Fishing logic cast/wait/bite window 1s, FishingSpot on east pond shore at (-17.8,?,1), 6 catches incl. boot/golden carp/wizard hat sold at bin; rods/bait/fish sizes still to do)
- [x] Delivery job using car, pay on completion (v1: Parcel Pete at (19,0,10.5) needs owned car, 4 drop-offs with beacon, timer, tip for speed; job state not saved; HUD timer/arrow still to do)
- [x] 2+ more crops, shop stock (v1: carrot 3 nights/$70, tomato 4 nights/$125 alongside turnip 2/$35; press [2] again to cycle seed type; shop sells the selected seed; per-crop seed prices $10/$18/$30; shop stock limits and crop art per growth stage still to do)
### Sprint 5 - Polish
- [ ] Sound effects + music (CC0 packs from GitHub), audio settings (AudioSettings logic + tests DONE; v1 procedural SFX DONE: coin/spend/blip/thud via Sfx node; pause/settings menu with volume sliders DONE (ESC); +-5% pitch variance DONE; v1 chop/footstep/splash SFX DONE (distance-based steps); v1 car engine loop DONE (pitch/volume from speed); music and surface-dependent footsteps still to do)
- [ ] Main menu, settings, tutorial, controller basic support (settings DONE via ESC menu; v1 tutorial hints DONE: 5 event-driven tips on new games; controller basic support DONE (gamepad bindings + right-stick camera, 0.2 deadzone); main menu, on-screen pad prompts and pad-navigable ESC menu still to do)
- [ ] Demo-ready build

## Phase 2 - Earth Early Access: larger town, building your own house, animals (catch/keep/resources), clothes, weapons/combat, car building, more jobs, racing.
## Phase 3 - Rocket + Moon open world.
## Phase 4 - Jungle planet with dinosaurs, catchable and usable.
## Phase 5 - Beyond: more planets, endgame, Steam launch.

## Improvement backlog (research-driven; append ideas here, pick 1 small one per run)
- Surface-aware footsteps (grass/wood floor/road) via ground raycast group lookup (Godot 4 reactive footsteps idea, itch.io blog); car engine pitch from speed
- Audio: sfxr-style parameter presets (GodotSfxr/gdfxr exist) for chop, splash, lockpick click, car engine pitch via AudioStreamGenerator; randomise pitch +-5% per play to avoid repetition
- Performance profiling pass for High mode
- Funny writing: NPC barks, item descriptions, news ticker
- Accessibility options (colour-blind, subtitles, key rebinding)
- Data-driven NPC schedules (list of {from_hour, to_hour, place}) so each NPC can have custom routines, shop hours and events (idea from Godot forum schedule threads)
- Interior polish: furniture props from KayKit packs, door open animation, fade-to-black on enter/exit
- NPC dialogue barks + shop closing hours tied to the keeper
- Witness system: gradual suspicion meter (fills faster when close/in view cone, decays when out of sight) instead of instant detection; cone + distance scaling (research: stealth-game spotting write-ups, Klei alarm design)
- Lockpick HUD: replace text bar with on-screen meter + sound click per pin
- Hiding: crouch/shadow reduces witness fill rate; closets in homes (follow-up to witness meter)
- Heat consequences: police NPC patrol at heat 3, shop price penalty at heat 2
- Fence price should drop when heat is high (fences get nervous) and fence stock/daily cap to avoid dumping (research: stolen-goods design threads)
- Reputation effects: Lawful gets shop discount, Outlaw gets fence bonus + townsfolk barks
- Police heat cooling: heat should only decay once you are out of sight of police (search-and-lose, as in modern wanted-system write-ups), not just by day count
- Police: add a second constable / car patrol once Sprint 3 cars land; crouch + shadows hiding still to do
- Car follow-ups: speed-sensitive FOV/camera lag, tyre-screech dust particles, headlights at night, fuel (optional), traffic AI with lane waypoints, cops chase by car at heat 3 (Sprint 3 part 2)
- Fishing follow-ups: bobber visual + splash/sound cue on bite, rod upgrades and bait, fish by time of day/weather, fish size and a journal (research: fishing minigame taxonomy write-ups; keep a forgiving bite window for cozy feel)
- Delivery follow-ups: HUD countdown + direction arrow, chained deliveries/streak bonus, fragile parcels that lose pay on collisions (research: courier-game reviews e.g. Easy Delivery Co: short cozy shifts, odd customers)
- Crops follow-ups: seasonal crops, regrowing crops (tomato yields several harvests), quality tiers, crop-specific growth models (research: cozy farm games balance by growth days vs price; longer crops pay more per day)
- Delivery HUD: DONE v1 (text line with timer, distance, compass, tip); a 3D/screen-space arrow still nice-to-have
- Idea (2026-11-17): traffic via simple looping waypoint cars before police car chase
- Traffic follow-ups (2026-11-17 research: waypoint/lane following is the standard cheap approach): honk + swerve when the player jumps out, traffic reacts to heat/police, junction turns via waypoint graph, vary colours/speeds
- Police car follow-ups (2026-11-17 search returned links only): siren light flash + sound, roadblocks/PIT, squad car avoids buildings (needs nav), spawn behind player offscreen
- Tutorial follow-ups (2026-11-17): hint on first lockpick/fishing/car, skippable in settings, on-screen key icons instead of text, controller prompts
- Controller follow-ups (2026-11-17, Godot docs: use InputMap actions + per-action deadzone): pad button prompts in tutorial/HUD when a pad is detected, pad navigation of settings sliders, vibration on car bump, rebinding UI
- Audio follow-ups (2026-11-17 search: links only; Godot AudioStreamGenerator + pitch_scale from speed is the common approach): engine gear-shift pitch drops, tyre screech on handbrake, music from a CC0 github repo
