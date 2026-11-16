# Runbook for each hourly autonomous run

Goal: advance the game per docs/PLAN.md, keep it working, push to `main`. Nobody is watching live; the owner playtests Windows builds occasionally. Never ask questions; make the most reasonable choice and log it.

## Steps
1. `git pull` (or clone) this repo. Read docs/PLAN.md, docs/LOG.md (last 10 entries), docs/DEVIATIONS.md, docs/PLAYTEST.md (owner feedback = top priority).
2. Setup tools if missing (fresh sessions lose them). Godot 4.7.1 stable from github.com/godotengine/godot-builds releases (linux x86_64 zip and export templates .tpz; only github.com release URLs and git clone work through the proxy). Templates go to ~/.local/share/godot/export_templates/4.7.1.stable. Import once: `godot --headless --path . --import`.
3. Research (10 min max): 1-3 WebSearches for an improvement relevant to the current sprint (gameplay feel, funny design ideas, Godot 4 techniques, performance, comparable games). Add worthwhile ideas to the PLAN.md backlog; apply at most one small one this run. CC0 assets only (record source in CREDITS.txt).
4. Build: take the next unchecked item(s) in PLAN.md that fit about 40 minutes of work. Small, working increments beat big broken ones.
5. Test: `godot --headless --path . --script res://tests/run_tests.gd` must pass; add tests for new logic. Fix or revert if failing. Optional screenshots via xvfb-run (see tests/screenshot_director.gd) when visuals change.
6. Docs: tick PLAN.md items, append a LOG.md entry (date, what changed, test count, research idea used, next step), bump version in project.godot at sprint completion.
7. Push: commit with a clear message and push to `main`. When a sprint completes, export `godot --headless --path . --export-release "Windows Desktop" build/ShovelToStarship.exe`, zip it with a READ_ME and attach it to a GitHub release (`gh release create vX.Y.Z ...`) if gh works; otherwise note it in DEVIATIONS.md.
8. If anything goes off plan (tool blocked, test unfixable, scope change), append to docs/DEVIATIONS.md, commit it, and continue with another item. Never leave main broken: if tests fail at the end, revert the failing change and log it.

## Guardrails
- Keep all owner-chosen features; reorder, never cut. Tone stays lighthearted and funny. No real brands, no copyrighted characters or music.
- Don't commit .exe/.zip or the .godot folder.
