// Build 17 story layer. Three new lines of quests and the places for them:
//
//  - The Quiet Hands (Lantern Row, a new trading street east of Saltreach): the valley's thieves' guild, run by
//    Magpie Varga out of the back room behind the Lantern. Light Fingers (a pickpocket test), The Collector's Safe
//    (Saltreach's salt factor and his strongbox) and Old Debts (Silas Crow, who sold the Hands out). Join and the
//    Hands teach you: pickpocketing comes easier, and Dace the fence pays better than anyone.
//  - Starfall (the eastern scrub, Orrin Pike's observatory): Lights Over the Ridge, Not Alone and The Signal Home.
//    Something came down in a saucer; something walked out of it. Help it home, or don't.
//  - The main quest's third act, The Long Way Home: Haven 12 still needs water after Meridian, whatever you did
//    there. Engineer Ruth Adebayo has the vault folk camped at their own front door; the regulator needs a
//    calibration rig (Kestrel Airfield), gaskets (Bo the tinker, Lantern Row), a new housing (the old furnace at
//    Cinder Quarry), a camp that holds together (Calder Voight and his doubters) and one more fight (Kess wants
//    the parts). Six quests, twenty-one stages; it ends with the recycler running.

export const FACTIONS = {
  quiet_hands: {n: 'The Quiet Hands', leader: 'Magpie Varga', desc: 'Thieves, fences and finders. They take from people who can spare it, mostly, and never from the Row.'},
  havens_door: {n: 'Camp of the Door', leader: 'Ruth Adebayo', desc: 'Haven 12\'s people camped outside their own vault, waiting on water.'},
};
export const QUEST_REP = {light_fingers: {quiet_hands: 2}, collectors_safe: {quiet_hands: 3}, old_debts: {quiet_hands: 4},
  cracked_housing: {havens_door: 1}, calibration_rig: {havens_door: 1}, seals_and_gaskets: {havens_door: 1}, housing_cast: {havens_door: 1},
  havens_doubt: {havens_door: 2}, last_nine_days: {havens_door: 4}};
export const NPC_FACTION = {magpie: 'quiet_hands', dace: 'quiet_hands', hesper: 'quiet_hands', ruth: 'havens_door', calder: 'havens_door',
  hd_folk1: 'havens_door', hd_folk2: 'havens_door'};
export const VENDOR_FACTION = {dace: 'quiet_hands'};
export const GUARDS = ['lr_guard'];

export const LOCS = {
  lantern_row: {name: 'Lantern Row', x: 604, z: 120, r: 46},
  starfall: {name: 'Starfall', x: 684, z: -424, r: 36},
  orrin_camp: {name: 'Orrin\'s Observatory', x: 652, z: -397, r: 14},
  havens_door: {name: 'Camp of the Door', x: 0, z: 205, r: 18},
};

const F = (body, skin, hat = null, coat = null, bulk = 1) => ({fem: true, body, skin, hat, coat, bulk});
const M = (body, skin, hat = null, coat = null, bulk = 1) => ({fem: false, body, skin, hat, coat, bulk});
const N = (id, name, x, z, rot, look, extra = {}) => Object.assign({id, name, x, z, rot, wander: null, scale: 1, look}, extra);
export const NPCS = [
  // Lantern Row
  N('magpie', 'Magpie Varga', 604.0, 89.5, 0, F('#2a2a32', '#c89a78', null, '#3a2a40', 0.95)),
  N('dace', 'Dace the Fence', 620.0, 106.0, 0, M('#4a4038', '#a8724c', 'cap', '#3a3028')),
  N('hesper', 'Hesper', 604.0, 102.0, 0, F('#5a3a2a', '#e0ac88', null, '#4a2a1a')),
  N('bo', 'Bo Tinker', 634.0, 132.0, 3.1416, M('#5a5a4a', '#8a5a3a', 'cap', null, 1.15)),
  N('lr_clerk', 'Ezra Coyne', 593.0, 134.0, 3.1416, M('#3a3a4a', '#e0ac88', null, '#2a2a3a', 0.9)),
  N('lr_guard', 'Row Watch', 569.0, 120.0, -1.5708, M('#4a4a3a', '#c89a78', 'helmet', '#3a3a2a', 1.1)),
  N('lr_folk1', 'Row Trader', 600, 118, 0, F('#6a5a4a', '#d2a07a', 'wide'), {wander: {x: 600, z: 120, r: 16}}),
  N('lr_folk2', 'Row Lamplighter', 584, 118, 0, M('#5a4a3a', '#a8724c', 'cap'), {wander: {x: 596, z: 118, r: 20}}),
  N('silas', 'Silas Crow', 318.0, 296.0, 0.8, M('#2a2a2a', '#d8a884', 'wide', '#1a1a1a', 1.05), {unless: 'silas_gone', fight: {hp: 120, dmg: 12, ranged: true}}),
  // Starfall
  N('orrin', 'Orrin Pike', 654.0, -397.0, 2.4, M('#5a5a6a', '#c89a78', 'wide', '#4a4a5a', 0.95)),
  N('visitor', 'The Visitor', 722.0, -458.0, 2.6, M('#8a9a9a', '#9aa6a8', null, null, 0.78), {flag: 'ufo_tracks', unless: 'visitor_gone', fight: {hp: 70, dmg: 9, ranged: true}}),
  // Haven's Door
  N('ruth', 'Ruth Adebayo', 2.5, 207.5, 3.1416, F('#3a4a6a', '#6a4430', null, '#2a3a5a')),
  N('calder', 'Calder Voight', -7.0, 198.5, 0.6, M('#3a4a6a', '#e0ac88', null, '#2a3a5a', 1.1), {unless: 'calder_gone'}),
  N('hd_folk1', 'Haven Settler', 0, 200, 0, F('#3a4a6a', '#d2a07a'), {wander: {x: 0, z: 203, r: 9}}),
  N('hd_folk2', 'Haven Settler', 6, 204, 0, M('#3a4a6a', '#8a5a3a'), {wander: {x: 0, z: 203, r: 9}}),
];

export const VENDORS = {
  dace: {name: 'Dace\'s Pawn', caps: 900, buy: 1.35, sell: 0.75, town: true,
    stock: [['bobby_pin', 14], ['hush', 2], ['quickstep', 2], ['stimpak', 2], ['ammo_9', 60], ['ammo_10', 40], ['snub_pistol', 1], ['derringer', 1], ['combat_knife', 1], ['duct_tape', 3]]},
  hesper: {name: 'The Lantern', caps: 300, buy: 1.3, sell: 0.5, town: true, likes: {aid: 1.2},
    stock: [['purified_water', 8], ['smoked_fish', 4], ['flatbread', 6], ['jerky', 5], ['coffee_tin', 3]]},
  bo: {name: 'Bo\'s Tinkery', caps: 500, buy: 1.3, sell: 0.6, town: true, likes: {junk: 1.3},
    stock: [['scrap_metal', 10], ['duct_tape', 4], ['copper_wire', 6], ['gears', 4], ['circuit', 3], ['fuel_can', 2], ['ammo_10', 30], ['ammo_10_fmj', 20], ['blast_powder', 2]]},
};

export const ITEMS = {
  coyne_watch: {n: 'Coyne\'s Pocket Watch', t: 'quest', w: 0.1, v: 0, desc: 'Silver, dented, still ticking. Engraved inside the lid: "To E.C., who counted everything but the hours."'},
  renn_slip: {n: 'Strongbox Combination', t: 'quest', w: 0, v: 0, desc: 'A scrap of paper from Deputy Renn\'s pocket: 31-7-19, and underneath, "DON\'T LOSE THIS AGAIN".'},
  salt_ledger: {n: 'The Salt Factor\'s Ledger', t: 'quest', w: 0.5, v: 0, desc: 'Who owes Saltreach\'s salt factor, how much, and what he\'s holding over them. Half the farms between here and the Kettle are in it.'},
  qh_book: {n: 'The Book of Hands', t: 'quest', w: 0.4, v: 0, desc: 'Every safe house, dead drop and friendly door the Quiet Hands have ever had, in Magpie\'s tiny writing. Silas Crow walked out with it.'},
  qh_lantern: {n: 'Brass Hand Lantern', t: 'junk', w: 0.5, v: 90, desc: 'The Quiet Hands\' token: a little brass lantern, shuttered. Show it in the right places and doors open.'},
  alien_cell: {n: 'Saucer Power Cell', t: 'quest', w: 2, v: 0, desc: 'A palm-sized cylinder of something like glass with a light moving slowly inside it. It is warm, and it hums when you hold it to your ear.'},
  visitor_beacon: {n: 'The Visitor\'s Beacon', t: 'quest', w: 1, v: 0, desc: 'Three bent rods and the power cell, wired together with a care you couldn\'t match. It needs to be high up, and loud.'},
  alien_alloy: {n: 'Saucer Alloy', t: 'junk', w: 0.4, v: 75, desc: 'A sliver of the saucer\'s hull. Light as paper, and it won\'t take a scratch from anything you own.'},
  stellar_blaster: {n: 'Visitor\'s Blaster', t: 'weapon', kind: 'energy', ammo: 'cell', energy: true, glb: 'bl/blaster_g', w: 1.5, v: 1200, dmg: 46, rof: 0.32, mag: 14, range: 150, spread: 0.004, beam: '#55ffcc',
    desc: 'A gift from someone a very long way from home. It drinks ordinary energy cells and gives back something much worse.'},
  calib_rig: {n: 'Calibration Rig', t: 'quest', w: 8, v: 0, desc: 'A steel case of dials, needles and a hand crank, stencilled KESTREL FIELD - INSTRUMENT SHOP. Its cell is long dead.'},
  gasket_set: {n: 'Regulator Gaskets', t: 'quest', w: 0.5, v: 0, desc: 'Bo\'s gaskets: tyre rubber boiled down with Stillwater fish glue and pressed in a jig. They smell terrible and they will hold.'},
  housing_cast: {n: 'Regulator Housing', t: 'quest', w: 6, v: 0, desc: 'A new housing, poured at the Cinder Quarry furnace. Rough outside, true inside.'},
  saboteur_note: {n: 'Unsigned Note', t: 'quest', w: 0, v: 0, desc: '"Every line we cut is a day nearer Lantern Row. They\'ll thank us when they\'re living under the sky. Burn this." Pinned to a pair of bolt cutters.'},
};

export const POCKETS = {
  lr_clerk: [['coyne_watch', 1]],
  renn2: [['renn_slip', 1]],
  silas: [['qh_book', 1]],
};

export const QUESTS = {
  // ---------------------------------------------------------------- the Quiet Hands
  light_fingers: {t: 'Light Fingers',
    desc: 'Magpie Varga runs the Quiet Hands from the back room behind the Lantern. Before she\'ll talk business she wants to see your hands.',
    stages: [
      {txt: 'Lift Ezra Coyne\'s pocket watch. He clerks at the Row Hall. Crouch, get behind him, and don\'t get caught.', at: 'lantern_row', done: G => G.has('coyne_watch')},
      {txt: 'Bring the watch to Magpie.', at: 'lantern_row'}],
    reward: {xp: 140, caps: 60}},
  collectors_safe: {t: 'The Collector\'s Safe',
    desc: 'Saltreach\'s salt factor keeps a ledger of everyone who owes him, and what he holds over them. Magpie wants it.',
    stages: [
      {txt: 'Get into the salt factor\'s strongbox in Saltreach: lift the combination from Deputy Renn\'s pocket, or pick it with two bobby pins.', at: 'saltreach', done: G => G.has('salt_ledger')},
      {txt: 'Take the ledger to Magpie. Or don\'t: it\'s a list of debts, and you could burn it.', at: 'lantern_row', done: G => !!G.flags.ledger_end},
      {txt: 'Tell Magpie.', at: 'lantern_row'}],
    reward: G => G.flags.ledger_end === 'given' ? {xp: 260, caps: 200} : {xp: 300, caps: 40}},
  old_debts: {t: 'Old Debts',
    desc: 'Silas Crow was Magpie\'s second until he walked out with the Book of Hands and sold three safe houses to Kess. He drinks at Pilgrim\'s Rest now.',
    stages: [
      {txt: 'Find Silas Crow at Pilgrim\'s Rest.', at: 'pilgrim', done: G => !!G.flags.met_silas || G.has('qh_book')},
      {txt: 'Get the Book of Hands back: talk him out of it, lift it from his coat, or take it from him.', at: 'pilgrim', done: G => G.has('qh_book')},
      {txt: 'Bring the Book to Magpie.', at: 'lantern_row'}],
    reward: {xp: 380, caps: 250}},
  // ---------------------------------------------------------------- Starfall
  lights_over_ridge: {t: 'Lights Over the Ridge',
    desc: 'Orrin Pike watches the sky from a camp in the eastern scrub. A month ago he watched something fall out of it.',
    stages: [
      {txt: 'Find where the lights came down, east of Orrin\'s camp.', at: 'starfall', done: G => G.visited('starfall') || !!G.flags.ufo_breach || !!G.flags.ufo_pod || !!G.flags.ufo_cockpit},
      {txt: G => `Search the wreck: the hull breach ${G.flags.ufo_breach ? '✓' : '·'}  the scorched pod ${G.flags.ufo_pod ? '✓' : '·'}  the cockpit ${G.flags.ufo_cockpit ? '✓' : '·'}`, at: 'starfall',
        done: G => !!(G.flags.ufo_breach && G.flags.ufo_pod && G.flags.ufo_cockpit)},
      {txt: 'Tell Orrin what you found.', at: 'orrin_camp'}],
    reward: {xp: 220, caps: 40}},
  not_alone: {t: 'Not Alone',
    desc: 'The pod in the saucer was empty, and something walked out of it on two legs.',
    stages: [
      {txt: 'Follow the tracks from the empty pod.', at: 'starfall', done: G => !!G.flags.ufo_tracks},
      {txt: 'Find whatever made them.', at: 'starfall', done: G => !!G.flags.met_visitor || !!G.flags.npcDead_visitor},
      {txt: 'It\'s hurt. Decide what to do about the Visitor.', at: 'starfall', done: G => !!G.flags.visitor_end || !!G.flags.npcDead_visitor},
      {txt: 'Tell Orrin.', at: 'orrin_camp'}],
    reward: G => G.flags.visitor_end === 'healed' ? {xp: 320, caps: 0} : {xp: 200, caps: 120}},
  signal_home: {t: 'The Signal Home',
    desc: 'The Visitor can call for its people, if it has the saucer\'s power cell and somewhere high to shout from.',
    stages: [
      {txt: 'Take the power cell from the saucer\'s cockpit. Something in the wreck may object.', at: 'starfall', done: G => G.has('alien_cell') && G.killed('sentinel')},
      {txt: 'Bring the power cell to the Visitor.', at: 'starfall', done: G => G.has('visitor_beacon') || !!G.flags.beacon_set},
      {txt: 'Patch the beacon into the KDST radio mast.', at: 'kdst', done: G => !!G.flags.beacon_set},
      {txt: 'Go back to the Visitor at Starfall.', at: 'starfall'}],
    reward: {xp: 520, caps: 0}},
  // ---------------------------------------------------------------- the main quest, act three
  cracked_housing: {t: 'The Long Way Home', main: true,
    desc: 'Whatever happened at Meridian, Haven 12 still has no water it can trust. Its people have pitched a camp outside their own door, and their engineer has a plan.',
    stages: [
      {txt: 'Go to the camp at Haven 12\'s door and find Engineer Ruth Adebayo.', at: 'havens_door', done: G => !!G.flags.met_ruth},
      {txt: 'Look at the recycler with Ruth: the service panel by the vault door.', at: 'havens_door', done: G => !!G.flags.saw_housing},
      {txt: 'Hear Ruth\'s plan.', at: 'havens_door'}],
    reward: {xp: 150, caps: 0}},
  calibration_rig: {t: 'Dials and Needles', main: true,
    desc: 'A regulator out of true is worse than none. Ruth needs the old instrument shop\'s calibration rig from Kestrel Airfield.',
    stages: [
      {txt: 'Find the calibration rig in the hangar yard at Kestrel Airfield.', at: 'airfield', done: G => G.has('calib_rig')},
      {txt: 'Its cell is dead. Find a fusion cell to wake it (traders in Old Meridian and Saltreach sell them).', done: G => G.has('fusion_cell') || !!G.flags.rig_in},
      {txt: 'Bring the rig and the fusion cell to Ruth.', at: 'havens_door', done: G => !!G.flags.rig_in},
      {txt: 'Tell Ruth you\'re ready to move on.', at: 'havens_door'}],
    reward: {xp: 220, caps: 50}},
  seals_and_gaskets: {t: 'Fish Glue and Tyre Rubber', main: true,
    desc: 'The regulator\'s seals turned to dust two hundred years ago. Ruth has heard of a tinker in Lantern Row who can make anything out of anything.',
    stages: [
      {txt: 'Ask Bo the tinker in Lantern Row about gaskets.', at: 'lantern_row', done: G => !!G.flags.bo_asked},
      {txt: 'Bring Bo 2 Duct Tape and a Fuel Can.', at: 'lantern_row', done: G => !!G.flags.bo_paid},
      {txt: 'Bo needs a day with the jig. Come back tomorrow.', at: 'lantern_row', done: G => G.has('gasket_set') || !!G.flags.gaskets_in},
      {txt: 'Bring the gaskets to Ruth.', at: 'havens_door', done: G => !!G.flags.gaskets_in}],
    reward: {xp: 200, caps: 40}},
  housing_cast: {t: 'Iron and Fire', main: true,
    desc: 'The regulator\'s housing cracked. Ruth has a mould; she needs iron, fuel and a furnace that still draws.',
    stages: [
      {txt: G => `Gather 6 Scrap Metal (${Math.min(6, G.count('scrap_metal'))}/6) and a Fuel Can for the furnace.`, done: G => (G.count('scrap_metal') >= 6 && G.has('fuel_can')) || G.has('housing_cast') || !!G.flags.cast_in},
      {txt: 'Fire the old furnace at Cinder Quarry and pour the housing.', at: 'quarry', done: G => G.has('housing_cast') || !!G.flags.cast_in},
      {txt: 'Bring the casting to Ruth.', at: 'havens_door', done: G => !!G.flags.cast_in}],
    reward: {xp: 220, caps: 30}},
  havens_doubt: {t: 'Haven\'s Doubt', main: true,
    desc: 'Not everyone at the Camp of the Door wants to go back inside. Somebody has been cutting the water lines.',
    stages: [
      {txt: 'Talk to Calder Voight, who speaks for the settlers who want to leave Haven for good.', at: 'havens_door', done: G => !!G.flags.met_calder},
      {txt: 'Somebody has been cutting the camp\'s water lines. Search the camp.', at: 'havens_door', done: G => G.has('saboteur_note') || !!G.flags.doubt_end},
      {txt: 'Decide what happens to Calder.', at: 'havens_door', done: G => !!G.flags.doubt_end},
      {txt: 'Tell Ruth.', at: 'havens_door'}],
    reward: G => G.flags.doubt_end === 'talked' ? {xp: 320, caps: 0} : {xp: 240, caps: 0}},
  last_nine_days: {t: 'The Last Nine Days', main: true,
    desc: 'Everything Ruth needs is in the camp, and the whole valley knows it. Haven 12 has nine days of water left. Again.',
    stages: [
      {txt: 'Kess\'s raiders are coming for the parts. Hold the Camp of the Door.', at: 'havens_door', done: G => G.allDead('kr', 6)},
      {txt: 'Fit the regulator with Ruth: work the recycler panel by the vault door.', at: 'havens_door', done: G => !!G.flags.recycler_on},
      {txt: 'Listen to Haven 12.', at: 'havens_door', done: G => !!G.flags.heard_haven_end},
      {txt: 'Talk to Ruth one last time.', at: 'havens_door'}],
    reward: {xp: 900, caps: 400}},
};

const T = (t, go, extra = {}) => Object.assign(go ? {t, go} : {t}, extra);
export const DIALOGUE = {
  // ---------------------------------------------------------------- Lantern Row
  magpie: {name: 'Magpie Varga', nodes: {
    hub: {say: G => G.flags.qh_member ? 'One of mine. What do you need, love?' : G.flags.met_magpie ? 'Back again. Either you want work or you want to be robbed. I can do both.' : 'You found the back door, which means either Hesper likes you or you\'re very nosy. Both are useful. Magpie Varga. I run the Quiet Hands. You\'ve heard of us, or you haven\'t, and both of those are how I like it.',
      opts: [
        T('Who are the Quiet Hands?', 'who', {act: G => G.setFlag('met_magpie', 1)}),
        T('I want work.', 'work', {if: G => !G.questKnown('light_fingers'), act: G => G.setFlag('met_magpie', 1)}),
        T('Ezra\'s watch.', 'watch', {if: G => G.questActive('light_fingers') && G.has('coyne_watch')}),
        T('Anything else?', 'safe', {if: G => G.questDone('light_fingers') && !G.questKnown('collectors_safe')}),
        T('About the salt ledger.', 'ledger', {if: G => G.questActive('collectors_safe') && G.has('salt_ledger') && !G.flags.ledger_end}),
        T('It\'s dealt with.', 'ledger_done', {if: G => G.questActive('collectors_safe') && !!G.flags.ledger_end}),
        T('What happened with Silas?', 'silas', {if: G => G.questDone('collectors_safe') && !G.questKnown('old_debts')}),
        T('The Book of Hands.', 'book', {if: G => G.questActive('old_debts') && G.has('qh_book')}),
        {t: 'Goodbye.', act: G => G.setFlag('met_magpie', 1)}]},
    who: {say: 'Finders. We find things people have too many of and move them to people who have too few. Never the Row, never the sick, never a kid. Break that and the Hands break you. Keep it and we keep you.',
      opts: [T('And if I wanted to join?', 'work', {if: G => !G.questKnown('light_fingers')}), T('Interesting.', 'hub')]},
    work: {say: 'Everybody wants to join until they have to do something. Ezra Coyne clerks at the Row Hall. He carries a silver watch he loves more than his mother. Bring it to me, without him knowing it\'s gone. Crouch, get behind him, be patient. If he catches you, I never met you.',
      opts: [T('Easy.', 'hub', {act: G => G.start('light_fingers')}), T('Not my kind of work.', 'hub')]},
    watch: {say: 'Ooh, it\'s warm still. He won\'t notice till supper. Good hands. Keep this lot: Dace will sell you more, and you\'ll need them. ...I\'ll put it back on his desk tomorrow. We don\'t keep things from the Row.',
      opts: [T('Glad to help.', 'hub', {act: G => { G.take('coyne_watch', 1); G.give('bobby_pin', 5); G.complete('light_fingers'); }})]},
    safe: {say: 'There is. The salt factor in Saltreach lends to farmers at rates that would make a raider blush, and writes down every debt, every lie and every daughter he\'s been promised in a ledger he keeps in a strongbox. Deputy Renn carries the combination, because the factor can\'t remember numbers. Bring me that book.',
      opts: [T('What will you do with it?', 'why'), T('I\'ll get it.', 'hub', {act: G => G.start('collectors_safe')})]},
    why: {say: 'Make him forget a few debts, mostly. Make a few farmers sleep. Make a little money, a bit. I\'m a thief, love, not a saint. I\'m just a thief with a list of people I don\'t steal from.',
      opts: [T('I\'ll get it.', 'hub', {act: G => G.start('collectors_safe')}), T('Let me think.', 'hub')]},
    ledger: {say: 'You read it, didn\'t you. Everybody reads it. So: do I get my book?',
      opts: [
        T('Here. Make him forget a few debts.', 'given', {act: G => { G.take('salt_ledger', 1); G.setFlag('ledger_end', 'given'); G.rep('quiet_hands', 2); }}),
        T('I burned it. Nobody gets to hold that over those farms. Not him, not you.', 'burned', {act: G => { G.take('salt_ledger', 1); G.setFlag('ledger_end', 'burned'); G.karma(6, 'Burned the salt factor\'s ledger'); }})]},
    given: {say: 'Good. Two farms clear their debts this month, and nobody ever finds out why. That\'s the job. That\'s the whole job. Welcome to the Hands.',
      opts: [T('Thank you.', 'ledger_done')]},
    burned: {say: '...Well. Can\'t say I\'d have done it. Can\'t say you\'re wrong. You\'d make a terrible thief and a decent Hand. Welcome in, anyway.',
      opts: [T('Thank you.', 'ledger_done')]},
    ledger_done: {say: 'Here. A lantern. Show it at any door with a lantern scratched on the frame and you\'ll get a bed and no questions. And Dace pays our people properly now.',
      opts: [T('One of the Hands.', 'hub', {act: G => { G.setFlag('qh_member', 1); G.give('qh_lantern', 1); G.complete('collectors_safe'); G.msg('Joined the Quiet Hands: pickpocketing comes easier (+15%), and Dace pays you better.'); }})]},
    silas: {say: 'Silas Crow. My second, for nine years. Then Kess offered him more than nine years was worth, and he walked out with the Book of Hands: every safe door we have. Three of them burned. He drinks at Pilgrim\'s Rest now, like a man who isn\'t afraid of anything. I want the Book. What happens to Silas is up to you.',
      opts: [T('I\'ll get it back.', 'hub', {act: G => G.start('old_debts')}), T('Not yet.', 'hub')]},
    book: {say: 'My Book. My little Book. ...And Silas? No, don\'t tell me. Here, this is yours, and so is anything in the strongbox behind me, once a season. You\'re the Hands\' now, all the way down.',
      opts: [T('Thank you, Magpie.', 'hub', {act: G => { G.take('qh_book', 1); G.setFlag('qh_vault', 1); G.complete('old_debts'); }})]},
  }},
  dace: {name: 'Dace the Fence', nodes: {
    hub: {say: G => G.flags.qh_member ? 'One of Magpie\'s. Better prices for family, and I don\'t ask where anything\'s been.' : 'Dace. Pawn, loans, and things nobody wants to explain. Buying, selling?',
      opts: [T('Let\'s trade.', null, {act: G => G.openTrade('dace')}), T('Goodbye.')]},
  }},
  hesper: {name: 'Hesper', nodes: {
    hub: {say: G => G.flags.met_magpie ? 'You know the way to the back. Drink first, though. House rule.' : 'Welcome to the Lantern. We pour, we listen, we forget. Back room\'s private. Unless somebody tells you it isn\'t.',
      opts: [T('Pour me something.', null, {act: G => G.openTrade('hesper')}), T('Who\'s in the back room?', 'back', {if: G => !G.flags.met_magpie}), T('Goodbye.')]},
    back: {say: '...You\'ve got honest eyes and a quick walk. Cabin behind the bar. Knock twice, then once. If she doesn\'t like you, I never said a word.', opts: [T('Thanks.', 'hub')]},
  }},
  bo: {name: 'Bo Tinker', nodes: {
    hub: {say: G => G.flags.bo_paid && !G.has('gasket_set') && !G.flags.gaskets_in ? (G.day > (G.flags.bo_day || 0) ? 'They\'re done! Pressed and cured. Smell them. ...Don\'t smell them.' : 'Jig\'s still pressing. Tomorrow. Rubber doesn\'t hurry and neither do I.')
        : 'Bo. I fix things and make things out of the things I can\'t fix. What\'ve you got?',
      opts: [
        T('Let\'s trade.', null, {act: G => G.openTrade('bo')}),
        T('Can you make gaskets for a vault regulator?', 'gaskets', {if: G => G.questActive('seals_and_gaskets') && !G.flags.bo_asked}),
        T('Here: two duct tape and a fuel can.', 'paid', {if: G => G.questActive('seals_and_gaskets') && !!G.flags.bo_asked && !G.flags.bo_paid && G.count('duct_tape') >= 2 && G.has('fuel_can')}),
        T('Are the gaskets ready?', 'ready', {if: G => !!G.flags.bo_paid && !G.has('gasket_set') && !G.flags.gaskets_in && G.day > (G.flags.bo_day || 0)}),
        T('Goodbye.')]},
    gaskets: {say: 'A vault regulator! Pre-war seals, nitrile probably, long gone. I can boil tyre rubber down with Stillwater fish glue and press it in a jig. Bring me two rolls of duct tape and a can of fuel for the boiler and I\'ll have them in a day.',
      opts: [T('I\'ll get them.', 'hub', {act: G => G.setFlag('bo_asked', 1)})]},
    paid: {say: 'Lovely. Into the boiler... Come back tomorrow. And don\'t stand downwind.',
      opts: [T('Tomorrow.', 'hub', {act: G => { G.take('duct_tape', 2); G.take('fuel_can', 1); G.setFlag('bo_paid', 1); G.setFlag('bo_day', G.day); }})]},
    ready: {say: 'Six gaskets, pressed and trimmed. They\'ll hold three hundred pounds and the smell will hold longer. On the house: a vault full of thirsty people is good for nobody\'s business.',
      opts: [T('Thank you, Bo.', 'hub', {act: G => G.give('gasket_set', 1)})]},
  }},
  lr_clerk: {name: 'Ezra Coyne', nodes: {hub: {say: G => G.questDone('light_fingers') ? 'I lost my watch and it turned up on my desk the next morning. Polished. I\'m choosing not to think about it.' : 'Row Hall. Licences, disputes, lost and found. Mostly lost.', opts: [T('Goodbye.')]}}},
  lr_guard: {name: 'Row Watch', nodes: {hub: {say: 'Lantern Row. Lamps lit from dusk, hands in your own pockets. If you see a lantern scratched on a door frame, it\'s not your business.', opts: [T('Understood.')]}}},
  lr_folk1: {name: 'Row Trader', nodes: {hub: {say: 'Best salt east of Saltreach and the cheapest lamp oil anywhere. Don\'t ask why the oil\'s cheap.', opts: [T('All right.')]}}},
  lr_folk2: {name: 'Row Lamplighter', nodes: {hub: {say: 'Every post on the Row gets a lamp at dusk. Mine. Forty-one lamps. Somebody steals one about once a week and brings it back polished. Strange town.', opts: [T('Ha.')]}}},
  silas: {name: 'Silas Crow', nodes: {
    hub: {say: G => G.flags.met_silas ? 'Still here? Buy a drink or get out of my light.' : 'Let me guess. Magpie sent you, because Magpie never comes herself. Silas Crow. Sit if you like. I\'m not afraid of her.',
      opts: [
        T('She wants the Book of Hands back.', 'book', {if: G => G.questActive('old_debts') && !G.has('qh_book'), act: G => G.setFlag('met_silas', 1)}),
        T('Why did you sell them out?', 'why', {act: G => G.setFlag('met_silas', 1)}),
        {t: 'Goodbye.', act: G => G.setFlag('met_silas', 1)}]},
    why: {say: 'Nine years of stealing salt and giving half of it back. Kess offered me a yard, a crew and a door with my own name on it. Magpie\'s rules are pretty. Pretty doesn\'t keep you warm.', opts: [T('I see.', 'hub')]},
    book: {say: 'The Book is the only thing keeping Kess from cutting my throat. As long as I have it, I\'m worth something to him. You want it, you\'ll have to give me a reason.',
      opts: [
        T('Kess got his three safe houses. You\'re spent, Silas. The Book is a noose with your name on it. Give it to me and walk away.', 'talked', {check: ['charm', 8]}),
        T('Then I\'ll take it.', 'fight'),
        T('Fair enough.', 'hub')]},
    talked: {say: '...You\'re right. You\'re bloody right, and I knew it, and I\'ve been drinking so I didn\'t have to. Take it. Tell her I\'m sorry. Don\'t tell her I said it.',
      opts: [T('Go somewhere quiet, Silas.', null, {act: G => { G.give('qh_book', 1); G.setFlag('silas_gone', 1); G.karma(3, 'Let Silas Crow walk away'); G.msg('Silas Crow finishes his drink, leaves the glass upside down, and walks out east.'); }})]},
    fight: {say: 'Should have known. She always did like the loud ones.', opts: [T('[Draw]', null, {act: G => { G.setFlag('silas_war', 1); G.fight('silas'); }})]},
  }},
  // ---------------------------------------------------------------- Starfall
  orrin: {name: 'Orrin Pike', nodes: {
    hub: {say: G => G.flags.visitor_end === 'home' ? 'It\'s gone home. I watched the light go up from the KDST mast and something came down to meet it. I\'m seventy-one. I have seen it. I can die now. I\'d rather not, but I could.'
        : G.flags.met_orrin ? 'Back! Seen anything? I see everything. That\'s the trouble.' : 'Ah! Careful of the telescope. Orrin Pike. Astronomer, retired, unemployed since the sky stopped being interesting. Which it did for two hundred years. Until last month.',
      opts: [
        T('What happened last month?', 'lights', {if: G => !G.questKnown('lights_over_ridge'), act: G => G.setFlag('met_orrin', 1)}),
        T('About the wreck.', 'wreck', {if: G => G.questActive('lights_over_ridge') && G.qStage('lights_over_ridge') === 2}),
        T('About the Visitor.', 'visitor', {if: G => G.questActive('not_alone') && G.qStage('not_alone') === 3}),
        {t: 'Goodbye.', act: G => G.setFlag('met_orrin', 1)}]},
    lights: {say: 'Three lights over the ridge, in a triangle, holding still, which nothing in the sky does. Then one of them wasn\'t holding still. It came down like a skipping stone, east, into the scrub. I\'m too old to walk out there and too curious to sleep. Will you go and look?',
      opts: [T('I\'ll go.', 'hub', {act: G => G.start('lights_over_ridge')}), T('Lights in the sky. Sure.', 'hub')]},
    wreck: {say: G => 'A saucer. A real one. ' + (G.flags.ufo_pod ? 'And the pod was empty? ' : '') + 'Oh, I\'ve waited my whole life to be right about something this stupid. ...An empty pod means something walked out. It\'s hurt, or it wouldn\'t have stayed near. Find it. Be kind. It\'s a long way from home.',
      opts: [T('I\'ll look.', 'hub', {act: G => { G.complete('lights_over_ridge'); G.start('not_alone'); }})]},
    visitor: {say: G => G.flags.visitor_end === 'healed' ? 'You helped it. Of course you did. Now it\'ll want to go home, and it can\'t walk there. Help it the rest of the way, would you? For me.'
        : 'Dead, then. ...Well. The universe sent us one visitor in two hundred years and we shot it. That\'s very us. Here, for the trouble. I don\'t want to look at you just now.',
      opts: [T('I will.', 'hub', {if: G => G.flags.visitor_end === 'healed', act: G => { G.complete('not_alone'); G.start('signal_home'); }}),
        T('I\'m sorry.', 'hub', {if: G => G.flags.visitor_end !== 'healed', act: G => { G.give('alien_alloy', 2); G.complete('not_alone'); }})]},
  }},
  visitor: {name: 'The Visitor', nodes: {
    hub: {say: G => G.flags.beacon_set ? 'It holds out a long hand, palm up, and closes it slowly. Then it points at the sky, and at you, and at its chest, and the light in its eyes goes very soft.'
        : G.has('alien_cell') ? 'It sees the cell in your hand and makes a sound like a kettle beginning to boil. It reaches for it, then stops, and waits for you.'
        : G.flags.visitor_end === 'healed' ? 'It points at the saucer, then makes a small round shape with its fingers: the cell. Then it points up.'
        : 'It\'s grey, and small, and wedged into a hollow under a rock with one long leg bent wrong. Its eyes are huge and black and wet. It doesn\'t move except to breathe, fast, and to hold up one hand with three fingers spread.',
      opts: [
        T('[Kneel slowly and show your hands]', 'calm', {if: G => !G.flags.met_visitor}),
        T('[Splint the leg and give it 2 Stimpaks and a RadAway]', 'heal', {if: G => !!G.flags.met_visitor && !G.flags.visitor_end && G.count('stimpak') >= 2 && G.has('radaway')}),
        T('[Shoot it]', 'shoot', {if: G => !G.flags.visitor_end}),
        T('[Give it the power cell]', 'cell', {if: G => G.questActive('signal_home') && G.has('alien_cell') && G.killed('sentinel')}),
        T('[Take its hand]', 'bye', {if: G => G.questActive('signal_home') && !!G.flags.beacon_set}),
        T('[Leave]')]},
    calm: {say: 'It watches you kneel. After a while it lowers its hand and points at its leg, and then at its chest, where the skin is burnt the colour of old copper. It\'s hurt. It knows you can see that.',
      opts: [T('[Leave it for now]', null, {act: G => G.setFlag('met_visitor', 1)})]},
    heal: {say: 'It flinches at the needle, then goes still. When the RadAway goes in it lets out a long breath that smells like rain on hot stone. Then it reaches up and touches your forehead with one finger, very lightly, and for a second you can see the saucer from above, falling, and three lights, and one going dark.',
      opts: [T('[Nod]', null, {act: G => { G.take('stimpak', 2); G.take('radaway', 1); G.setFlag('visitor_end', 'healed'); G.karma(8, 'Healed the Visitor'); G.addXp(80); }})]},
    shoot: {say: 'It sees the gun come up. It doesn\'t look surprised.', opts: [T('[Fire]', null, {act: G => { G.setFlag('visitor_end', 'killed'); G.karma(-8, 'Shot the Visitor'); G.fight('visitor'); }}), T('[Lower the gun]', 'hub')]},
    cell: {say: 'It takes the cell in both hands like something sacred. It works for a long time with three bent rods from its pockets, humming, and then gives you back the cell wired into a little cage of metal. It points west, toward the tall mast at KDST, and lifts its hands up high.',
      opts: [T('[Take the beacon]', null, {act: G => { G.take('alien_cell', 1); G.give('visitor_beacon', 1); }})]},
    bye: {say: 'Its hand is cool and dry. Somewhere above the ridge a light is coming down, very slowly, without a sound. The Visitor presses something into your palm: a weapon, light as a bird. Then it walks out into the scrub toward the light, and doesn\'t look back, and you don\'t see it go.',
      opts: [T('[Watch the sky]', null, {act: G => { G.give('stellar_blaster', 1); G.give('cell', 30); G.setFlag('visitor_end', 'home'); G.setFlag('visitor_gone', 1); G.complete('signal_home'); }})]},
  }},
  // ---------------------------------------------------------------- the Camp of the Door
  ruth: {name: 'Ruth Adebayo', nodes: {
    hub: {say: G => G.questDone('last_nine_days') ? 'Water. Clean, cold water, out of a tap, in a vault. You did that. Haven 12 owes you its life twice now, and we\'re not good at owing. We\'ll learn.'
        : G.flags.met_ruth ? (!!(G.flags.rig_in && G.flags.gaskets_in && G.flags.cast_in) && !G.questKnown('last_nine_days') ? 'That\'s all of it. Rig, gaskets, housing. We can build it.' : 'What have you got for me?')
        : 'You! The Overseer said you\'d come back. Ruth Adebayo, chief engineer, or I was when we had something to engineer. Sit, if you can find a bit of ground that isn\'t a tent.',
      opts: [
        T('What happened? Why is everyone outside?', 'out', {if: G => !G.flags.met_ruth, act: G => { G.setFlag('met_ruth', 1); G.start('cracked_housing'); }}),
        T('Show me the recycler.', 'show', {if: G => G.questActive('cracked_housing') && !!G.flags.met_ruth && !G.flags.saw_housing}),
        T('What\'s the plan?', 'plan', {if: G => G.questActive('cracked_housing') && !!G.flags.saw_housing}),
        T('Here\'s the calibration rig, and a fusion cell.', 'rig', {if: G => G.questActive('calibration_rig') && G.has('calib_rig') && G.has('fusion_cell') && !G.flags.rig_in}),
        T('The rig\'s working. What\'s next?', 'rig_done', {if: G => G.questActive('calibration_rig') && !!G.flags.rig_in}),
        T('Bo\'s gaskets.', 'gaskets', {if: G => G.questActive('seals_and_gaskets') && G.has('gasket_set')}),
        T('A new housing, from the quarry furnace.', 'cast', {if: G => G.questActive('housing_cast') && G.has('housing_cast')}),
        T('About Calder.', 'calder', {if: G => G.questActive('havens_doubt') && !!G.flags.doubt_end}),
        T('Let\'s build it.', 'build', {if: G => !!(G.flags.rig_in && G.flags.gaskets_in && G.flags.cast_in) && !G.questKnown('last_nine_days')}),
        T('It\'s running.', 'end', {if: G => G.questActive('last_nine_days') && !!G.flags.heard_haven_end}),
        T('Goodbye.')]},
    out: {say: G => (G.flags.ending === 'home' ? 'You brought the regulator home. We fitted it the same night, and the housing split down the seam at the first pressure test. Two hundred years in a reactor and three days in your pack. ' : 'The Meridian regulator didn\'t come home, and I\'m not asking why. People had reasons. ')
        + 'The recycler\'s on its last filter. The Overseer moved everyone who could walk out here, where at least there\'s a sky to look at while we ration. I can build a regulator. I need parts and someone who can walk.',
      opts: [T('Show me.', 'show')]},
    show: {say: 'The service panel\'s by the door, there. Have a look for yourself: I want you to understand what you\'re carrying.',
      opts: [T('I\'ll look.', 'hub')]},
    plan: {say: 'Three things. A calibration rig, because a regulator that\'s out of true will flood the beds or poison them: Kestrel Airfield had an instrument shop. Gaskets, because ours are dust: there\'s a tinker in Lantern Row, east of Saltreach. And a housing: I have the mould, I need iron and a furnace, and the old furnace at Cinder Quarry still draws. Oh, and one more thing. Calder Voight wants everyone to leave Haven for good. Talk to him before he talks everyone else into it.',
      opts: [T('I\'ll get them.', 'hub', {act: G => { G.complete('cracked_housing'); G.start('calibration_rig'); G.start('seals_and_gaskets'); G.start('housing_cast'); G.start('havens_doubt'); }})]},
    rig: {say: 'Oh, look at you. KESTREL FIELD INSTRUMENT SHOP. ...Cell in, crank it... and the needles move. They move! Every one of them. I could kiss you. I won\'t. I\'m an engineer.',
      opts: [T('Ha.', 'hub', {act: G => { G.take('calib_rig', 1); G.take('fusion_cell', 1); G.setFlag('rig_in', 1); }})]},
    rig_done: {say: 'It\'s on the bench and it\'s true to a hair. One down.', opts: [T('Good.', 'hub', {act: G => G.complete('calibration_rig')})]},
    gaskets: {say: 'Fish glue and tyre rubber. Bo, you beautiful lunatic. They\'ll hold. They\'ll hold better than the originals did.',
      opts: [T('Two down.', 'hub', {act: G => { G.take('gasket_set', 1); G.setFlag('gaskets_in', 1); G.complete('seals_and_gaskets'); }})]},
    cast: {say: 'Rough as a goat outside, smooth as glass in. That\'s a good pour. You\'ve done this before. ...No? Then you\'re lucky, and I\'ll take lucky.',
      opts: [T('Three down.', 'hub', {act: G => { G.take('housing_cast', 1); G.setFlag('cast_in', 1); G.complete('housing_cast'); }})]},
    calder: {say: G => G.flags.doubt_end === 'talked' ? 'Calder came and helped me strip the old unit. Said he\'d stay till the water runs and then decide. That\'s more than I hoped for.'
        : G.flags.doubt_end === 'exiled' ? 'Calder\'s gone, and six families with him, to Lantern Row. I don\'t blame them. I don\'t forgive the bolt cutters either.'
        : 'So Calder\'s staying, and keeping quiet, and owes you. Keep an eye on him. I will.',
      opts: [T('It\'s done.', 'hub', {act: G => G.complete('havens_doubt')})]},
    build: {say: 'Then we build it. Tonight. And the whole valley knows what we\'ve got in this camp now, so we won\'t be doing it in peace. Kess has been asking about us at the Gantry. If his boys come, I need you on the line.',
      opts: [T('Let them come.', 'hub', {act: G => { G.start('last_nine_days'); G.setFlag('kess_raid', 1); G.msg('Engines on the road from the Gantry. Kess\'s raiders are coming for the camp.'); }})]},
    end: {say: 'Haven 12. Running water. I keep turning the tap on in my head. ...Listen. Whatever you do now, wherever you go: there\'s a bunk in Haven with your name on the door. Literally. I had Pell stencil it.',
      opts: [T('Thank you, Ruth.', null, {act: G => { G.setFlag('kess_raid_done', 1); G.complete('last_nine_days'); G.karma(10, 'Brought water back to Haven 12'); }})]},
  }},
  calder: {name: 'Calder Voight', nodes: {
    hub: {say: G => G.flags.doubt_end ? 'Well. You know where I stand.' : 'You\'re the one who walked out of the door first. Then you know. There\'s a whole world out here, and we\'re fixing a hole in the ground so we can go back down into it.',
      opts: [
        T('You want people to leave Haven?', 'leave', {act: G => { G.setFlag('met_calder', 1); if (!G.questKnown('havens_doubt')) G.start('havens_doubt'); }}),
        T('Someone\'s been cutting the water lines. This was with the cutters.', 'note', {if: G => G.has('saboteur_note') && !G.flags.doubt_end}),
        T('Goodbye.')]},
    leave: {say: 'I want people to choose. Two hundred years we\'ve lived by a door. The Overseer decides who sees daylight. Ruth decides who drinks. Out here we could decide for ourselves. Every day that recycler stays broken is a day people learn they don\'t need it.',
      opts: [T('I hear you.', 'hub')]},
    note: {say: '...I didn\'t write that. ...I wrote that. Nobody\'s been hurt! We cut lines we could patch. We were buying time, so people would see the sky long enough to want it.',
      opts: [
        T('Then let them choose, honestly. Stay till the water runs, and then anyone who wants to go, goes. With my help.', 'talked', {check: ['charm', 7]}),
        T('You\'re leaving. Today. Take whoever wants to follow you to Lantern Row.', 'exiled'),
        T('I\'ll keep this between us. Stop cutting lines.', 'kept')]},
    talked: {say: '...Honestly. All right. All right. I\'ll stay and I\'ll help Ruth, and when it\'s running, the door stays open both ways. You\'d make a better Overseer than Adair, you know.',
      opts: [T('Don\'t tell her that.', null, {act: G => { G.take('saboteur_note', 1); G.setFlag('doubt_end', 'talked'); G.karma(4, 'Kept the Camp of the Door together'); }})]},
    exiled: {say: 'Then that\'s how it goes. You\'ll find us on the Row, under the sky, if you ever get tired of doors.',
      opts: [T('Goodbye, Calder.', null, {act: G => { G.take('saboteur_note', 1); G.setFlag('doubt_end', 'exiled'); G.setFlag('calder_gone', 1); }})]},
    kept: {say: 'You\'re not going to tell Ruth? ...Thank you. No more lines. You have my word, for what it\'s worth this week.',
      opts: [T('It\'s worth something.', null, {act: G => { G.take('saboteur_note', 1); G.setFlag('doubt_end', 'kept'); }})]},
  }},
  hd_folk1: {name: 'Haven Settler', nodes: {hub: {say: G => G.questDone('last_nine_days') ? 'I had a bath. A whole bath. I cried a bit.' : 'Half a cup a day. You stop noticing the thirst after a while. Then you notice it all at once.', opts: [T('Hang in there.')]}}},
  hd_folk2: {name: 'Haven Settler', nodes: {hub: {say: 'I\'d never seen a cloud till last month. I don\'t trust them. They move.', opts: [T('They do that.')]}}},
  hd_panel: {name: 'Recycler Service Panel', nodes: {
    hub: {say: G => G.flags.recycler_on ? 'HAVEN 12 WATER RECLAMATION\nREGULATOR ......... SEATED\nFLOW ............. NOMINAL\nRESERVE .......... RISING'
        : G.questActive('last_nine_days') ? 'HAVEN 12 WATER RECLAMATION\nREGULATOR ......... BENCH (READY)\nFLOW ............. 4%\nRESERVE .......... 9 DAYS'
        : 'HAVEN 12 WATER RECLAMATION\nREGULATOR ......... FAULT - HOUSING BREACH\nFLOW ............. 4%\nRESERVE .......... 9 DAYS\n\nThrough the inspection glass, the regulator\'s housing is split along its seam like a dropped egg.',
      opts: [
        T('[Seat the new regulator and open the valves]', 'fit', {if: G => G.questActive('last_nine_days') && G.allDead('kr', 6) && !G.flags.recycler_on}),
        T('Step back.', null, {act: G => { if (G.questActive('cracked_housing')) G.setFlag('saw_housing', 1); }})]},
    fit: {say: 'Ruth calls the numbers, you turn the wheels. The rig\'s needles swing, shiver, and settle. Deep in the hill something begins to knock, then to hum, then to run. Somewhere inside Haven 12, four hundred people hear water.',
      opts: [T('Step back.', null, {act: G => { G.setFlag('recycler_on', 1); G.addXp(150); }})]},
  }},
};

export const POINTS = {
  sr_strongbox: {label: pt => G.questActive('collectors_safe') && !G.has('salt_ledger') ? (G.has('renn_slip') ? 'Open the salt factor\'s strongbox (31-7-19)' : G.count('bobby_pin') >= 2 ? 'Pick the strongbox (2 bobby pins)' : 'A locked strongbox') : null,
    use: pt => {
      if (G.has('renn_slip')) { G.give('salt_ledger', 1); G.msg('The dial turns sweetly. Under a bag of chits: a fat ledger bound in salt-stiff leather.'); checkQuests(); return; }
      if (G.count('bobby_pin') < 2) { G.msg('Combination lock. Deputy Renn carries the numbers, they say. Or bring two bobby pins.'); return; }
      G.take('bobby_pin', 2);
      if (G.stat('agility') + G.stat('intellect') >= 11 || Math.random() < 0.45) { G.give('salt_ledger', 1); G.karma(-2, 'Robbed the salt factor'); G.msg('Two pins, one bent double, and the old lock gives. The ledger is inside.'); checkQuests(); }
      else G.msg('Both pins snap in the lock. Nobody heard. Probably.'); }},
  kf_rig: {label: pt => G.questActive('calibration_rig') && !G.has('calib_rig') && !G.flags.rig_in ? 'Take the calibration rig' : null,
    use: pt => { G.give('calib_rig', 1); G.msg('A steel case on a rusted cart: KESTREL FIELD - INSTRUMENT SHOP. Heavy, and silent; its cell is dead.'); checkQuests(); }},
  quarry_furnace: {label: pt => G.questActive('housing_cast') && !G.has('housing_cast') && !G.flags.cast_in ? (G.count('scrap_metal') >= 6 && G.has('fuel_can') ? 'Fire the furnace and pour the housing' : 'An old furnace (needs 6 scrap metal and a fuel can)') : null,
    use: pt => {
      if (G.count('scrap_metal') < 6 || !G.has('fuel_can')) { G.msg('The furnace still draws, but you need iron to melt and fuel to melt it with.'); return; }
      G.take('scrap_metal', 6); G.take('fuel_can', 1); G.give('housing_cast', 1); G.addXp(60);
      G.msg('The fuel catches with a roar. An hour of feeding scrap and working the bellows, and orange iron runs into Ruth\'s mould. You let it cool and knock it out: a housing.'); checkQuests(); }},
  hd_panel: {label: pt => G.questKnown('cracked_housing') ? 'Use the recycler service panel' : null, use: pt => G.talk('hd_panel')},
  hd_cache: {label: pt => G.questActive('havens_doubt') && !!G.flags.met_calder && !G.has('saboteur_note') && !G.flags.doubt_end ? 'Search behind the supply tent' : null,
    use: pt => { G.give('saboteur_note', 1); G.msg('Under a tarp behind the supply tent: a pair of bolt cutters, wet with water, and a note pinned to the handle.'); checkQuests(); }},
  ufo_breach: {label: pt => G.questActive('lights_over_ridge') && !G.flags.ufo_breach ? 'Look into the hull breach' : null,
    use: pt => { G.setFlag('ufo_breach', 1); G.give('alien_alloy', 1); G.msg('Inside the split hull the walls are smooth and warm, with no seams anywhere. A strip of torn plating comes away in your hand, light as paper.'); checkQuests(); }},
  ufo_pod: {label: pt => G.questActive('lights_over_ridge') && !G.flags.ufo_pod ? 'Examine the scorched pod' : null,
    use: pt => { G.setFlag('ufo_pod', 1); G.msg('A pod, flung clear of the wreck and burst open. It is shaped for something small, with long arms and longer legs. It is empty, and there is dried blue on the rim.'); checkQuests(); }},
  ufo_cockpit: {label: pt => G.questActive('lights_over_ridge') && !G.flags.ufo_cockpit ? 'Climb up to the cracked dome' : (G.questActive('signal_home') && !G.has('alien_cell') && !G.flags.ufo_core_taken ? 'Take the power cell from the cockpit' : null),
    use: pt => {
      if (G.questActive('signal_home')) { G.setFlag('ufo_core_taken', 1); G.give('alien_cell', 1); G.msg('You prise the cell out of its cradle. Every light in the saucer goes out at once, and then something in the wreck starts to move.'); checkQuests(); return; }
      G.setFlag('ufo_cockpit', 1); G.msg('Under the cracked dome: three seats, two of them burnt black. Panels of light still pulse slowly, like breathing. At the centre, a glass cylinder glows in its cradle.'); checkQuests(); }},
  ufo_trail: {label: pt => G.questActive('not_alone') && !G.flags.ufo_tracks ? 'Follow the tracks from the pod' : null,
    use: pt => { G.setFlag('ufo_tracks', 1); G.msg('Three-toed prints, dragging one foot, leading south-east into the rocks. Spots of blue every few steps.'); checkQuests(); }},
  kdst_mast: {label: pt => G.questActive('signal_home') && G.has('visitor_beacon') && !G.flags.beacon_set ? 'Wire the beacon into the radio mast' : null,
    use: pt => { G.take('visitor_beacon', 1); G.setFlag('beacon_set', 1); G.addXp(80); G.msg('You clamp the beacon to the mast and tie it into the feed. KDST\'s lights dim, every one, and a thread of pale light goes straight up from the mast into the sky and stays there.'); checkQuests(); }},
};
export const WORLD_POINTS = [
  {id: 'sr_strongbox', x: 329.0, z: 58.0, r: 2.2},
  {id: 'kf_rig', x: 292.0, z: -322.0, r: 2.4},
  {id: 'quarry_furnace', x: 158.0, z: 362.0, r: 3.0},
  {id: 'hd_panel', x: -3.0, z: 219.5, r: 2.4},
  {id: 'hd_cache', x: -10.5, z: 211.5, r: 2.2},
  {id: 'ufo_breach', x: 689.5, z: -427.5, r: 3.0},
  {id: 'ufo_pod', x: 700.0, z: -436.0, r: 2.6},
  {id: 'ufo_cockpit', x: 684.0, z: -424.0, r: 4.2},
  {id: 'ufo_trail', x: 704.0, z: -440.0, r: 2.6},
  {id: 'kdst_mast', x: -166.0, z: -356.0, r: 3.0},
];

const E = (id, type, x, z, extra = {}) => Object.assign({id, type, x, z, always: true}, extra);
export const SPAWNS = [
  E('kr0', 'raider', -18, 188, {name: 'Gantry Raider', flag: 'kess_raid', unless: 'kess_raid_done'}),
  E('kr1', 'raider', 16, 186, {name: 'Gantry Raider', flag: 'kess_raid', unless: 'kess_raid_done'}),
  E('kr2', 'marauder', 22, 204, {name: 'Gantry Raider', flag: 'kess_raid', unless: 'kess_raid_done'}),
  E('kr3', 'raider', -22, 210, {name: 'Gantry Raider', flag: 'kess_raid', unless: 'kess_raid_done'}),
  E('kr4', 'pyro', 8, 178, {name: 'Gantry Raider', flag: 'kess_raid', unless: 'kess_raid_done'}),
  E('kr5', 'marauder', -6, 176, {name: 'Gantry Boss', flag: 'kess_raid', unless: 'kess_raid_done'}),
  E('sentinel', 'guardbot', 690, -430, {name: 'Wreck Sentinel', flag: 'ufo_core_taken'}),
  E('sf0', 'raider', 708, -404, {name: 'Scrap Picker'}),
  E('sf1', 'raider', 712, -410, {name: 'Scrap Picker'}),
  E('sf2', 'hound', 640, -440),
  E('sf3', 'hound', 644, -444),
];

export const TRIGGERS = [
  // act three begins once Meridian is settled, whichever way
  {if: G => !!G.flags.ending && !G.questKnown('cracked_housing'), do: G => { G.start('cracked_housing'); G.setFlag('radio', 'door_call'); }},
  {if: G => G.visited('starfall') && !G.questKnown('lights_over_ridge'), do: G => G.start('lights_over_ridge')},
  {if: G => G.flags.silas_war && G.flags.npcDead_silas && !G.has('qh_book') && !G.questDone('old_debts'), do: G => { G.give('qh_book', 1); G.setFlag('silas_gone', 1); G.msg('In Silas Crow\'s coat: a little book bound in black oilcloth.'); }},
  {if: G => G.flags.npcDead_visitor && !G.flags.visitor_end, do: G => { G.setFlag('visitor_end', 'killed'); G.setFlag('visitor_gone', 1); }},
  {if: G => G.flags.npcDead_visitor && !G.flags.visitor_gone, do: G => G.setFlag('visitor_gone', 1)},
  {if: G => G.flags.recycler_on && !G.flags.heard_haven_end, do: G => { G.setFlag('heard_haven_end', 1); G.setFlag('radio', 'haven_water'); }},
  {if: G => G.allDead('kr', 6) && G.flags.kess_raid && !G.flags.kess_raid_won, do: G => { G.setFlag('kess_raid_won', 1); G.msg('The last of Kess\'s raiders breaks and runs for the Gantry road.'); }},
  {if: G => G.day >= 3 && G.visited('lantern_row') && !G.flags.radio_row, do: G => { G.setFlag('radio_row', 1); G.setFlag('radio', 'row_lights'); }},
  {if: G => G.day >= 4 && !G.flags.radio_starfall && !G.questKnown('lights_over_ridge'), do: G => { G.setFlag('radio_starfall', 1); G.setFlag('radio', 'starfall_news'); }},
];
export const RADIO = {
  door_call: {h: 'HAVEN 12 — OVERSEER ADAIR', who: 'overseer', t: `> HAVEN 12 OPEN CHANNEL

This is Overseer Adair, to whoever is still listening, and to you in particular.

Meridian is settled. I won't pretend I understand everything you did out there. I understand this: Haven's recycler is on its last filter, and I have moved everyone who can walk out to the door.

Ruth Adebayo says she can build us a regulator. She needs your legs. Come to the camp at the door.

> END`},
  haven_water: {h: 'HAVEN 12 — OVERSEER ADAIR', who: 'overseer', t: `> HAVEN 12 OPEN CHANNEL

The reserve gauge is rising. I have watched it for an hour and I don't trust my own eyes.

Four hundred people will drink tonight. The door stays open. Anyone who wants the sky can have it, and anyone who wants a bunk can have one.

To the one who walked out first: thank you. Come home sometimes.

> END`},
  row_lights: {h: 'MERIDIAN FREE RADIO', who: 'radio', t: `> MERIDIAN FREE RADIO — NOTICES

Lantern Row reports forty-one lamps lit last night and forty-one lamps present this morning, which is a record.

If you're travelling east of Saltreach, stop at the Lantern. Tell Hesper the radio sent you. She'll charge you double.

> END`},
  starfall_news: {h: 'MERIDIAN FREE RADIO', who: 'radio', t: `> MERIDIAN FREE RADIO — NOTICES

Strange one tonight. Three of you have written in about lights over the eastern ridge, in a triangle, holding still.

Orrin Pike, our astronomer out past the drive-in, says he saw one of them come down. Orrin, if you're listening: please stop leaving your telescope pointed at the KDST mast.

> END`},
};
export const EPILOGUE = [
  {if: G => G.questDone('last_nine_days'), t: 'Haven 12\'s recycler ran for another hundred years on a regulator built from an airfield rig, a tinker\'s gaskets and iron from a quarry furnace. The great door was never shut again.'},
  {if: G => G.flags.doubt_end === 'exiled', t: 'Calder Voight and six families made a home on Lantern Row. Their children grew up under the sky and went back to visit Haven 12 on holidays, as tourists.'},
  {if: G => G.flags.doubt_end === 'talked', t: 'Calder Voight stayed, and helped, and when the water ran he walked out of the door and didn\'t come back, and nobody had to cut a line to let him go.'},
  {if: G => G.flags.qh_member, t: 'The Quiet Hands kept their rules: never the Row, never the sick, never a kid. Every farm in the salt country knew a lantern scratched on a door frame meant someone was looking out for them, a little crookedly.'},
  {if: G => G.flags.visitor_end === 'home', t: 'On clear nights Orrin Pike kept his telescope on the ridge until he died. Three lights came back once, the year after, held still over Starfall for an hour, and went away.'},
  {if: G => G.flags.visitor_end === 'killed', t: 'The saucer at Starfall was picked to the frame within a year. The Visitor\'s grave is a cairn Orrin Pike built himself, and nobody else knows what is under it.'},
];
