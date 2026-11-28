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
  `https://github.com/woodlandwhitt/ashfall/releases/download/godot-N/AshfallMeridian.apk`.
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
   building. *Status: shipped. A 1000-second day with sun, moon and stars; clear, cloudy, rain, storms with
   thunder, and radstorms; radiation and Rad Flush; the radio (DJ, news, music) on the Pip-Boy; the Rust Runner
   buggy; chems with buffs, crashes and addiction; the K-hole (blackout, or two minutes in the Hole:
   `data/khole/`, drawn by `scripts/khole.gd`); and the 21 building interiors (`data/cells/`, entered through
   their street doors). Also in this build: townsfolk look different from each other, guns sit in the hands
   properly, and townsfolk can be shot (essential people yield, guards join in).*
6. **godot-8:** a fixes-and-feel build from play-testing godot-7. *Status: shipped. Enemies see and hurt you
   again (their line of sight was hitting your own body) and fight with tactics: gunmen keep their distance,
   strafe, fire in bursts, take cover when hurt and run when nearly dead; animals and brawlers spread out,
   circle and wind up their blows. Hit markers (white, yellow for criticals and head hits, red for kills), a
   red wedge showing where a hit came from, the target's name and health, head hits for half again. Every gun
   is held by its own grip and handguard (measured off side views, `tools/gunside.tscn`) with the hands pinned
   by IK; melee weapons are modelled and swing. The Pip-Boy is rebuilt in sections (STAT, INV, DATA, RADIO,
   SYS) with deeper pages. Haven 12 has panel ceilings, tiled floors, strip lights, wall ribs, sliding doors and
   a cog door that rolls aside. HUD corners no longer run under the touch buttons.*
7. **godot-9:** voices, tools and fixes. *Status: shipped. Every scripted line (conversations, companions, radio,
   the DJ, the intro) is voiced by its own speaker with Piper and the LibriTTS voice (`tools/voice/`), with
   effects for the radio, the Core and the people of the Hole; unrecorded lines fall back to the device's speech.
   A developer menu (F1, or DEVELOPER in the pause menu: cheats, player, world, spawning, quests, areas, voices,
   rendering and a command console) and Forge mode (F2, or FORGE in the pause menu: build walls, floors, ramps,
   stairs, cover, props, lights, loot, workbenches and enemy spawn points, kept with the save per area, with three
   portable map slots). Haven 12's walls are painted steel panels; handguns are held out two-handed and the
   support hand reaches the handguard on long guns.*
8. **godot-10:** story and feel. *Status: shipped. The story layer (`tools/story/story10.mjs` -> `data/story.json`,
   merged over logic.json): six factions with standing (Pip DATA > FACTIONS; shop prices follow it), the council
   beat "Five Hands on One Lever" (hear each power's claim on the core and pledge to one; the epilogue remembers
   whether you kept your word), Jory's "The Lead Wagon" and Sable's "Burning Bridges", fourteen new epilogue
   paragraphs. Sneaking (detection, sneak attacks), stealing (owned things and containers; seen or unseen),
   two raised fists, a darker Haven 12 and wallpapered town interiors, walls drawn both ways, the security
   locker, full-resolution near terrain (props no longer float), two radio stations with music and more DJ.*
9. **godot-11:** more of the valley. *Status: shipped. The Silver Spur's tables (`scripts/casino.gd`): blackjack
   (six-deck shoe, 3:2, double, split), single-zero roulette with inside and outside bets, dice (pass, don't pass,
   field) and four slot machines, Old Patsy paying by what you did about her governor chip; a nightly house limit
   (win too much and Knuckles walks you out until tomorrow), VIP chips, the High Roller tally. Companion approval
   (Jory and Renn like decency, Sable likes larceny; karma, quests and the tables move it; Pip DATA > PARTY),
   personal conversations at 30 that make them loyal (tougher, harder-hitting, they stay whatever your karma),
   leaving for good at -40. Deputy Renn joins as a companion with his quest "Old Colours" (Mags Coyle's bounty, the
   dry wash camp, and who in Saltreach sold the wagon routes). Story layers now stack (`story10.mjs`,
   `story11.mjs`). No grass through the Spur's carpet. Console: casino, approve, loyal, recruit.*
10. **godot-12:** *Status: shipped.* Furnished interiors: every town room and Haven 12's eleven rooms get
   photoscanned furniture (Poly Haven, CC0) by room type, plus the wasteland kit's crates, barrels and junk, all
   aged (`furnish.gd`, `furniture.gd`). Weathered props outdoors (`weathering.gd`). Real fires (`fire_fx.gd`).
   Item models on the ground (`item_models.gd`). Ghouls with rotting skin and rags; everyone dressed from mixed outfit
   parts and dyes (`Humanoid.mix_spec`). Enemies strafe with hips turned (`leg_twist.gd`), face you to shoot, come
   at you a few at a time. Terminals with password hacking (`terminal.gd`). Third-person camera (`third_person.gd`).
   Chem quick button. Intelligence (7th S.P.E.C.I.A.L.). Pip-Boy drag scrolling; pause closes menus; queued
   messages; pools lie on the ground; provoked townsfolk calm down; no stealing through doors; Forge furniture.
11. **godot-13:** *Status: shipped.* The arsenal (`data/arsenal.json` from `tools/arsenal/`): every gun its own
   model (zee-dot-weapons' kitbashed low-poly guns and Kenney blasters, CC0), repainted in worn finishes
   (`gun_paint.gd`), with grips read off side views (`tools/gunside.tscn`, `tools/fpall.tscn`); 30 new weapons
   (rocket tube, energy guns with beam colours, ion, splash and burn; modelled melee tools), 10 grenades (sticky,
   incendiary, smoke that blocks sight, flashbang stun, cryo slow, rad cloud, plasma, nail bleed, proximity mine,
   dynamite) and 20 chems. Town life (`town_life.gd`): baked navmeshes, people walk to chairs, desks, shelves and
   benches near home and sit or work there; you can sit too. Gunmen hold their aim while moving (`aim_hold.gd`) with
   their own sidearms. Flying vultures (`vulture.gd`). Haven 12's atrium walls, the tunnel behind the great door,
   decor set on real surfaces (`Furniture.surfaces`), signs kept clear, thinner rooms, desks under floating
   terminals; fires settle out of rocks; bodies step out of solids (`clear_spot.gd`). Save from the pause menu, a
   Settings panel with on-screen DEV/FORGE buttons. Quest tracking stays on what you follow; side quests fail
   when their giver dies. **In-app updates** (`patcher.gd`, `updater.gd`): each release carries a patch pack cut
   against the base build's full pack (`godot/patch_base.txt`; "self" makes a build the new base), downloaded from
   the title screen and mounted at the next start.
12. **godot-14:** *Status: shipped as the first in-game update (patch against build 13).* Navigation rebuilt for
   townspeople (`town_life.gd`): their own navigation map, apart from the coarse one hostiles use; indoor rooms and
   Haven 12 baked whole, the valley in 32 m tiles with trimmed borders so they join; gathering spots at wells,
   fires, boards and gaming tables; neighbours stop to talk; people step round you; companions path round walls;
   walkable-distance spot choice; stuck recovery; a Developer-menu navmesh view. A Graphics menu (presets to Ultra
   plus thirteen settings, `quality.gd`). Fifteen perks with level gates. Sixteen foods. The Tuttle hill family at
   Hollerback Holler, synths, guardbots and power-armoured Iron Wardens (`machine.gd`), and wearable power armour.
   The gunsmith (`gun_mods.gd`, Pip menu GUNSMITH): seventeen parts across six slots. Voices read for mood
   (`tools/voice/gen.py`).
13. **godot-15:** *Status: shipped as a new base (one reinstall, for the new launcher icon) plus a patch for
   build 13 installs.* A new icon (ember sun, ridges, the relay tower). Townspeople no longer repeat themselves:
   each sit, chat, stand or job is a beat of its own length, chats take turns, spots they've just used are avoided,
   idles vary. **The map doubled, eastward** (`tools/terrain/expand.py`, keeping the original square as it was): the
   Ashwood, 2 km by 1 km, reached by Kettle Pass, a road cut through the old east wall (props and colliders there
   settle with the ground, `chunks.cut_at`). Roads, mesas, a dry river canyon, mountain edges, and a forest of
   low-poly pines and dead snags (`flora.gd`, `data/flora.png`; near and far detail, a sparse horizon forest).
   Settlements and ruins built in code (`frontier.gd`, `builds.gdshader`: boards, tin, canvas, logs, concrete), walls
   in the solid list so both navigations route through the doors: **Cinder Gap** (store, saloon, clinic, town
   hall, workshop with a bench, market, water tower, gate), the **Ashborn** camp (palisade, hide tents, longhouse,
   totems, the Ember Mother), **Crane's Lookout** (a climbable fire tower and a cabin), **Mercy Falls** (ruins and
   the hospital) and the **Sunset Drive-In**. Rooms are furnished and lit. Twenty-three new people
   (`tools/story/story15.mjs`, with flag-gated people, story fights, guards, shops and places in the story format),
   four quests that cross each other (The Mercy Road, The Burning Man, Mercy's Ledger, Last Call), new factions,
   a fire-watch broadcast, twelve epilogue lines, voiced. The Pip map keeps the map's shape. `--ashtest` plays all of
   it through.
14. **godot-16:** *Status: shipped as a patch (to build 15, and to build 13).* **The map is three times its old
   size**: a northern band 2 km by 512 m (`tools/terrain/north.py`; z0 is -1012 so the old chunk files keep their
   grid, re-numbered at load by `region.glb_origin`). Three roads climb into it: Northgate above KDST Radio, the
   Airfield Cut above Kestrel Airfield, and a gap through the Ashwood's northern ridge. **Stillwater** on its
   reservoir (a real lake you can wade, piers, skiffs, a windmill, co-op, smokehouse, harbourmaster, boathouse),
   **Old Meridian** (a street grid of ruined towers painted with empty windows, fallen blocks and burnt cars, the
   Highrisers' **Spire** with its lobby and cage, and the **Garage** market under a parking deck) and the **Glass
   Bowl** (a bomb crater floored with glass and glowing pools, the **Children of the Glass** on its rim, **Silo 9**
   and its blockhouse at the bottom). Seventeen new people, three quests (Still Waters, The Spire, Children of the
   Glass) that all meet at the silo's console, a sermon on the shortwave, nine epilogue lines, voiced; world points
   can open a conversation (`G.talk`). `--northtest` plays it through.
15. **godot-17:** *Status: shipped as a patch (to build 15, and to build 13); a fresh install also gets the new
   intro.* Fixes from play: Dustwell's floating roof slab settled (`data/settle.json`, `tools/settle/`); the brown
   "dust balls" are soft specks now (`dust.gdshader`); steps climb without a jump; run 8.6 m/s, higher jump; no
   talking to the downed; red prompts for crimes, no stealing through walls, more to steal indoors; **pickpocketing**
   (`pockets.gd`: crouch behind someone; caught three times and they fight); **storage** in any container, corpse or
   safe (PUT IN); the chem button forgets what you've run out of; corpses drop cleanly; gunmen only hold their aim
   facing you. **Explosive drums** (`barrels.gd`): the WebView build's baked red drums (and their glowing yellow
   plate) folded away and replaced by live ones that burn when shot, blow and chain, plus one beside most raider
   camps. **Ammo types** (`ammo.gd`): the 10mm pistol takes 10mm; FMJ (+60% on machines, slugs for shotguns) and
   explosive (bursts) for every calibre, crafted, looted and sold; tap the ammo count to switch. The build 13 guns
   finally reach traders (their stock had been merged into a table nothing read). Terminal menus scroll; a lockout
   says it clears tomorrow. **The Meridian reactor** opens into a 16 x 14 m containment hall (`reactor.gd`, Frontier
   `reactor_hall`): the vessel, coolant loop, tanks, desks; the Glow Brute starts caged, the klaxon goes when you
   walk in and the cell lifts four seconds later; big enemies' collision now fits their models. **Hangar 2** has
   the crashed relief plane and a blinking flight recorder. **Interface:** an animated Ashfall intro and themed
   loading screen (`loader.gd`, `boot.gd`, `boot_splash.png`) in place of Godot's splash; Load Game on the title and
   pause menus; quest ACTIVE/HISTORY tabs; a trade card with stats, comparison and a quantity slider, the list keeping
   its place; a corner radar and red hostile ticks on the compass; the map pans, pinch-zooms and travels on a double
   tap; holster (HOLS). **AI:** enemies hunt where they last saw you and give up and go home; gangs break when their
   own fall; townsfolk keep hours. Biscuit is a rigged, animated dog (glTF sample Fox, CC0/CC-BY). **The story**
   (`story17.mjs`): **Lantern Row**, a new trading street, and the **Quiet Hands** thieves' guild (Light Fingers, The
   Collector's Safe, Old Debts; members pick pockets easier and Dace pays better); **Starfall**, a crashed saucer, Orrin
   Pike and the Visitor (Lights Over the Ridge, Not Alone, The Signal Home, the Visitor's Blaster); **the main
   quest's third act** at the **Camp of the Door** outside Haven 12 (The Long Way Home, Dials and Needles, Fish Glue
   and Tyre Rubber, Iron and Fire, Haven's Doubt, The Last Nine Days: 21 stages, so the main line runs 13 quests and
   39 stages); radio news that follows what you've done; voiced. `--b17test` plays it through.
16. **godot-18:** *Status: shipped as a patch (to build 15, and to build 13).* **The roads' stair-steps are gone**
   (`tools/terrain/destep.py`): build 15 and 16 laid roads from height samples 4 m apart, each cell taking its
   nearest sample, so a road down a slope became a flight of treads (2 m risers into the Glass Bowl). Every road is
   re-laid from a surface interpolated along it, the treads are rounded off, and a finer pass catches the small ones;
   the original square's pass cuts are only smoothed, with cut grids so its props follow the ground down.
   **Silo 9 for real** (`silo.gd`, `story18.mjs`): the two-man rule (the Iron Angel's key and Tobiah's override);
   launch, and a klaxon counts forty-five seconds, the missile climbs out of the hatch on fire and smoke, rolls
   north-east and bursts over the old test range: a white sky, a fireball, a mushroom cloud on the horizon for the
   day, the rumble a dozen seconds later, fallout over the north for a day. Scuttle the core, and you have ninety
   seconds to clear the Bowl's floor before the silo folds into the ground (rubble from then on). The Ash Wind follows a
   launch (warn Nell, shut the reservoir sluice, get the Children under a roof, wait it out); an emergency broadcast,
   radio news, epilogue lines. `--silo=launch|scuttle`, `--b18test`.
17. **godot-19:** *Status: shipped as a patch (to build 15, and to build 13).* **Fixes:** road signs letter each line
   to fit the board and only on their own side (no more mirrored text through the board); the vault's cog door turns
   its spokes off the "12" and gains a backing plate; the corner radar is gone (the compass ticks stay); **hold SWAP
   to holster** (tap to swap), the HOLS button removed. **Starfall remade:** a tilted saucer with tiers, rim ports, a
   cracked dome, a breach and a soil berm, one leg torn off, and its plating and the furrow lying on the ground (every
   piece follows the terrain). **Towns fight back** (`npc.gd _defend`): armed guards shoot the raiders, beasts and
   ghouls that come into town (and draw their fire), townsfolk run, and nobody in town dies of it (they go down and get
   up); kills by guards pay you no XP. **Raids** (`events.gd _raid`) hit a guarded settlement you're standing in now
   and then. **Factions count:** a hated faction's guards attack on sight, its folk won't talk and its traders won't
   trade; a respected one's guards cover you further out and hit harder. New guards: two Dustwell deputies and a vault
   officer at the Camp of the Door (`story19.mjs`, voiced). **Settlement detail:** sandbag posts, washing lines, crate
   stacks, water tanks, tables, scrap heaps and lamp posts in the Camp of the Door, Dustwell, Cinder Gap, Lantern Row,
   Stillwater, the Ashborn camp, the Garage and the Children's camp. **Floating:** watchtower and water-tower legs reach
   the ground on slopes; tents, shrines and parked wrecks settle into slopes (`--floataudit` lists what still hangs).
   `--b19test`.
18. **godot-20:** *Status: shipped as a patch (to build 15, and to build 13); the APK is renamed.* The game is
   **Ashfall: Meridian** on the phone (app name, project name, `AshfallMeridian.apk`, release titles); the name
   change itself needs the new APK installed, since a patch can't change project settings. **Doors:** every frontier
   shack, hall and cabin has a board ramp up to its floor, and the step-up tries a low step before a tall one, so you
   walk in without jumping (`--doortest` walks into all of them). **Sprint** 7.9 m/s, between build 16's 7.2 and build
   17's 8.6. **Prompts follow the crosshair:** containers and pickups must be in front of your eyes to be offered, the
   closest to the centre wins, and looking away takes the prompt and the USE with it; a container whose mesh never
   made it into the world (the reactor's safe) gets a visible safe or footlocker where it stands. **Floating:**
   barrels found their floor through an invisible collider (fixed), fence runs follow slopes sheet by sheet, log seats
   have closed ends and sit into the ground (no seeing through them at the Camp of the Door). **Biscuit** bites for
   75% and a little slower. **Camp of the Door:** a cook pot on a tripod, more seats, a tarp over the stores, a
   generator and aerial, a notice board, string lights, a garden plot, drums, pallets and tyres. **New places:**
   Wayside 9 (a fuel stop raiders hold as a toll post), Holloway Farm (burnt, ghouls in the fields) and Relay Station K
   (sentry robots still on guard), each with a stash. `--b20test`.
19. **godot-21:** *Status: shipped as a patch (to build 15, and to build 13); the new boot splash needs the APK.*
   **Main menu** (`scripts/menu.gd`, `MainMenu`): full screen over the live valley, a camera drifting round where you
   are through three slow views, the menu down the left (RESUME when you came from the game, CONTINUE with where and
   when, NEW GAME with an are-you-sure when there's a game to lose, LOAD GAME, OPTIONS, CREDITS, EXPLORE THE VALLEY,
   QUIT), pages in a panel on the right. **Options:** graphics preset, field of view, look sensitivity, volume, radio
   volume, camera, DEV and FORGE buttons (sensitivity and volumes are new, in `Settings`). **Intro and loading:** two
   cards before the title (powered by Godot, headphones), a framed gauge with a gradient fill, a light running along
   it, a glowing edge, tenth ticks and a boxed percentage; a stage line (loading, building, streaming, ready); tips that
   change every seven seconds. The boot splash is now the intro's own last frame. **Quests for build 20's places**
   (`story21.mjs`): The Toll Road (Hob Kettering, Wayside 9), Holloway Ground (Ada Holloway, the farm and its
   graves), Dead Air (Relay Station K's sentries and console, a broadcast on Meridian Free Radio). The old screenshots'
   issues re-checked in the game: Lantern Row's sign, tower and fence, the camp's logs, the reactor safe, door steps.
   `--b21test`, `--screen=menu[:options|load|credits]`, `--screen=loader:intro|splash`, `--heights=x0,z0,x1,z1,step`.
20. **godot-22:** *Status: shipped as a patch (to build 15, and to build 13).* **Falls hurt:** a drop of more than
   about four metres costs health (six metres a little, twelve nearly half), with a thud and a grunt; anything more
   than a hop lands with a thud. **Sounds:** a hit lands with a punch (Kenney's Impact Sounds, CC0) and now and then a
   grunt; a jump rustles and sometimes grunts (grunts voiced with Piper, like everyone else). **The fire lookout**
   (`_lookout`) is rebuilt to be climbed: eight railed flights, landings railed on their open side, a U-shaped cab
   floor that no longer sits on your head over the last flights, legs and the first step down to the ground, a cot,
   a stool, the aerial, a bell (`--towertest` climbs it). **Fire pits** (`FireFX.make_pit`): every campfire burns in a
   ring of stones or of bricks, a cast-iron stove, a cut-down drum, or a cross of logs on its ashes, chosen by where
   it is. **Rifles to the shoulder** (`Humanoid.shoulder_gun`): in third person and in raider hands a long gun rides
   the chest with the butt in the shoulder and both hands on it, so it no longer points at the sky; the gun stays up
   on your aim whatever your legs do. **Sharpshooters** carry rifles, keep 26-58 m off, back away when you close in
   and hold still to shoot; the last gunmen still on the old stick rig (sharpshooters, hunters, hired guns,
   warlords) are people now. **Two-handed tools** (axe, pickaxe, shovel, sledge, bat) take both hands in first
   person and no longer run back past the camera. `--b22test`, `--sidecam_e`, `--tpside`.
21. **godot-23:** *Status: shipped as a patch (to build 15, and to build 13).* **DEV, Silo 9:** LAUNCH, SCUTTLE, WATCH
   THE LAUNCH / WATCH THE SCUTTLE (from the ridge), TO THE SILO and RESET in the DEV panel's world page. **Gun
   add-ons** sit on the gun: the scope and the reflex sight find the real top of the receiver from the mesh, the
   muzzle line from its front slice (`GunMods._points/_section`). **Gunfire** (`scripts/gunfx.gd`, `GunFX`): a flame
   of crossed quads and a star at the muzzle along the aim, sparks, a puff of smoke, a brass case that's thrown,
   bounces and clicks; tracers that travel; enemies flash too. **Impacts** by what's hit (dirt, stone, wood, metal):
   dust, chips, sparks, and a hole left on the surface (the last 48); an enemy's miss kicks up the ground near you.
   **Interiors:** every furnished room (the town's cells, Haven 12) is mapped on a 20 cm grid of where a body fits;
   doorways and passages (floor between two walls no wider than 1.7 m) are kept clear of furniture, chairs included,
   and nothing hangs on a door jamb; if furniture still cuts floor off from the door the piece responsible is taken
   out with what stood on it. The old map's own loose pieces in a doorway go (the clinics' armchairs); a shut door
   baked into a room's model opens now (you step through, like the town's other doors). `--area=cells --furntest`,
   `--area=vault --furntest`. **Furniture and lights:** the view across a wide phone screen is held to 100 degrees
   (75 tall was nearly 120 across, which made every room and chair look tiny and far), the arms drawn as before;
   frontier homes get a real table with the lantern on it, the clinic's chair at the doctor's table; hanging lights
   (`Furniture.hang`) hang from the actual ceiling, flush on a ceiling plate, no lower than 2.15 m, the shack's lamp
   at the bulb. **Light:** indoors (a frontier building, or roofed and walled in) the sky's fill eases down and the
   lamps do the work; rain stays outside; the town's rooms have less flat fill and their lamps cast shadows in the
   room you're in; Haven 12 a little dimmer; outdoors a little more sun and less fill. `--b23test`, `--fireat=N`,
   `--tonemap=filmic|agx|aces`.
22. **godot-24:** *Status: shipped as a patch (to build 15) and as its own base.* **Updates:** every build is now a
   base of its own (its APK says so and its whole pack, base-N.pck, stays on its release); each release carries
   patches for the last three bases before it, plus build 15's (the base of every APK from 15 to 23). Build 13's
   patch goes from build 25 (build 24's own release still carried one: the roll reached back past the builds that
   kept no base pack; it now starts at 24, ROLL_FROM in the workflow). **Starfall remade:** a smooth solid saucer half buried in its
   furrow, the breach on the north side, a cracked dome over a furnished cockpit, the pod split open in its own
   scorch, crystals, a probe, the dead crew, the Visitor and the Wreck Sentinel as greys; nothing loose floats, and
   you can't walk into the cockpit through its hull. **Quest spots glint** (`QuestGlint`): anything a quest wants
   searched shows a slow pale glint within 50 m and a ring of light on the ground close by, while the quest wants
   it. **Floating things:** wrecks are laid on the slope with all four wheels down; seats, benches, tables, crates
   and the like come down to the lowest ground under them; eleven of the old map's props that hung in the air are
   lowered (`--propscan`, data/settle.json); the fire lookout's cab has a ceiling, its aerial on the roof's peak and
   its bell on a bracket. **Dead trees regrown** (`DeadTree`, data/deadtrees.json from tools/trees/scan.gd): the 910
   old dead trees, whose limbs were flat boards stood off the trunk, are grown again where they stood and as tall:
   a tapering crooked trunk, six to nine limbs from inside it, forks, the old mossy bark wrapped round. **Arms:**
   rifles held with the elbows down and the shoulders out of view; the sledge's left hand grips the haft. **Havoc**
   (`Havoc`): tyres, traffic cones, buckets, cans, crates and fuel cans lie round the settlements and road stops
   (no cones out in the wilds), real rigid bodies that a bullet sends skidding, a blast throws and you kick aside.
   **People:** clothes fitted (no borrowed sleeves or foreign armour, hats seated), grime on clothes, raiders in gas
   masks, bandanas, goggles, tyre and scrap pauldrons, bandoliers and scrap-plate vests; faces with eye colour,
   brows, scars, glasses. **Hit glow:** a broad soft glow towards the screen edge on the side a hit came from (no
   more thin red slivers round the sights), none in god mode. **Intro and loading:** no engine card and no tap to
   skip; WhitCo Productions first (the name kindling letter by letter, burning away into the ash) with the sky
   rising behind it into the title; the boot splash is the dark the intro starts from; 38 tips; the far ground is
   built a few chunks a frame behind the loading screen (no more eight-second freeze) and the bar follows it.
   `--b24test`, `--quest=id`, `--at=x,z,yaw,pitch,height`.
23. **godot-25:** carried over: the main quest longer still (a fourth act between Meridian and the door: the
   Overseer's secret, the other vaults), real road meshes and terrain variety (washes, rock shelves, erosion), better
   ground and building textures, more GitHub character models for townspeople, interiors (the Spire's upper floors,
   the silo shaft), companions from the north, a Forge tidy-up (brick and more materials), a closer pass on the
   first-person pistol hands, and the WebView build retired.
