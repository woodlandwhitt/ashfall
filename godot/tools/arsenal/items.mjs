// Build 13's arsenal. Every gun has a model of its own now; these are the thirty new weapons, ten grenades and
// twenty chems, plus the new models for the old guns that used to share one.
// Weapon fields as in game.json (kind, dmg, rof seconds between shots, mag, ammo, range, spread, pellets) and:
//   glb      the model under guns/          finish   a tint over its paint: rust, nickel, gold, black, olive, bone
//   beam     tracer colour for energy guns  splash   a small blast where the bolt lands (radius)
//   ion      x damage against robots        burn     sets the target alight (damage per second, seconds)
//   proj     'rocket': a slow round that explodes where it lands (radius r, uses dmg)
//   mglb     melee model (built along +Y, handle at the origin), ms its scale, two for two-handed swings

const W = (n, o) => ({n, t: 'weapon', ...o});
const E = (n, o) => W(n, {kind: 'energy', ammo: 'cell', energy: true, ...o});

// the old guns that shared a model get one of their own
const REFIT = {
  pipe_pistol: {glb: 'lp_pistol', finish: 'rust'},
  longhorn: {glb: 'lp_revolver'},
  brannock_longhorn: {glb: 'lp_revolver', finish: 'gold'},
  rattler: {glb: 'lp_smg', finish: 'olive'},
  hunting_rifle: {glb: 'lp_rifle', finish: 'bone'},
  scatter_gun: {glb: 'lp_shotgun', finish: 'rust'},
  street_sweeper: {glb: 'lp_drum_shotgun'},
  arc_pistol: {glb: 'bl/blaster_b', beam: '#66ccff'},
  arc_rifle: {glb: 'bl/blaster_d', beam: '#66ccff'},
  lever_rifle: {glb: 'lp_carbine', finish: 'bone'},
  carbine: {glb: 'lp_burst_rifle'},
  marksman: {glb: 'lp_marksman'},
  ion_caster: {glb: 'bl/blaster_l', beam: '#7fa8ff', ion: 2},
  buzzsaw: {glb: 'lp_minigun', finish: 'rust'},
};

const NEW = {
  // ---- ballistic and explosive
  derringer: W('Card Sharp Derringer', {kind: 'pistol', glb: 'lp_derringer', finish: 'nickel', w: 1, v: 110, dmg: 36, rof: 0.32, ammo: 'ammo_44', mag: 2, range: 45, spread: 0.035,
    desc: 'Two barrels, two chances, no third. A Spur gambler\'s sleeve gun.'}),
  stinger: W('Tin Row Stinger', {kind: 'smg', glb: 'lp_machine_pistol', w: 2.5, v: 160, dmg: 10, rof: 0.07, ammo: 'ammo_9', mag: 22, range: 60, spread: 0.05,
    desc: 'A pistol filed down to fire as long as you hold the trigger. Hard to hold on target, harder to stop.'}),
  ridgeback: W('Ridgeback Battle Rifle', {kind: 'rifle', glb: 'lp_battle_rifle', finish: 'olive', w: 9, v: 520, dmg: 44, rof: 0.3, ammo: 'ammo_rifle', mag: 20, range: 190, spread: 0.008,
    desc: 'Heavy, long and built for fighting from a ridge. The bipod folds under the barrel.'}),
  gantry_bullpup: W('Gantry Bullpup', {kind: 'smg', glb: 'lp_bullpup', finish: 'black', w: 6, v: 430, dmg: 25, rof: 0.11, ammo: 'ammo_rifle', mag: 30, range: 140, spread: 0.014,
    desc: 'Short enough for a corridor, long enough for the yard. Gantry security bought a crate of them.'}),
  long_silence: W('Long Silence', {kind: 'rifle', glb: 'lp_sniper', w: 11, v: 780, dmg: 96, rof: 1.3, ammo: 'ammo_rifle', mag: 5, range: 320, spread: 0.002,
    desc: 'A bolt-action rifle with a scope as long as your forearm. Whoever it\'s pointed at never hears it.'}),
  rocket_tube: W('Rocket Tube', {kind: 'rifle', glb: 'lp_launcher', finish: 'olive', w: 14, v: 900, dmg: 150, rof: 1.6, ammo: 'ammo_rocket', mag: 1, range: 200, spread: 0.004, proj: 'rocket', r: 6, snd: 'shotgun_far',
    desc: 'Shoulder-fired, single shot, reloads slow. It ends arguments with robots, trucks and anything in between.'}),
  capacitor_rifle: E('Capacitor Rifle', {glb: 'lp_charge_rifle', w: 8, v: 640, dmg: 72, rof: 1.0, mag: 6, range: 200, spread: 0.003, beam: '#ffe066',
    desc: 'Charges a bank of salvaged capacitors and dumps them down the barrel in one crack of lightning.'}),
  beamer: E('Beamer', {glb: 'lp_beamer', w: 6, v: 420, dmg: 17, rof: 0.1, mag: 30, range: 110, spread: 0.01, beam: '#ff5544',
    desc: 'A prewar crowd-control laser. Ticks out a stream of short red pulses.'}),
  // ---- energy, from the blaster kit
  pulse_carbine: E('Pulse Carbine', {glb: 'bl/blaster_a', finish: 'black', w: 6, v: 470, dmg: 24, rof: 0.14, mag: 24, range: 130, spread: 0.01, beam: '#55aaff',
    desc: 'Meridian\'s last security carbine. Each pulse leaves a blue afterimage in the air.'}),
  tesla_pistol: E('Tesla Pistol', {glb: 'bl/blaster_c', w: 3, v: 380, dmg: 30, rof: 0.45, mag: 10, range: 60, spread: 0.02, beam: '#cfe8ff', ion: 2.2,
    desc: 'A coil of copper and a prayer. Robots hate it; it fries their boards from the inside.'}),
  plasma_lance: E('Plasma Lance', {glb: 'bl/blaster_e', finish: 'olive', w: 12, v: 980, dmg: 88, rof: 1.2, mag: 5, range: 260, spread: 0.002, beam: '#66ff66', splash: 1.8,
    desc: 'A long-barrelled plasma rifle meant for a tank\'s turret. Every bolt lands like a dropped sun.'}),
  heavy_plasma: E('Heavy Plasma Rifle', {glb: 'bl/blaster_f', w: 11, v: 860, dmg: 48, rof: 0.38, mag: 12, range: 140, spread: 0.01, beam: '#77ff55', splash: 1.4,
    desc: 'Spits green bolts that splash and stick. It\'s heavy because the coolant is heavy.'}),
  ion_repeater: E('Ion Repeater', {glb: 'bl/blaster_g', finish: 'black', w: 8, v: 690, dmg: 15, rof: 0.085, mag: 40, range: 100, spread: 0.018, beam: '#88aaff', ion: 2.5,
    desc: 'Hoses out ionised bolts. Barely tickles a raider. Shreds a Sentinel.'}),
  microwave: E('Microwave Emitter', {glb: 'bl/blaster_h', w: 5, v: 520, dmg: 11, rof: 0.1, mag: 30, range: 22, spread: 0.03, beam: '#ffaa44', burn: [6, 3],
    desc: 'A kitchen appliance that went to war. Short range, and anything it touches keeps cooking afterwards.'}),
  static_pistol: E('Static Pistol', {glb: 'bl/blaster_i', finish: 'rust', w: 2.5, v: 240, dmg: 18, rof: 0.22, mag: 16, range: 70, spread: 0.02, beam: '#bfd8ff', ion: 1.8,
    desc: 'A homemade zapper built from a tram\'s brake coil. Crackles, pops, and sometimes bites the shooter\'s thumb.'}),
  laser_pistol: E('Laser Pistol', {glb: 'bl/blaster_j', w: 2.5, v: 300, dmg: 22, rof: 0.3, mag: 18, range: 120, spread: 0.006, beam: '#ff4433',
    desc: 'Police issue before the end. A red beam, a smell of hot metal, a very clean hole.'}),
  glow_pistol: E('Glow Pistol', {glb: 'bl/blaster_k', w: 3, v: 340, dmg: 21, rof: 0.35, mag: 14, range: 80, spread: 0.012, beam: '#c8ff44', burn: [4, 4],
    desc: 'Fires slugs of hot glow. The wound keeps glowing after you\'ve walked away.'}),
  photon_smg: E('Photon SMG', {glb: 'bl/blaster_m', finish: 'black', w: 4, v: 460, dmg: 12, rof: 0.075, mag: 36, range: 80, spread: 0.022, beam: '#ff6655',
    desc: 'A laser with a hair trigger. Paints a red hose across whatever you point it at.'}),
  laser_rifle: E('Laser Rifle', {glb: 'bl/blaster_n', w: 7, v: 560, dmg: 36, rof: 0.34, mag: 20, range: 180, spread: 0.004, beam: '#ff3322',
    desc: 'The army\'s laser, long-barrelled and steady. Quiet enough to hear the target hit the ground.'}),
  gamma_blunderbuss: E('Gamma Blunderbuss', {glb: 'bl/blaster_o', finish: 'rust', w: 8, v: 610, dmg: 15, rof: 0.9, mag: 4, range: 30, spread: 0.09, pellets: 7, beam: '#99ff33',
    desc: 'A wide bell of a muzzle that sprays gamma pellets. Pointing it means hitting something.'}),
  plasma_carbine: E('Plasma Carbine', {glb: 'bl/blaster_p', w: 7, v: 680, dmg: 33, rof: 0.27, mag: 16, range: 120, spread: 0.01, beam: '#55ff88', splash: 1.0,
    desc: 'A short plasma rifle for close work. Green, loud, and hot to the touch.'}),
  welder_rifle: E('Arc Welder Rifle', {glb: 'bl/blaster_q', finish: 'rust', w: 9, v: 540, dmg: 8, rof: 0.05, mag: 60, range: 16, spread: 0.035, beam: '#d6f0ff', burn: [8, 2],
    desc: 'A shipyard welding rig with a trigger bolted on. A continuous crackling arc that melts what it touches.'}),
  disintegrator: E('Prototype Disintegrator', {glb: 'bl/blaster_r', finish: 'black', w: 9, v: 1600, dmg: 120, rof: 1.8, mag: 3, range: 160, spread: 0.003, beam: '#cc66ff', splash: 1.2,
    desc: 'A Meridian lab prototype stamped DO NOT REMOVE. Whatever it kills is left as a fine violet ash.'}),
  // ---- melee
  fire_axe: W('Fire Axe', {kind: 'melee', mglb: 'ml/tool_axe', ms: 3.3, two: true, w: 5, v: 90, dmg: 46, rof: 0.75, range: 2.9,
    desc: 'Red paint mostly gone. The edge has been kept sharp by someone who meant it.'}),
  claw_hammer: W('Claw Hammer', {kind: 'melee', mglb: 'ml/tool_hammer', ms: 1.7, w: 1.5, v: 30, dmg: 24, rof: 0.42, range: 2.4,
    desc: 'Builds a shack, takes it apart, settles a dispute.'}),
  pickaxe: W('Miner\'s Pickaxe', {kind: 'melee', mglb: 'ml/tool_pickaxe', ms: 3.4, two: true, w: 6, v: 80, dmg: 44, rof: 0.85, range: 2.9,
    desc: 'From the Saltpan quarries. Goes through rock; goes through armour.'}),
  shovel: W('Trench Shovel', {kind: 'melee', mglb: 'ml/tool_shovel', ms: 3.1, two: true, w: 4, v: 45, dmg: 30, rof: 0.6, range: 2.8,
    desc: 'Dig a hole. Fill it. A grim joke along the old road.'}),
  cleaver: W('Butcher\'s Cleaver', {kind: 'melee', mglb: 'ml/knifeRound_sharp', ms: 0.95, w: 1.2, v: 40, dmg: 25, rof: 0.4, range: 2.3,
    desc: 'Heavy at the tip. Hollis would like it back.'}),
  bowie: W('Bowie Knife', {kind: 'melee', mglb: 'ml/knife_sharp', ms: 0.95, w: 1, v: 60, dmg: 28, rof: 0.36, range: 2.5,
    desc: 'Long, clipped point, brass guard. A knife for people who expect to be in a knife fight.'}),
  lead_pipe: W('Lead Pipe', {kind: 'melee', w: 2.5, v: 15, dmg: 22, rof: 0.5, range: 2.6,
    desc: 'Plumbing, repurposed.'}),
  // ---- ammo
  ammo_rocket: {n: 'Rocket', t: 'ammo', w: 2, v: 45, desc: 'A finned rocket for the Rocket Tube. Handle gently.'},
};

// ---- grenades: thrown with NADE once readied. Kinds as in nade.gd
const N = (n, nade, o) => ({n, t: 'aid', throw: true, w: 0.5, nade, ...o});
const NADES = {
  frag: {glb: 'lp_frag', gs: 1.0},
  sticky: N('Sticky Bomb', {r: 7, dmg: 110, fuse: 2.0, stick: true, glb: 'lp_sticky', gs: 1.0}, {v: 85,
    desc: 'Glue on one side, plastic explosive on the other. Clings to whatever it hits, and goes off two seconds later.'}),
  incendiary: N('Incendiary Grenade', {fire: true, r: 6, dmg: 20, dur: 11, fuse: 1.8, glb: 'bl/grenade_a', gs: 0.42, col: '#b04a2a'}, {v: 70,
    desc: 'Thermite and a fuse. Bursts into a wide patch of burning ground that lasts a long time.'}),
  smoke: N('Smoke Grenade', {smoke: 14, r: 6, dmg: 0, fuse: 1.5, glb: 'bl/grenade_b', gs: 0.42, col: '#7a7f74'}, {v: 35,
    desc: 'A grey cloud that nobody can see through, for fourteen seconds. Break contact, cross the open ground, or slip past.'}),
  flashbang: N('Flashbang', {flash: 4.5, r: 9, dmg: 4, fuse: 1.4, col: '#9aa0a6'}, {v: 55,
    desc: 'A blinding crack that leaves everyone nearby stunned and staggering for a few seconds. Look away.'}),
  cryo: N('Cryo Grenade', {cryo: 8, r: 7, dmg: 30, fuse: 1.6, col: '#7fd0ff'}, {v: 95,
    desc: 'Liquid nitrogen under pressure. Freezes everything nearby to a crawl for eight seconds.'}),
  rad_nade: N('Rad Grenade', {rad: 12, r: 6, dmg: 9, fuse: 1.8, col: '#c9e23a'}, {v: 75,
    desc: 'Glowing slag in a lead shell. Leaves a cloud that sickens anything standing in it, you included.'}),
  plasma_nade: N('Plasma Grenade', {r: 7, dmg: 170, fuse: 1.6, plasma: true, col: '#55ff77'}, {v: 140,
    desc: 'A sphere of contained plasma. When the containment goes, so does everything in seven metres.'}),
  nail_bomb: N('Nail Bomb', {r: 8, dmg: 100, fuse: 2.0, nails: 3, col: '#8b8f93'}, {v: 40,
    desc: 'A coffee tin of roofing nails and black powder. The ones it doesn\'t kill keep bleeding.'}),
  prox_mine: N('Proximity Mine', {r: 6, dmg: 150, fuse: 1.0, mine: 2.6, col: '#5c6b48'}, {v: 110,
    desc: 'Throw it down; it arms in a second and goes off when something walks over it. Something includes you.'}),
  dynamite: N('Bundle of Dynamite', {r: 11, dmg: 165, fuse: 3.2, col: '#b8322a'}, {v: 65,
    desc: 'Three sticks, one long fuse. Count to three and throw it far.'}),
};

// ---- chems: an item that names a drug below, and the drug's effect (as Game.L.consts.DRUGS). Effects:
// speed ap reload spread melee fov (multipliers), dr regen rad heart night warp exposure (added), sat con tr tg tb
// (look), stats (S.P.E.C.I.A.L. changes while it lasts), crash (an after-effect), addict (chance)
const D = (n, o) => ({n, onset: 3, fade: 12, addict: 0.08, lines: [], ...o});
const DRUGS = {
  hush: D('Hush', {dur: 120, fx: {dr: 25, regen: 0.15, sat: 0.8, con: 0.95, exposure: -0.03}, addict: 0.12,
    lines: ['The pain is still there. It just stopped talking.', 'Everything goes soft and far away.']}),
  redline: D('Redline', {dur: 60, onset: 1, fade: 6, fx: {melee: 1.8, speed: 1.12, tr: 1.25, tg: 0.85, tb: 0.85, sat: 1.2, heart: 1.8}, stats: {might: 2, aim: -2},
    crash: {dur: 40, fx: {speed: 0.85, melee: 0.8, sat: 0.7}}, addict: 0.18,
    lines: ['Your vision goes red at the edges. You want to hit something.', 'Teeth clenched. Fists ready.']}),
  quickstep: D('Quickstep', {dur: 75, fx: {speed: 1.22, ap: 1.4, sat: 1.1, con: 1.05, heart: 1.2}, stats: {agility: 3},
    crash: {dur: 30, fx: {speed: 0.8, ap: 0.6}}, addict: 0.15, lines: ['Your legs are springs.', 'You could outrun a bullet. Probably not. Maybe.']}),
  lucid: D('Lucid', {dur: 180, fx: {con: 1.12, sat: 1.05, exposure: 0.04, spread: 0.9}, stats: {intellect: 3, aim: 1},
    lines: ['Your thoughts line up and stand to attention.', 'Every problem has an obvious answer. You can see it.']}),
  silver_tongue: D('Silver Tongue', {dur: 200, fx: {sat: 1.1, tr: 1.06, tb: 0.95, exposure: 0.03}, stats: {charm: 3}, addict: 0.05,
    lines: ['Words arrive already polished.', 'You feel very, very persuasive.']}),
  ironhide: D('Ironhide', {dur: 90, fx: {dr: 45, speed: 0.75, sat: 0.7, con: 1.1}, stats: {endurance: 2, agility: -2}, addict: 0.1,
    lines: ['Your skin goes grey and hard. Bullets will have to try.']}),
  glowcap_tea: D('Glowcap Tea', {dur: 150, onset: 6, fade: 20, fx: {regen: 0.6, rad: 0.08, tg: 1.08, sat: 1.05}, addict: 0.02,
    lines: ['Earthy, faintly luminous. Your cuts close up as you watch.']}),
  nightjar: D('Nightjar', {dur: 240, fx: {night: 1.3, tg: 1.12, tr: 0.9, sat: 0.65}, stats: {aim: 1},
    lines: ['The dark turns to a green dusk. You can see everything.']}),
  overclock: D('Overclock', {dur: 45, onset: 1, fade: 5, fx: {ap: 2.4, reload: 0.5, speed: 1.08, heart: 2.8, con: 1.2, warp: 0.1}, crash: {dur: 60, fx: {ap: 0.4, speed: 0.8, sat: 0.6, exposure: -0.08}},
    addict: 0.25, lines: ['Your heart hits a speed it was never rated for.', 'Time is going too slowly. Everything else is very fast. You are everything else.']}),
  bloodpack: D('Bloodpack', {dur: 30, onset: 1, fade: 4, fx: {regen: 2.2}, addict: 0, lines: ['Warm, thick, and somebody else\'s. Your colour comes back.']}),
  clover: D('Four-Leaf', {dur: 300, fx: {sat: 1.18, tg: 1.05, exposure: 0.05}, stats: {luck: 3}, addict: 0.04,
    lines: ['The world feels like it\'s on your side for once.']}),
  grit: D('Grit', {dur: 150, fx: {dr: 12, sat: 0.9, con: 1.08}, stats: {endurance: 3, might: 1}, addict: 0.1,
    lines: ['You chew it and spit. You can take a beating now.']}),
  bullshot: D('Bull Shot', {dur: 120, fx: {melee: 1.3, sat: 1.1, tr: 1.1}, stats: {might: 3}, crash: {dur: 30, fx: {melee: 0.85, speed: 0.9}}, addict: 0.14,
    lines: ['Your shoulders feel a foot wider.']}),
  slowburn: D('Slowburn', {dur: 60, onset: 2, fade: 8, fx: {spread: 0.55, reload: 0.85, sat: 0.85, tb: 1.1, warp: 0.2, fov: 0.94}, stats: {aim: 2}, addict: 0.12,
    lines: ['The world slows to a crawl and your hands do not.']}),
  viper: D('Viper', {dur: 90, fx: {spread: 0.6, sat: 1.15, tg: 1.1, con: 1.12, heart: 1.0}, stats: {aim: 2, charm: -1}, crash: {dur: 35, fx: {spread: 1.5, speed: 0.9}}, addict: 0.16,
    lines: ['Cold eyes. Steady hands. You could thread a needle at a hundred metres.']}),
  sunburst: D('Sunburst', {dur: 150, onset: 5, fade: 25, fx: {ap: 1.3, sat: 1.6, exposure: 0.12, tr: 1.08, tg: 1.06, tb: 0.85, warp: 0.25, fov: 1.05}, stats: {charm: 2, aim: -1}, addict: 0.12,
    lines: ['The sky is full of colours it never had.', 'Everybody is your friend. Everything is beautiful.']}),
  ashsnuff: D('Ashsnuff', {dur: 180, fx: {dr: 8, speed: 1.05, sat: 0.6, exposure: -0.08}, stats: {aim: -1, endurance: 1}, addict: 0.2,
    lines: ['Black powder up the nose. Your eyes water; your nerves settle.']}),
  stitch_gel: D('Stitch Gel', {dur: 90, onset: 2, fade: 10, fx: {regen: 0.9, dr: 8}, addict: 0, lines: ['It burns, then it binds. Wounds pull themselves shut.']}),
  purge: D('Purge', {dur: 40, onset: 2, fade: 6, fx: {rad: -2.5, speed: 0.85, sat: 0.75, tg: 0.9, exposure: -0.05}, addict: 0,
    lines: ['Your stomach turns over. The radiation comes out the hard way.']}),
  ghostweed: D('Ghostweed', {dur: 120, onset: 6, fade: 25, fx: {speed: 0.95, sat: 0.5, exposure: 0.06, tb: 1.12, warp: 0.4, fov: 1.06}, stats: {agility: 1, luck: 1, aim: -1}, addict: 0.06, stealth: 1,
    lines: ['You feel faint around the edges, like a photograph left in the sun.', 'Nobody seems to notice you. Maybe you are not quite here.']}),
};
const C = (n, w, v, desc) => ({n, t: 'aid', drug: '', w, v, desc});
const CHEMS = {
  hush: C('Hush', 0.1, 50, 'A painkiller autoinjector. +25 damage resistance and slow healing for two minutes. A little numbing in the head.'),
  redline: C('Redline', 0.1, 60, 'Combat stimulant in a red vial. Huge melee damage and +2 Strength for a minute, -2 Perception. Leaves you shaking afterwards.'),
  quickstep: C('Quickstep', 0.1, 55, 'Leg-jitter pills. Run faster, +3 Agility and more Action Points for 75 seconds, then a heavy crash.'),
  lucid: C('Lucid', 0.1, 70, 'Prewar study aid. +3 Intelligence and +1 Perception for three minutes, and a steadier aim.'),
  silver_tongue: C('Silver Tongue', 0.1, 65, 'Honey lozenges laced with something. +3 Charisma for over three minutes.'),
  ironhide: C('Ironhide', 0.2, 80, 'A thick grey paste rubbed on the skin. +45 damage resistance, +2 Endurance, but slow and -2 Agility.'),
  glowcap_tea: C('Glowcap Tea', 0.3, 30, 'Brewed from cave mushrooms. Steady healing for two and a half minutes, at the cost of a little radiation.'),
  nightjar: C('Nightjar', 0.1, 60, 'Eye drops from a ranger kit. See in the dark for four minutes. +1 Perception.'),
  overclock: C('Overclock', 0.1, 95, 'Military combat stim. Action Points through the roof and reloads twice as fast for 45 seconds, then a brutal crash.'),
  bloodpack: C('Bloodpack', 0.3, 45, 'A bag of preserved blood. Restores a lot of health fast, over thirty seconds.'),
  clover: C('Four-Leaf', 0.1, 80, 'Pressed clover in sugar. Nobody knows why it works. +3 Luck for five minutes.'),
  grit: C('Grit', 0.1, 40, 'Chewing tobacco cut with bonemeal. +3 Endurance, +1 Strength and a little damage resistance.'),
  bullshot: C('Bull Shot', 0.2, 55, 'A brown bottle that smells like a barn. +3 Strength and heavier blows for two minutes.'),
  slowburn: C('Slowburn', 0.1, 85, 'A sniper\'s inhaler. The world slows, your aim tightens to a pinpoint, +2 Perception.'),
  viper: C('Viper', 0.1, 70, 'Snake venom diluted to almost safe. Rock-steady aim and +2 Perception, -1 Charisma, a shaky crash.'),
  sunburst: C('Sunburst', 0.1, 60, 'A party tab from the Spur. Colours bloom, +2 Charisma and more Action Points, -1 Perception.'),
  ashsnuff: C('Ashsnuff', 0.1, 20, 'Cheap black snuff. Steadies the nerves and dulls pain. Very easy to get hooked on.'),
  stitch_gel: C('Stitch Gel', 0.2, 50, 'Surgical glue in a tube. Fast healing for ninety seconds.'),
  purge: C('Purge', 0.2, 70, 'An emetic chelator. Strips radiation out of you quickly. Unpleasant in every way.'),
  ghostweed: C('Ghostweed', 0.1, 75, 'A pale dried herb. You fade at the edges; enemies have a harder time spotting you. +1 Agility and Luck.'),
};
for (const k in CHEMS) CHEMS[k].drug = k;

export const ITEMS = {};
for (const k in REFIT) ITEMS[k] = REFIT[k];
Object.assign(ITEMS, NEW);
for (const k in NADES) ITEMS[k] = k === 'frag' ? {nade: {r: 9, dmg: 120, fuse: 2.1, ...NADES.frag}} : NADES[k];
Object.assign(ITEMS, CHEMS);
export {DRUGS};

// where it all turns up: traders' stock and the loot tables
export const STOCK = {
  brannock: [['derringer', 1], ['ridgeback', 1], ['long_silence', 1], ['fire_axe', 1], ['bowie', 1], ['sticky', 2], ['dynamite', 3], ['nail_bomb', 3], ['prox_mine', 2], ['flashbang', 2]],
  duggan: [['claw_hammer', 1], ['lead_pipe', 1], ['shovel', 1], ['smoke', 2], ['hush', 2], ['stitch_gel', 2], ['grit', 2]],
  wick: [['disintegrator', 1], ['laser_pistol', 1], ['tesla_pistol', 1], ['static_pistol', 1], ['pulse_carbine', 1], ['capacitor_rifle', 1], ['beamer', 1], ['cryo', 2], ['plasma_nade', 1]],
  finch: [['gantry_bullpup', 1], ['laser_rifle', 1], ['photon_smg', 1], ['ammo_rocket', 4], ['rocket_tube', 1], ['incendiary', 2], ['overclock', 1], ['ironhide', 1]],
  kess: [['stinger', 1], ['cleaver', 1], ['pickaxe', 1], ['redline', 3], ['bullshot', 2], ['ashsnuff', 4], ['nail_bomb', 3], ['dynamite', 2], ['molotov', 2]],
  halloran: [['hush', 3], ['stitch_gel', 3], ['bloodpack', 3], ['purge', 2], ['lucid', 1], ['nightjar', 1]],
  ro: [['glow_pistol', 1], ['gamma_blunderbuss', 1], ['rad_nade', 2], ['glowcap_tea', 3], ['purge', 2]],
  kettle: [['sunburst', 4], ['ghostweed', 3], ['viper', 2], ['slowburn', 2], ['quickstep', 3], ['overclock', 1], ['redline', 2]],
  della: [['clover', 2], ['silver_tongue', 2], ['sunburst', 2]],
  jun: [['welder_rifle', 1], ['microwave', 1], ['ion_repeater', 1], ['plasma_carbine', 1], ['smoke', 2], ['cryo', 1]],
  sal: [['shovel', 1], ['claw_hammer', 1], ['lead_pipe', 1], ['nail_bomb', 4], ['incendiary', 2], ['ammo_rocket', 2]],
  maren: [['stitch_gel', 2], ['bloodpack', 2], ['hush', 2], ['purge', 1]],
  oskar: [['grit', 2], ['ashsnuff', 3], ['smoke', 1], ['flashbang', 1]],
  drifter: [['bowie', 1], ['derringer', 1], ['quickstep', 1], ['silver_tongue', 1]],
  hollis: [['cleaver', 1], ['glowcap_tea', 2]],
  ezra: [['ashsnuff', 3], ['grit', 2]],
  vex: [],
};
export const LOOT = {
  common: [['lead_pipe', 1, 1], ['claw_hammer', 1, 1], ['ashsnuff', 1, 1], ['hush', 1, 1], ['glowcap_tea', 1, 1]],
  uncommon: [['stinger', 1, 1], ['static_pistol', 1, 1], ['laser_pistol', 1, 1], ['shovel', 1, 1], ['cleaver', 1, 1], ['bowie', 1, 1], ['derringer', 1, 1],
    ['smoke', 1, 1], ['flashbang', 1, 1], ['nail_bomb', 1, 1], ['dynamite', 1, 1], ['incendiary', 1, 1],
    ['redline', 1, 1], ['quickstep', 1, 1], ['grit', 1, 1], ['bullshot', 1, 1], ['stitch_gel', 1, 2], ['bloodpack', 1, 1], ['purge', 1, 1], ['silver_tongue', 1, 1], ['sunburst', 1, 1]],
  rare: [['ridgeback', 1, 1], ['gantry_bullpup', 1, 1], ['long_silence', 1, 1], ['capacitor_rifle', 1, 1], ['beamer', 1, 1], ['pulse_carbine', 1, 1], ['tesla_pistol', 1, 1],
    ['heavy_plasma', 1, 1], ['ion_repeater', 1, 1], ['microwave', 1, 1], ['glow_pistol', 1, 1], ['photon_smg', 1, 1], ['laser_rifle', 1, 1], ['gamma_blunderbuss', 1, 1],
    ['plasma_carbine', 1, 1], ['welder_rifle', 1, 1], ['fire_axe', 1, 1], ['pickaxe', 1, 1], ['ammo_rocket', 1, 3],
    ['sticky', 1, 2], ['cryo', 1, 2], ['rad_nade', 1, 2], ['plasma_nade', 1, 1], ['prox_mine', 1, 2],
    ['lucid', 1, 1], ['ironhide', 1, 1], ['nightjar', 1, 1], ['overclock', 1, 1], ['clover', 1, 1], ['slowburn', 1, 1], ['viper', 1, 1], ['ghostweed', 1, 1]],
};
// one of a kind: Wick keeps the Disintegrator behind the counter, priced to match

// ---- build 14: perks with a level to reach and a real effect each (wired in player.gd, game.gd, nade.gd, focus.gd)
export const PERKS = {
  bloody_mess: {n: 'Bloody Mess', d: '+5% damage with everything, and the people and things you kill come apart messily.'},
  fast_metabolism: {n: 'Fast Metabolism', d: 'Stims, food and drink heal 20% more.'},
  action_runner: {n: 'Action Runner', d: 'Action Points come back 30% faster.'},
  chem_resistant: {n: 'Chem Resistant', d: 'Half as likely to get hooked on chems.', lvl: 4},
  strong_back: {n: 'Strong Back', d: 'Carry 50 more.', lvl: 4},
  demolition: {n: 'Demolition Expert', d: 'Grenades, mines and rockets do 35% more damage over a wider blast.', lvl: 6},
  pyromaniac: {n: 'Pyromaniac', d: 'Fire does half again as much damage: molotovs, incendiaries, and weapons that set things alight.', lvl: 6},
  light_step: {n: 'Light Step', d: 'Mines never go off under you, and you move quicker while sneaking.', lvl: 6},
  mysterious_stranger: {n: 'Mysterious Stranger', d: 'Now and then, when something you\'re fighting is nearly dead, a stranger in a long coat finishes it with one shot and is gone.', lvl: 8},
  sniper: {n: 'Sniper', d: 'Head shots do half again as much, and rifles hold tighter.', lvl: 8},
  ninja: {n: 'Ninja', d: 'Sneak attacks do half again as much damage.', lvl: 8},
  grim_reaper: {n: "Grim Reaper's Sprint", d: 'A kill in FOCUS gives you all your Action Points back.', lvl: 10},
  nerd_rage: {n: 'Nerd Rage!', d: 'Below a fifth of your health: +30 damage resistance and half again as much melee damage.', lvl: 10},
  rad_child: {n: 'Rad Child', d: 'Radiation heals you: the more you have, the faster you mend.', lvl: 12},
  treasure_hunter: {n: 'Treasure Hunter', d: 'Bodies carry one more find.', lvl: 4},
};

// ---- build 14: food and drink. heal, rad (radiation added), buff {k: dr|rad|melee|luck|ap, amt, t seconds}
const F = (n, w, v, heal, desc, o = {}) => ({n, t: 'aid', w, v, heal, desc, food: true, ...o});
export const FOOD = {
  roast_molerat: F('Roast Mole Rat', 0.4, 12, 22, 'Restores 22 health. Crackling skin, stringy meat, a little glow in the fat.', {rad: 1}),
  scorp_tail: F('Fried Scorpion Tail', 0.3, 22, 26, 'Restores 26 health and +10% melee damage for a minute. Venom gland removed. Mostly.', {buff: {k: 'melee', amt: 1.1, t: 60}}),
  flatbread: F('Corn Flatbread', 0.2, 6, 16, 'Restores 16 health. Saltreach corn, slapped flat and charred.'),
  smoked_fish: F('Saltreach Smoked Fish', 0.4, 18, 30, 'Restores 30 health. Caught in the salt pans, smoked over driftwood.', {rad: 1}),
  hollow_shrooms: F('Hollow Mushrooms', 0.2, 4, 8, 'Restores 8 health. They grow in the dark under Hollow, and they glow a little.', {rad: 3}),
  iguana_stick: F('Iguana-on-a-Stick', 0.3, 10, 20, 'Restores 20 health. Every stall in the valley sells them; every stall swears theirs is the original.'),
  boar_ribs: F('Boar Ribs', 0.8, 30, 40, 'Restores 40 health and +8 damage resistance for two minutes. Sticky, smoky, enormous.', {buff: {k: 'dr', amt: 8, t: 120}}),
  pinyon_cake: F('Pinyon Nut Cake', 0.2, 20, 18, 'Restores 18 health and +1 Luck for two minutes. Della bakes them for the high rollers.', {buff: {k: 'luck', amt: 1, t: 120}}),
  coffee_tin: F('Chicory Coffee', 0.3, 12, 4, 'Restores 4 health and Action Points come back faster for three minutes. Bitter as a debt.', {buff: {k: 'ap', amt: 0.3, t: 180}}),
  canned_beans: F('Canned Beans', 0.5, 7, 20, 'Restores 20 health. Prewar, dented, eaten cold with a knife.', {rad: 2}),
  dust_pops: F('Dust Pops Cereal', 0.3, 9, 12, 'Restores 12 health, and more Action Points for a minute. Sugar that survived the end of the world.', {rad: 3, buff: {k: 'ap', amt: 0.2, t: 60}}),
  vulture_omelette: F('Vulture Egg Omelette', 0.4, 24, 35, 'Restores 35 health. You don\'t want to know how big the egg was.'),
  rad_tea: F('Lead-Root Tea', 0.3, 20, 6, 'Restores 6 health and halves radiation taken for two minutes.', {buff: {k: 'rad', amt: 0.5, t: 120}}),
  cactus_water: F('Spiced Cactus Water', 0.5, 10, 14, 'Restores 14 health. Clean, cool, a kick of chilli.'),
  prewar_cola: F('Sun Pop Classic', 0.4, 14, 12, 'Restores 12 health. The original recipe. Slightly radioactive, as it always was.', {rad: 2}),
  hunter_stew: F("Hunter's Stew", 0.8, 40, 55, "Restores 55 health and +15% melee damage for two minutes. Whatever the hunter caught, and a lot of it.", {buff: {k: 'melee', amt: 1.15, t: 120}}),
};
Object.assign(ITEMS, FOOD);
(STOCK.cass ||= []).push(['roast_molerat', 4], ['flatbread', 6], ['iguana_stick', 6], ['canned_beans', 4], ['cactus_water', 5], ['coffee_tin', 3]);
(STOCK.hollis ||= []).push(['boar_ribs', 3], ['hunter_stew', 2], ['vulture_omelette', 2], ['scorp_tail', 3]);
(STOCK.della ||= []).push(['pinyon_cake', 4], ['prewar_cola', 4]);
(STOCK.ezra ||= []).push(['smoked_fish', 4], ['flatbread', 4], ['rad_tea', 2]);
(STOCK.hale ||= []).push(['smoked_fish', 3], ['hunter_stew', 2], ['coffee_tin', 2]);
(STOCK.halloran ||= []).push(['rad_tea', 3]);
LOOT.common.push(['canned_beans', 1, 2], ['dust_pops', 1, 1], ['prewar_cola', 1, 1], ['hollow_shrooms', 1, 2], ['iguana_stick', 1, 1]);
LOOT.uncommon.push(['roast_molerat', 1, 1], ['smoked_fish', 1, 1], ['rad_tea', 1, 1], ['coffee_tin', 1, 1]);

// ---- build 14: power armour, and the new people and machines in the valley
ITEMS.power_armor = {n: 'Iron Warden Power Armor', t: 'armor', w: 40, v: 2600, dr: 48, radRes: 0.5, carry: 40, spd: 0.9, bonus: {might: 2, agility: -1},
  desc: 'A walking tank of olive plate and servos, the Iron Wardens\' pride. Enormous protection, half the radiation, +2 Strength and room for 40 more, but slower and clumsier (-1 Agility).'};
ITEMS.warden_tags = {n: 'Warden Tags', t: 'junk', w: 0.1, v: 30, desc: 'Stamped steel dog tags. The Wardens want these back, and pay for them.'};
ITEMS.synth_core = {n: 'Synth Component', t: 'junk', w: 0.3, v: 75, desc: 'A palm-sized lattice of glass and gold, still warm. Wick would love to look at it.'};
// [game.json fields, region etype fields]
export const ENEMIES = {
  hillfolk: [{n: 'Hill Folk', hp: 60, spd: 3.4, dmg: 8, ranged: true, range: 28, atk: 1.6, detect: 34, xp: 38, caps: [3, 20], mag: 2, nades: 0.15,
    loot: [['common', 1]], drops: [['moonshine', 1, 1, 0.4], ['shells', 2, 6, 0.6], ['jerky', 1, 2, 0.4], ['hunter_stew', 1, 1, 0.1]]}, {hp: 60, dmg: 8, speed: 3.4, range: 28, xp: 38, ranged: true}],
  hill_ma: [{n: 'Ma Tuttle', hp: 170, spd: 3.0, dmg: 12, ranged: true, range: 30, atk: 1.3, detect: 36, xp: 140, caps: [40, 90], mag: 2, nades: 0.3,
    loot: [['uncommon', 1], ['rare', 0.5]], drops: [['hunter_stew', 1, 2, 1], ['sawed_off', 1, 1, 0.6], ['dynamite', 1, 2, 0.6]]}, {hp: 170, dmg: 12, speed: 3.0, range: 30, xp: 140, ranged: true}],
  synth: [{n: 'Synth', hp: 85, spd: 3.8, dmg: 9, ranged: true, range: 40, atk: 1.1, detect: 44, xp: 70, caps: [0, 0], robot: true, mag: 12,
    drops: [['cell', 6, 14, 1], ['synth_core', 1, 1, 0.5], ['laser_pistol', 1, 1, 0.15], ['circuit', 1, 1, 0.4]]}, {hp: 85, dmg: 9, speed: 3.8, range: 40, xp: 70, ranged: true}],
  guardbot: [{n: 'Guardbot', hp: 140, spd: 3.0, dmg: 11, ranged: true, range: 36, atk: 0.9, detect: 40, xp: 90, caps: [0, 0], robot: true, mag: 20,
    drops: [['cell', 8, 18, 1], ['circuit', 1, 2, 0.7], ['scrap_metal', 2, 4, 1], ['gears', 1, 2, 0.6]]}, {hp: 140, dmg: 11, speed: 3.0, range: 36, xp: 90, ranged: true}],
  warden: [{n: 'Iron Warden', hp: 240, spd: 3.0, dmg: 14, ranged: true, range: 42, atk: 1.0, detect: 46, xp: 170, caps: [10, 40], mag: 20,
    loot: [['rare', 1]], drops: [['power_armor', 1, 1, 0.35], ['warden_tags', 1, 1, 1], ['laser_rifle', 1, 1, 0.2], ['cell', 10, 20, 1], ['stimpak', 1, 2, 0.6]]}, {hp: 240, dmg: 14, speed: 3.0, range: 42, xp: 170, ranged: true}],
};
// where they are: a new hollow in the low ground north-west of the Gulch, synths round the reactor, robots at the airfield, Wardens at Ironside
export const LOCS = {holler: {name: 'Hollerback Holler', x: -300, z: 375, r: 26}};
const S = (type, x, z, name) => ({type, x, z, hostile: true, name});
export const SPAWNS = [
  S('hillfolk', -305, 365), S('hillfolk', -292, 381), S('hillfolk', -312, 385), S('hillfolk', -285, 367), S('hillfolk', -318, 373), S('hill_ma', -300, 377, 'Ma Tuttle'),
  S('synth', 60, -255), S('synth', 72, -246), S('synth', 55, -240), S('synth', 82, -262),
  S('guardbot', 290, -345), S('guardbot', 312, -322), S('guardbot', 322, -348),
  S('warden', -320, -288), S('warden', -342, -312),
];


// the Tuttles' camp: shacks of scrap walls round a fire, barrels, crates and a bench (forge pieces)
const PR = (kind, x, z, rot = 0) => ({kind, x, z, rot});
export const PROPS = [
  PR('wall', -308, 369, 0), PR('wall', -308, 373, 0), PR('wall_door', -311, 371, 1.57), PR('roof', -309.5, 371, 0),
  PR('wall', -290, 383, 1.57), PR('wall_window', -294, 383, 1.57), PR('roof', -292, 381.5, 1.57),
  PR('barrel', -303, 373), PR('barrel', -302.2, 373.6), PR('crate', -296, 373, 0.4), PR('crate', -295.3, 373.8, 1.0),
  PR('bench', -298, 379, 0.3), PR('bench', -302, 381, -0.6), PR('fence', -316, 381, 1.2), PR('fence', -318, 377, 1.4),
  PR('loot_common', -309, 375, 0), PR('lamp', -300, 369, 0), {kind: 'campfire', x: -300, z: 376},
];
