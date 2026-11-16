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
- [ ] Traffic basics, police chase
### Sprint 4 - Fishing and first job
- [x] Fishing minigame at pond, fish sell prices (v1: Fishing logic cast/wait/bite window 1s, FishingSpot on east pond shore at (-17.8,?,1), 6 catches incl. boot/golden carp/wizard hat sold at bin; rods/bait/fish sizes still to do)
- [x] Delivery job using car, pay on completion (v1: Parcel Pete at (19,0,10.5) needs owned car, 4 drop-offs with beacon, timer, tip for speed; job state not saved; HUD timer/arrow still to do)
- [ ] 2+ more crops, shop stock
### Sprint 5 - Polish
- [ ] Sound effects + music (CC0 packs from GitHub), audio settings
- [ ] Main menu, settings, tutorial, controller basic support
- [ ] Demo-ready build

## Phase 2 - Earth Early Access: larger town, building your own house, animals (catch/keep/resources), clothes, weapons/combat, car building, more jobs, racing.
## Phase 3 - Rocket + Moon open world.
## Phase 4 - Jungle planet with dinosaurs, catchable and usable.
## Phase 5 - Beyond: more planets, endgame, Steam launch.

## Improvement backlog (research-driven; append ideas here, pick 1 small one per run)
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
