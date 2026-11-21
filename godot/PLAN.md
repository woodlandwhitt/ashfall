# Ashfall: Meridian, Godot overhaul: master prompt

Use this file as the brief for every session that works on the Godot version. Read it first, follow the phase
order, and update the "Status" lines as phases land.

## The brief

Rebuild Ashfall: Meridian natively in Godot 4.5 (Mobile renderer, Android first), replacing the WebView/three.js
build in `/app`. The Godot version must have **every feature of the WebView build (builds 1-13) and more**,
look clearly better, run smoothly on mid-range Android phones, and tell a deeper story. It must stay a
Fallout-3-style first-person open-world RPG set in the irradiated valley around the Meridian reactor.

Hard rules:
- Assets must be free with no sign-up: CC0, or CC BY with credit in `godot/CREDITS.md`. Pull them from GitHub or
  other places the build machine can reach. Never use paid or "free with account" assets.
- Ship every milestone. Merge to `main` → GitHub Actions builds `godot-N` → send the user
  `https://github.com/woodlandwhitt/ashfall/releases/download/godot-N/AshfallGodot.apk`.
- Work on the `godot-slice` branch and only merge to `main` when the self-test passes. Pushes to other branches
  don't build.
- Test before shipping: `-- --selftest` (headless) must pass, and look at `-- --shot` screenshots of anything visual.
- Keep the WebView build working until the Godot build has full feature parity.

## Performance budget (the first priority, measured on the user's phone)

The godot-2 baseline had lows of 11 FPS on Medium and 16 on Low. Targets:
- **Medium:** 45+ FPS steady, with "low" no worse than 35.
- **Low:** 60 FPS. **High:** 30+ on a flagship.
- **Per frame:** under ~350 draw calls and under ~400k triangles on screen.
- **Limits:** at most 8 shadowed objects near the camera, and no shader compiles during play (pre-warm materials
  on the loading screen).
- **How to get there:**
  - The world streams in 64 m chunks. Small props draw only near the camera; buildings use a long range.
  - Characters merge to a single mesh with a LOD.
  - AnimationPlayers turn off beyond 55 m. Physics stops for anything standing still or far away.
  - A cheap terrain shader on Low. Render scale per preset.
- **Measure:** `-- --perf --at=x,z,yaw` prints draw surfaces and triangles split by characters, small and big
  chunks, and grass. Keep a table of results in this file.

## Graphics overhaul

- **People:** Quaternius Universal Base Characters and Modular Outfits (CC0), all on one 65-bone skeleton,
  animated with the Universal Animation Library (45 clips). Outfits are tinted from each NPC's look in the old
  `entities.js`. To add: UAL2 animations, more outfits (sci-fi, modern), hair, hats, and faction colours.
- **First person:** the player's own arms (vault-suit sleeves) holding the weapon, with aim, shoot and reload
  clips. Every weapon gets a grip offset and its own reload.
- **World:**
  - Re-export every location from the three.js build, then dress it further: more buildings, interiors, props
    (Poly Haven CC0, Kenney, KayKit, Quaternius kits), and decals for dirt, cracks and blood.
  - Better skies: dust storms, rad storms, lightning, a night sky with stars, and a moon.
- **Lighting:** a baked-feel look on mobile (light probes or a VoxelGI-like fake on High), warm interior lamps,
  fog volumes on High.
- **Post:** tonemapping, glow, colour grade, and drug and K-hole screen effects (from `khole.js` and `drugs.js`).

## Mechanics to port (from the WebView build; nothing gets dropped)

Source of truth is `/home/claude/wasteland/src` (`data.js` has 68 quests, 71 dialogue trees, 134 items,
23 locations, 15 lore entries, 19 vendors, plus PERKS, RECIPES, BOUNTIES, COMPANIONS, RADIO, ENDINGS and KARMA).

- **Opening:** the vault start, story intro, character creation (stats: might, agility, endurance, aim, luck,
  charm), the vault exodus.
- **Stats:** XP, levels, perks, karma and karma titles.
- **Weapons:** every gun from builds 11-12 with its real model, plus grenades, molotovs and the pulse grenade.
  Also melee, ammo types, reloads and recoil.
- **FOCUS:** the targeting mode, VATS-like, with AP.
- **Inventory:** the Pip menu with inventory, stats, quests, map and radio. Barter with 19 vendors, crafting at
  workbenches, lockpicking, terminals and lore.
- **Drugs:** chems and addiction (`drugs.js`), and the ketarad K-hole (blackout or the Hole, with its creatures,
  beings and quests).
- **People:** companions, bounties, road events, attackable townsfolk.
- **Driving:** the Rust Runner vehicle.
- **World:** day/night with dayrate, weather (rain, lightning, radstorms), water dynamics, radio stations.
- **Interiors:** interior cells for every important building, with enter and exit doors.
- **Saving:** save and load (several slots plus autosave), the map, fast travel between discovered locations.
- **Endings:** all three, plus the epilogue slides.

New mechanics to add after parity:
- Cover-aware enemy AI with flanking, using the navmesh.
- Factions with reputation.
- A dynamic radio DJ that reacts to your deeds.
- Settlement building at Dustwell.

## Story overhaul

Keep every existing quest and line, then deepen them:
- **Main quest:** make Haven 12's dying recycler and Meridian's reactor one mystery. Add three or four new
  investigation beats that point at the Haven Co. memo, the Ironside order and the Meridian logs before the
  final choice.
- **Factions:** Dustwell (settlers), Ironside (order), the Toll Kings (raiders on the I-9), the Kettle Hollow
  junkies, and Meridian's last engineers. Each gets a questline of 3+ quests and an effect on the endings.
- **Companions:** each gets a personal quest and opinions on your choices.
- **Endings:** keep the three; vary their epilogue slides by faction standing and karma.
- **Voices:** voiced lines with device text-to-speech, per-character pitch and rate (as now), and subtitles.

## Content pipeline (how the port works)

- `tools/export_region.mjs` (in `/home/claude/godot/tools`) runs the three.js build headlessly and exports any
  rectangle of the world.
  - **World:** 64 m chunk GLBs with small and big tagging. Then `share_textures.py` dedupes their textures.
  - **Terrain:** heightmap (`height.f32`) and ground mask.
  - **Data:** colliders, points, pools, lamps, NPC and enemy spawns, and their models.
- `tools/export/` holds the whole pipeline (see its README). `dialogue.mjs` converts `data.js` dialogue and LOOKS. It must grow into a full converter for quests,
  items, vendors, perks and recipes into JSON, so the Godot game is data-driven: logic in GDScript, content in
  JSON.
- `tools/make_heads.py` cuts heads from the base bodies so they can be worn with outfits.

## Phases (each one ships a godot-N build)

1. **godot-3:** performance pass, Quaternius people and first-person arms, graphics presets, the plan.
   *Status: shipped.*
2. **godot-4:** the whole map streamed (all 23 locations). Save/load, inventory, the Pip menu, every weapon,
   stats and levels. *Status: shipped (plus grenades).*
3. **godot-5:** all quests and dialogue data-driven from JSON, vendors and barter, lockpicking, terminals and
   lore, crafting. *Status: shipped. `tools/export/logic.mjs` stores the original's quest and dialogue functions
   as syntax trees; `scripts/jsvm.gd` runs them against `scripts/gapi.gd` (the original G API). Locked doors open
   by stepping through; interiors, casino, companions and the vehicle answer "in a later build" until their
   phase.*
4. **godot-6:** the vault opening and character creation, perks, karma, FOCUS targeting, companions, bounties,
   road events. *Status: shipped. Haven 12 is the first interior area (`data/vault/`, its own chunks, heightmap,
   people and objects; `Game.load_area`), which godot-7's building interiors will reuse. Radstorms wait for the
   weather system.*
5. **godot-7:** day/night, weather, radio, the vehicle, drugs, the K-hole, interiors for every important
   building.
6. **godot-8:** the story overhaul (new beats, factions, companion quests), all endings and epilogues, polish.
   At that point the Godot build replaces the WebView build.
