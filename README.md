# OpenSims

An original life-simulation sandbox built with Godot 4.7, modelled on how classic life
sims look, feel and play. Characters combine native Anny anatomy, licensed CC0
MakeHuman assets, original modelling and AI texture detail. Source provenance is
retained in `assets/source/`; `tools/` rebuilds the Blender models and generated audio.

## Character creator status

The current checkpoint includes native male/female and age anatomy, direct sculpt
controls, improved hands, fitted female clothing and a revised bob hairstyle. The
full Sims 4 visual-quality target remains unfinished, and work is paused at the
user's request. See [completed work, remaining work and validation](docs/character-creator-progress.md)
for the current status, known limitations, source licenses and rebuild instructions.

## Running

- Open `project.godot` in Godot 4.7.2 and press F5, or run `Godot_v4.7.2-stable_win64.exe --path .`
- Tests: `Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/run_tests.tscn`
- Checks (print OK/FAIL): `... --headless --path . -- --scenario=<saveload|travelcheck|householdscheck|audiocheck>`;
  `inputcheck` clicks through the real UI, so run it without `--headless`
- Screenshot of a scripted moment: `... --path . -- --screenshot=C:/path/out.png --scenario=<name>`
  (see `_run_scenario` in `scripts/main.gd` for the list)
- Creator gesture check (run with a visible renderer): `... --path . res://tools/check_character_sculpt.tscn -- --scenario=skip_cas`
- Start straight in Create a Sim: `... -- --scenario=new`; skip the title screen: `--scenario=skip_cas`
- Native age/rig/hair/save check (with a visible renderer): `... --path . res://tools/check_ages.tscn`
- Regenerate assets: `blender --background --python tools/make_sim.py`,
  `blender --background --python tools/make_objects.py`, `python tools/make_audio.py`
  For character source presets, use the isolated Anny environment and `python tools/export_anny.py` first. It exports both frames and all native age presets.

## What's in it

- **Title screen** laid out like the reference: who lives in the last-played home, Resume
  Game, Load Game (save slots, then households), New Game, and a "..." menu; Save As makes new slots.
- **Menu and Game Options** matching the reference's layout: Save, Game Options (Graphics,
  Sound, Music, Gameplay with free will, aging and lifespan, Save Settings with autosave,
  Environment with the lunar cycle (moon phases, full-moon and new-moon nights),
  Camera with edge scrolling and the Sims 3 camera, Screen Capture, Tutorial & Tips, Other, Accessibility), Help, Lessons, Patch Notes, Credits, Achievements,
  Manage Households, Main Menu, Quit Game.
  Households you are not playing live on: they age, work, get promoted, have babies
  and pass away, with neighbourhood news. Townies age, marry, have children, and newcomers move in.
- **Create a Sim**: households of up to four, name, male/female anatomy, native age anatomy (toddler to elder), body sliders,
  direct face/body drag controls with undo and cancellation, hairstyles, walk styles, skin/hair/outfit colours for Everyday, Sleepwear, Athletic and Swimwear,
  24 traits with conflicts, and one of 19 aspirations in 11 categories.
- **Neighbourhood map**: buy a furnished home or an empty plot; homes of other families
  are marked as taken.
- **Live mode**: six needs, emotions from moodlets with body language, 16 skills (fishing, piano, comedy, mischief, mixology, programming and more), wants
  and aspiration milestones with a Rewards Store, socials in six categories (Friendly,
  Funny, Romance, Mischief, Mean, Parenting) and relationships (friends, going steady, break-ups,
  WooHoo, marriage, moving in), toddler skills (talking, walking, potty...) taught by parents, child skills (Creativity, Mental, Motor, Social) and monkey bars, 8 careers with daily tasks and on-the-job choices, plus school, homework, life stages, babies,
  old age, death and the Grim Reaper, night-time burglars (a burglar alarm calls the police), bills and power cuts, messes, breakdowns and fires,
  cooking recipes and group meals, gardening (plant, water, weed, fertilize, harvest produce of five qualities), sticky outfits (dresser and self-click Change Outfit), held props, inventory with paintings and fish, a phone with Social, Travel, Services (pizza, maid, repairs), Career and Household tabs, social events (House Party, Dinner Party, Date) with goals and medals,
  townies, visitors at the door, day and night, music and ambience.
- **Build/Buy**: ready-made furnished rooms, undo/redo, walls and a one-drag room tool, foundations with steps, terrain paint, roofs (gable, hip, flat or none, six colours), doors, windows, fences (picket, iron railing, hedge) with gates, half walls, columns, paint, floors, pools, a second storey with stairs,
  ~70 objects with colour swatches and counter-top decor (lamps, vases, books, candles...) (bathtub, armchair, kids' furniture, rugs, art,
  pines, flowering shrubs and flower beds...),
  a scrolling catalogue, and room decor that lifts Sims' moods.
- **Lot traits**: up to three per home (Homey, Chef's Kitchen, Gremlins, Natural Light...).
- **Community lots**: a park, gym, library and lounge.

## Controls

The same defaults as the reference game:

- **Live mode**: left-click to walk or open a pie menu (click a Sim to socialize); P, 0 or `
  pause; 1/2/3 speeds; Space next Sim; Enter centre on the Sim (Shift+Enter: the lot);
  O needs, L skills, Y simology, R relationships, J career, G aspiration, I inventory;
  Home/End walls up/down; Page Up/Down floors; Tab hides the interface; C screenshot; Esc menu.
- **Camera**: WASD/arrows pan (Shift: faster), Q/E raise/lower, comma/period or
  right-drag rotate, middle-drag pan, wheel or Z/X zoom, edge scrolling.
- **Build/Buy**: F2 opens the object catalogue, F3 the ready-made Rooms, F1 back to live; H hand, B wall, K sledgehammer,
  E eyedropper, R design tool; comma/period rotate the held object, Delete sells;
  Ctrl+Z / Ctrl+Y undo and redo. Build/Buy and saving are locked during a fire.
- **Create a Sim**: click the face or scroll up to inspect facial details; scroll down
returns to the body. Drag the nose, eyes or jaw sideways to adjust proportions;
drag lips upward for fullness. Drag the waist outward for weight or the chest upward
for muscle. Drag the background to turn. Ctrl+Z and Ctrl+Shift+Z undo/redo drag edits;
Escape cancels the current drag. Existing sliders and swatches remain available.
