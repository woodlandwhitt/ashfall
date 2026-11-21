# Export pipeline (WebView build → Godot data)

These scripts run the three.js build of Ashfall (`/home/claude/wasteland`) in headless Chromium and convert its
world and content into the files under `godot/data/`. Node needs `playwright` (from the WebView project) and `acorn`.

| Script | Writes | What it does |
|---|---|---|
| `export_region.mjs OUT` (env `REGION=x0,x1,z0,z1`) | `world/c_i_j.glb`, `world/tex/*.webp`, `chars/`, `height.f32`, `mask.png`, `tint.png`, `region.json` | Static geometry as 64 m chunks, characters with named limbs, the heightmap, ground mask and colliders. Resumable: existing chunks, textures and characters are skipped. |
| `share_textures.py OUT/world` | rewrites chunk GLBs | Points every chunk at the shared `tex/` files instead of embedded images. |
| `strip_extras.py` | rewrites GLBs | Drops glTF extras Godot does not need. |
| `dialogue.mjs region.json` | `region.json` | (godot-4) the townsfolk's lines and looks. |
| `gamedata.mjs` | `game.json` | Items, enemies, loot tables, perks, places, vendors, gun fits. |
| `logic.mjs` | `logic.json` | Quests, dialogue, quest objects, vendors, recipes, endings: functions become ESTree syntax trees that `scripts/jsvm.gd` runs. |
| `world_meta.mjs` | `world.json` | Spawns (with the quests that summon them), containers, pickups, terminals, workbenches, locked doors, quest points. |
