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
- [ ] Witness/alarm system, police "heat" levels, hiding
- [ ] Lawful/Outlaw reputation, fence NPC buys stolen goods
### Sprint 3 - Cars
- [ ] Buyable drivable car (enter/exit, handling, fuel optional)
- [ ] Traffic basics, police chase
### Sprint 4 - Fishing and first job
- [ ] Fishing minigame at pond, fish sell prices
- [ ] Delivery job using car, pay on completion
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
