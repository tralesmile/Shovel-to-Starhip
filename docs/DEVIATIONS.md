# Deviations from plan
Record anything that went off plan (blocked tool, failed export, dropped/changed scope, asset license problem, failing tests left unresolved, research idea rejected) then continue with the next item.
Format: `- YYYY-MM-DD HH:MM | what happened | what was done instead | follow-up needed`
- 2026-11-16 | Godot 4.7.1 downloaded from github-builds OK; export templates and Windows export not attempted this run (sprint not complete) | none | export at Sprint 3/phase completion
- 2026-11-16 | WebSearch research step skipped, and a headless in-scene driving smoke test hung (timeout) | relied on unit tests + clean boot check | next run: load WebSearch, try xvfb screenshot test of driving
- 2026-11-16 | Traffic basics + police car chase (Sprint 3 leftover) deferred; Godot had to be re-downloaded (fresh session) | took fishing from Sprint 4 instead (reorder only, nothing cut) | do traffic later; in-scene driving smoke test still not attempted
- 2026-11-16 | Web search gave no useful page content (only link list); Godot re-downloaded again; Windows export skipped (sprint not complete) | used design rule of thumb | none
- 2026-11-17 | WebSearch research skipped again (kept run small); Godot re-downloaded | none | load WebSearch via ToolSearch next run
- 2026-11-17 | Godot re-downloaded again (fresh session); search returned link list only; police car chase deferred | shipped traffic only | next run: police car chase
- 2026-11-17 | Godot re-downloaded again; web search returned link list only | used standard pursuit steering from memory | none
- 2026-11-17 | Local clone was behind origin/main; built a duplicate Sprint 1 slice that conflicted on push | discarded it (kept on local branch only), rebased onto upstream and did Sprint 5 audio settings instead | always `git pull` before building
