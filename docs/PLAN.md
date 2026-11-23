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
- [x] Police response (v1: Constable Bumble patrols town at heat 3, chases on sight at 6.4 speed, arrest = lose loot + 25% cash fine, heat drops to 1; hiding indoors makes him lose you; crouch/shadow hiding DONE; closets DONE v1)
### Sprint 3 - Cars
- [x] Buyable drivable car (v1: Honest Hank's dealer at (14,0,10.5), $400 sedan, E to enter/exit, WASD + Space handbrake, bicycle-model steering, thud on collision, parked position saved; fuel/engine sound still to do; headlights DONE v1; tyre dust puffs DONE v1)
- [x] Traffic basics (v1: 3 ambient TrafficCars loop two lanes of the town road, brake for anything ahead, wrap at ends; police car chase still to do)
- [x] Police car chase at heat 3 (v1: PoliceCar squad car spawns on the road ahead when heat 3 and player is driving, pure pursuit steering cruise 15 vs player top 18, catch = arrest, despawns when you hide or get 70m away; sirens/roadblocks/collisions still to do)
### Sprint 4 - Fishing and first job
- [x] Fishing minigame at pond, fish sell prices (v1: Fishing logic cast/wait/bite window 1s, FishingSpot on east pond shore at (-17.8,?,1), 6 catches incl. boot/golden carp/wizard hat sold at bin; rods/bait/fish sizes still to do)
- [x] Delivery job using car, pay on completion (v1: Parcel Pete at (19,0,10.5) needs owned car, 4 drop-offs with beacon, timer, tip for speed; job state not saved; HUD timer/arrow still to do)
- [x] 2+ more crops, shop stock (v1: carrot 3 nights/$70, tomato 4 nights/$125 alongside turnip 2/$35; press [2] again to cycle seed type; shop sells the selected seed; per-crop seed prices $10/$18/$30; shop stock limits and crop art per growth stage still to do)
### Sprint 5 - Polish
- [ ] Sound effects + music (CC0 packs from GitHub), audio settings (AudioSettings logic + tests DONE; v1 procedural SFX DONE: coin/spend/blip/thud via Sfx node; pause/settings menu with volume sliders DONE (ESC); +-5% pitch variance DONE; v1 chop/footstep/splash SFX DONE (distance-based steps); v1 car engine loop DONE (pitch/volume from speed); v1 surface-dependent footsteps DONE (grass/wood interiors/road by position); v1 procedural day/night background music DONE (Music node, Music bus); CC0 recorded music still optional; music day/night 3s equal-power crossfade DONE; pad-navigable ESC menu v1 DONE (first slider grabs focus on open))
- [ ] Main menu, settings, tutorial, controller basic support (settings DONE via ESC menu; v1 tutorial hints DONE: 5 event-driven tips on new games; controller basic support DONE (gamepad bindings + right-stick camera, 0.2 deadzone); v1 main menu DONE (title screen: Continue/New Game/Quit, pauses tree, pad-focusable); v1 pad/key prompts DONE (InputPrompts tracks last device, tutorial tips use {action} tokens); HUD interact prompts DONE ([E] tag swaps to pad label); help panel prompts DONE (live-swapping tokens))
- [ ] Demo-ready build (v1 groundwork DONE: boot smoke test tests/smoke_boot.gd, Windows export verified working with 4.7.1 templates (116MB exe), docs/DEMO_CHECKLIST.md; demo-shell Send Feedback button DONE (opens GitHub issues; wishlist link once a Steam page exists); still to do: owner manual smoke pass, release zip + READ_ME)

## Phase 1.6 - Depth, feel and story (owner request 2026-11-18; keep ALL core ideas, this adds to them)
Goal: make the sandbox feel like the best of the genre (Stardew Valley, Core Keeper, Terraria, Palworld, GTA-lite, Cassette Beasts) while keeping the lighthearted shovel-to-starship idea. Every run: at least one item from "Feel" and one from "Graphics/Physics", plus one from "Make things".
### Gather and break (physics-based)
- [ ] (v1 DONE 2026-11-19: 3 real RigidBody3D logs tumble out when the trunk lands, bounce, magnet to you within 2.6m and add wood; still to do: fall as rigid body, chop logs into planks, stump regrow already works) Tree felling: chopping hits fill a damage meter, then the tree FALLS as a rigid body in the chop direction, splits into logs (RigidBody3D), logs can be chopped again into planks/firewood, stump remains and regrows over days
- [ ] (v1 DONE: WoodLog pickup w/ arm delay, magnet, collect pop; reuse for stone/ore/herbs) Pick up anything from the ground (E / auto-magnet when close): logs, stones, ore, herbs, dropped items with bounce, pop and a small pickup arc
- [ ] (v1 DONE 2026-11-19: Pickaxe tool [5], 5 MineRock rocks, 4 hits with shake/shrink/sparks/hit-stop, break into rigid-body stone/copper/gem chunks, regrow 3 days; still to do: pickaxe tiers, mine area/caves, selling/using ore) Mining: ore rocks with hit stages that crack and break into chunks/ore pieces (rigid bodies), pickaxe tiers, small caves/mine area, gems
- [ ] Carry system: heavy items (logs, rocks) slow you; wheelbarrow/cart/car trunk to haul
### Animals and riding
- [ ] Hunting (simple wildlife that flees, drops meat/hide; bow or slingshot), cooking
- [ ] Taming: feed/befriend wild animals, pets that follow and help (find loot, carry), farm animals with products
- [ ] Riding: horse/ostrich/goat mount (walk/run/gallop, stamina, jump), later dinosaur on the jungle planet
### Movement feel
- [ ] (coyote time + jump buffer DONE v1 2026-11-23 via FX.jump_step; tree wind sway DONE; sprint stamina bar + winded breather, landing squash + dust DONE v1 2026-11-23) Walk/run/sprint with stamina, acceleration curves, jump + coyote time, slopes, camera shake/FOV on sprint, footstep dust
- [ ] Better car physics (suspension, drifting, damage), boat, bike
### Make things (creative core)
- [ ] (v1 DONE 2026-11-23: Workbench station by the sell bin, 5 data-driven recipes in GameState.RECIPES, E crafts first affordable; Copper Pickaxe upgrade recipe DONE (2 ingots + 2 planks, one-off, rocks break a hit sooner); Copper Axe DONE v1 2026-11-23 (trees fall in 2 hits); ore/gem chunks glow + sparkle DONE; still to do: recipe picker UI, furniture recipes, blueprint unlocks, use fence panels/rocket plates) Workbench + crafting recipes (tools, furniture, fences), blueprint unlocks
- [ ] Build mode: place walls/floors/roofs on a grid, build your own house, decorate; snap, rotate, demolish refund
- [ ] Vehicle builder: attach parts (wheels, engine, body, thrusters) to make cars -> boats -> the starship (ties to the rocket goal)
- [ ] Tool upgrades and invention bench (combine parts into funny gadgets)
### World and story
- [ ] Bigger world: chunked/streamed terrain, biomes (meadow, forest, quarry, beach, desert), landmarks, day/night + weather
- [ ] Story spine: "Gran's busted rocket": 5 acts (farm money -> town trust or infamy -> parts quests -> build the starship -> Moon). Quest log, memorable funny NPC arcs, 2 endings (Lawful hero / Notorious legend)
- [ ] Jobs and side activities: delivery, fishing contests, racing, treasure maps
### Graphics and physics polish (every run, pick one)
- [ ] (colour grading per time of day DONE v1 2026-11-19 via FX.grade_for; SSAO/glow/fog already High mode) Lighting: SSAO/SSIL, soft shadows, fog, bloom, colour grading per time of day
- [ ] Better vegetation (wind sway shader, grass density), water shader with foam, particles (dust, leaves, sparks)
- [ ] (hit-stop DONE v1 on chop + mining; camera shake DONE) Hit-stop, squash and stretch, impact particles, camera shake, sound for every action
- [ ] Ragdoll or physics props for crates, barrels, fences; destructible small props
- [ ] LOD/occlusion and performance budget (60 fps Low mode)

## Phase 1.7 - Features borrowed from similar games (owner request 2026-11-18; all kept, ordered by value)
Priority order for runs: weapons/hunting, friendship, odd jobs, pets with jobs, disguises, staged rocket, then the rest.
### Weapons, hunting and fighting (keep it funny: silly weapons, cartoon hits, no gore)
- [ ] Weapon system: equip slot, swing/aim/shoot, damage, cooldown, ammo, hit-stop + knockback + impact particles
- [ ] Melee: shovel (starter, funny bonk), axe, pickaxe, frying pan, baseball bat, fishing-rod whip
- [ ] Ranged: slingshot, bow and arrows, throwable turnips/pies, later a toy blaster and rocket-launcher gag
- [ ] Wildlife to hunt: rabbits, deer, boars, birds (flee/alert AI), drops meat/hide/feathers; hunting skill + tracks
- [ ] Hostile or grumpy fauna to fight: angry goose boss, wolves/bandit raccoons at night, cave critters, later jungle dinosaurs
- [ ] Combat feel: dodge roll, block, health + stamina bars, enemy telegraphs, downed-and-wake-up penalty (lose a little cash, not the game)
- [ ] Weapon crafting and upgrades at the workbench; hunting trophies for the house
- [ ] Police/law interaction: weapons raise heat, can be holstered, silly non-lethal tools (bonk, net, pie)
### Stardew-style life
- [ ] Friendship hearts for each NPC, gifts (loved/liked/hated), birthdays, heart events, arcs beyond barks
- [ ] Seasons (crops, weather, festivals); funny festivals (best-turnip contest, robbery-free day)
- [ ] Skill levels (farming, fishing, mining, hunting, stealth, driving) with perks
- [ ] Community-centre-style collection goal whose rewards unlock rocket parts
### Valheim / Core Keeper style
- [ ] Cooking with recipes and food buffs
- [ ] Weather and temperature (rain, storms, cold nights, clothing)
- [ ] Bosses with a funny twist (giant angry goose etc.)
- [ ] Underground caves/dungeons with loot
### GTA / Wobbly Life style
- [ ] Odd jobs with a mini-game each: courier, taxi, builder, chef, fisherman
- [ ] Disguises and masks that lower heat; burglary tools; getaway-car upgrades; crew heists
- [ ] Phone with contacts, map and missions
- [ ] Ragdoll physics for crashes and falls
- [ ] Cosmetics: hats, outfits, car paint
### Palworld / Cassette Beasts style
- [ ] Pets with jobs (water crops, carry loot, lookout) and traits
- [ ] Pet evolutions, collection book, pet races instead of battles
### Kerbal / Besiege / Terraria style
- [ ] Staged rocket: each part earned from a different activity (farm, heist, mine, hunt)
- [ ] Test flights where crashing is part of the joke
- [ ] Planet-by-planet progression with a unique gimmick each
- [ ] Achievements and a journal tracking everything done
### General polish
- [ ] Photo mode
- [ ] Town mini-games (fishing contests, races, card games)
- [ ] Radio using the procedural day/night music, with silly DJ chatter
- [ ] Accessibility: subtitles, colour-blind mode, key remapping

## Phase 2 - Earth Early Access: larger town, building your own house, animals (catch/keep/resources), clothes, weapons/combat, car building, more jobs, racing.
## Phase 3 - Rocket + Moon open world.
## Phase 4 - Jungle planet with dinosaurs, catchable and usable.
## Phase 5 - Beyond: more planets, endgame, Steam launch.

## Improvement backlog (research-driven; append ideas here, pick 1 small one per run)
- Mining/feel (2026-11-19 search, links only: Core Keeper mining guide https://supercraft.host/wiki/core-keeper/mining-guide , Godot forum game-feel checklist https://forum.godotengine.org/t/game-feel-checklist-for-godot-4-hit-stop-trauma-shake-coyote-time-and-more/145340 , hit-stop+trauma shake https://forum.godotengine.org/t/tutorial-hit-stop-and-screen-shake-in-godot-4-autoload-trauma-camera-mit/145240 , gdquest juicy attack https://gdquest.com/library/juicy_attack). Weakest part vs Core Keeper/Terraria: mining has no progression (tiers, ore->bars->tools) and no sense of depth. APPLIED: hit-stop with real-time timer. Next: trauma-based stacking camera shake, coyote time/jump buffer, pickaxe tiers needing copper bars, fall-damage-free cave area, ShatterKit-style fracture meshes.
- Physics drops (2026-11-19 search, links only: Godot forum RigidBody3D crate/pickup threads https://forum.godotengine.org/t/pick-up-and-drop-item-code-help/130851 , Valheim/Minecraft tree-physics mods e.g. https://www.curseforge.com/minecraft/mc-mods/physics-tree-drop). Weakest part vs Valheim/Terraria: gathering felt abstract (wood teleported into the bag). APPLIED: logs are rigid bodies with delayed magnet pickup. Next: whole trunk as a rigid body toppling away from the player, log->plank chopping, drop merging/despawn cap for perf, stone/ore reuse of WoodLog, pickup pop sfx pitch ramp.
- Tyre dust follow-ups (2026-11-18 search: links only; Godot docs/forum: GPUParticles3D vs CPUParticles3D, local_coords off so trails stay in world): swap to GPUParticles3D + skid-mark decals in High mode, per-wheel emitters
- Focus Audit style pass: check every menu is keyboard/pad navigable and ESC menu returns focus; on-screen pad glyph prompts swapping by last input device
- Surface-aware footsteps (grass/wood floor/road) via ground raycast group lookup (Godot 4 reactive footsteps idea, itch.io blog); car engine pitch from speed
- Audio: sfxr-style parameter presets (GodotSfxr/gdfxr exist) for chop, splash, lockpick click, car engine pitch via AudioStreamGenerator; randomise pitch +-5% per play to avoid repetition
- Performance profiling pass for High mode
- Funny writing: NPC barks (night barks DONE), item descriptions, news ticker; no-repeat bark memory DONE (Npc.fresh_bark)
- Accessibility options (colour-blind, subtitles, key rebinding)
- Data-driven NPC schedules (list of {from_hour, to_hour, place}) so each NPC can have custom routines, shop hours and events (idea from Godot forum schedule threads)
- Interior polish: furniture props from KayKit packs, door open animation, fade-to-black on enter/exit
- NPC dialogue barks + shop closing hours tied to the keeper
- Witness system: gradual suspicion meter (fills faster when close/in view cone, decays when out of sight) instead of instant detection; cone + distance scaling (research: stealth-game spotting write-ups, Klei alarm design)
- Lockpick HUD: replace text bar with on-screen meter + sound click per pin
- Hiding: crouch/shadow reduces witness fill rate; closets in homes (follow-up to witness meter)
- Heat consequences: police NPC patrol at heat 3, shop price penalty at heat 2
- Fence price should drop when heat is high (DONE v1: -20%/heat level above 1; daily cap DONE: 3 items/day) (fences get nervous) and fence stock/daily cap to avoid dumping (research: stolen-goods design threads)
- Reputation effects: Lawful shop discount DONE v1 (2%/pt, max 20%) + heat surcharge 10%/level above 1 (2026-11-18); still:  Outlaw gets fence bonus + townsfolk barks
- Cop search follow-ups (2026-11-18, links only: mosfetarium MaskedDetective devblog #2 on guard searching): check closets/hiding spots near last seen spot, search points chosen by nav reachability, give-up barks (give-up barks DONE)
- Police heat cooling: heat should only decay once you are out of sight of police (search-and-lose, as in modern wanted-system write-ups), not just by day count
- Police: add a second constable / car patrol once Sprint 3 cars land; crouch + shadows hiding still to do
- Car follow-ups: speed-sensitive FOV/camera lag, tyre-screech dust particles, headlights at night (DONE v1: 2 SpotLights on when dark>0.35), fuel (optional), traffic AI with lane waypoints, cops chase by car at heat 3 (Sprint 3 part 2)
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
- Music follow-ups (2026-11-17, search: links only; adaptive music via AudioStreamInteractive exists): crossfade between day/night loops, extra tracks for indoors/driving/police chase, recorded CC0 tracks (e.g. itch/github packs) if a fetchable source appears
- Footstep follow-ups (2026-11-17): real material lookup via ground raycast + group/metadata instead of position rules; sand/water steps once biomes exist (Godot Material Footsteps asset exists)
- Menu focus follow-ups (2026-11-17, Godot docs gui_navigation: set focus_neighbor_* and grab_focus on open; links only): Resume button focus neighbours, focus highlight style, Focus Audit itch tool idea
- Prompt follow-ups (2026-11-17, search: Inglo Games 'Dynamic Input Prompts in Godot 4', Tsumiki devlog: swap prompts on last device, keep working while paused): glyph icons instead of text labels, use tokens in HUD interact prompts/help panel, read labels from InputMap instead of tables
- Demo readiness (2026-11-17 search: Godot 4 Next Fest Demo Shell, bugnet QA checklist for Steam demos; links only): demo-shell menu with wishlist/feedback link, 15-minute smoke test of the exported build before release, clean first-5-minutes tutorial
- Interactable UX (2026-11-17, search: munchmo 'Rethinking Interactables', Acagamic contextual prompts; links only): pick nearest/most-facing interactable, show prompt only when in view cone; PS vs Xbox glyph set option
- Context hints (2026-11-17, search: Roblox onboarding techniques, wayline tutorial UX; links only): teach at point of use, once; next add first-heat/police and first-fence hints, make hints skippable in settings; DONE v2: heat, fence, arrest hints; DONE v3: "Show hints" toggle in ESC menu (saved in audio.json)
- Police cooling (2026-11-17 search: wanted-level write-ups, links only; modern systems make you break line of sight/hide to cool down): next, heat decays faster while hidden indoors/out of sight of Bumble
- Police cooling DONE v1 (2026-11-17): heat sheds 0.025/s while hidden indoors and Bumble is not chasing; next: crouch/shadow hiding, cooling outdoors when out of sight, 'lie low' HUD hint. Research 2026-11-17: GTA-style wanted articles (links only) say modern systems need you to break line of sight rather than wait out a timer.
- Police cooling DONE v2 (2026-11-18): heat also sheds 0.008/s in the open when no constable/squad car has line of sight (GameState.cool_heat `unseen`, Police.sees_player). Research: GTA-style wanted-level/search-cone search (links only: GTA wiki, 'search cones' write-ups). Next: crouch/shadow hiding, 'lie low' HUD hint, search-radius mechanic for cops after losing you.
- Crouch hiding DONE v1 (2026-11-18): hold C/Ctrl/pad B to sneak (speed 2.6, model squashes), halves constable sight range (14 -> 7) and cools heat 0.014/s out of sight in the open. Research: stealth-game visibility/noise write-ups (links only: School of Stealth, player stealth controller baseline). Next: shadow/night visibility bonus, closets in homes, crouch footstep volume (quieter steps), witness NPC fill rate reduced when crouched.
- Crouch follow-up DONE (2026-11-18): crouching halves witness suspicion fill (Witness.CROUCH_FILL_MULT). Next: quieter crouch footsteps, shadow/night visibility bonus, closets in homes.
- Crouch follow-up DONE (2026-11-18): crouch footsteps play at 25% volume (Sfx.step_volume). Research: stealth shadow-visibility search (links only: Game Developer 'building blocks of stealth play', Splinter Cell lighting). Next: shadow/night visibility bonus (night halves constable sight), closets in homes.
- Stealth follow-up DONE (2026-11-18): night (20:00-6:00) halves constable sight range, stacks with crouch (Police.is_night, NIGHT_SIGHT_MULT). Research: none this run (small item, unattended). Next: closets in homes, search-radius cop behavior after losing you.
- Cop search DONE v1 (2026-11-18): after losing you Bumble goes to your last seen spot and looks around 5s (Police.State.SEARCH) before resuming patrol; sees you again = chase. Next: closets in homes, search radius widening.
- Closets DONE v1 (2026-11-18): each town home has a wardrobe (Closet node); E to hide, heat cools 3x (0.075/s) inside, auto-exit if you walk >2.2m away. Research: hiding-spot design (links only: DOORS wiki Hiding, Hello Neighbor wardrobes). Next: hide-in-closet camera/model hidden, NPC residents hunting you when heat high, search radius widening, closet creak noise risk.
- Closet follow-up DONE (2026-11-18): player model hidden while in a wardrobe (Closet.model_visible). Next: closet camera tweak, search radius widening, resident NPCs hunting at high heat.
- Closet camera DONE (2026-11-18): camera pulls to 2.2m while hiding. Research: links only (Skyrim 'Take a Peek' mod, UE forum hiding in furniture). Next: peek-through-slats vignette/overlay, resident NPCs hunting at high heat, closet creak noise risk.
- Closet creaks DONE (2026-11-18): wardrobe throws a funny creak line every 9s while hiding (Closet.creak_tick). Design note: constable never enters interiors, so a creak-detection risk does not apply; flavour only. Research: hiding-spot design search (links only: Amnesia wiki Hiding, Invisible Inc stealth design, Styx lure-to-cupboards thread). Next: resident NPCs hunting at high heat, peek-slats vignette.
- Townsfolk barks DONE v1 (2026-11-18): reputation-flavoured greetings from nearby outdoor NPCs (Npc.bark). Next: Outlaw-only dialogue, NPC-specific lines.
- Loot barks DONE (2026-11-18): townsfolk comment on your clinking pockets when you carry stolen goods (Npc.BARKS_LOOT overrides rep pool). Next: NPC-specific lines, Outlaw-only dialogue choices.
- Personal barks DONE (2026-11-18): Pip/Dame Gertrude/Bork each have own lines on odd barks (Npc.BARKS_PERSONAL). Research: Game Developer 'Adding life to worlds with dialogue barks' (links only) -> idea: avoid repeating last-used line per NPC, context barks by time of day/weather. Next: Outlaw-only dialogue choices, no-repeat bark memory.
- No-repeat barks DONE (2026-11-18): Npc.fresh_bark skips ahead so the same line never plays twice running. Next: Outlaw-only dialogue options, per-NPC last-line memory.
- Outlaw dialogue DONE v1 (2026-11-18): reputation <= -7 gets a notorious bark tier (Npc.BARKS_NOTORIOUS). Research: dialogue-reacts-to-reputation devlog (links only: itch 'Echo dynamic dialogue faction system', Roadwarden devlog). Next: Outlaw-only shop/fence dialogue choices, per-NPC last-line memory.
- Sal reacts to Outlaw standing DONE (2026-11-18): Shady Sal's sale line changes at rep <= -3 and <= -7 (Station.sal_sale_line). Next: Outlaw-only shop dialogue, per-NPC last-line memory.

## Research backlog (2026-11-23 run)
Weakest part vs comparables: gathered materials (wood, stone, ore, gems) had no use; Terraria/Core Keeper turn them into progression at stations. Applied: workbench + recipes (rocket_plate ties to the Moon goal), coyote time + jump buffer.
- Terraria crafting guide, nearby-station/chest crafting UX: https://terraria.wiki.gg/wiki/Crafting_station and https://godlike.host/new-crafting-ui-explained-in-terraria-1-4-5-update-how-to-craft-from-nearby-chests-blog (idea: craft from nearby chests, station tiers)
- Godot 4 game feel checklist (hit stop, trauma shake, coyote time): https://forum.godotengine.org/t/game-feel-checklist-for-godot-4-hit-stop-trauma-shake-coyote-time-and-more/145340
- Stacking feel effects, "apply the difference": https://forum.godotengine.org/t/game-feel-effects-that-stack-without-fighting-your-code-trauma-shake-real-time-hit-stop-and-apply-the-difference/146379

## Research backlog (2026-11-23 run 2)
Weakest part vs comparables (Stardew/Core Keeper): sprint was free and tools never improved, so there was no tension or progression in moving/gathering. Applied: stamina with a "winded" recovery threshold (Stardew-style energy, but forgiving), copper pickaxe tier via workbench (Core Keeper/Terraria tool tiers), landing squash + dust (game-feel checklist).
- Why Stardew-style chores stay addictive (short loops, visible progress): https://medium.com/super-jump/what-makes-a-game-about-mundane-chores-hopelessly-addictive-ab136266ebcf
- Core Keeper digging loop: https://www.thegamer.com/core-keeper-and-the-endless-craving-for-digging-holes/ and crafting that feels good: https://fictionhorizon.com/20-crafting-systems-that-actually-feel-good/
- Godot 4 particles docs (GPUParticles3D vs CPU, sub-emitters): https://docs.godotengine.org/en/4.7/tutorials/3d/particles/index.html
- Next: more tiers (iron/gem pickaxe), axe upgrade, stamina upgrades from food, speed lines on sprint, per-step dust bursts.

## Research backlog (2026-11-23 run 3)
Weakest part vs comparables (Core Keeper/Terraria): pickups were silent bookkeeping; those games make collecting itself rewarding (magnetised drops, rising pitch chains, shimmering ore). Applied: pickup combo pitch (+1 semitone per quick pickup, cap 8), glowing/sparkling ore and gem chunks, copper axe tier. Searches returned links only.
- Core Keeper/Terraria similarities and digging craving: https://www.thegamer.com/core-keeper-terraria-similarities/
- Godot particles progress report: https://godotengine.org/article/progress-report-state-of-particles/ and stylized water tool https://80.lv/articles/create-beautiful-stylized-water-easily-with-this-godot-tool/
- Next: recipe picker UI (cycle recipes), iron tier, water foam shader, GPUParticles hit sparks, pet that picks up items for you.
