// Build 15 story layer: the Ashwood, east through Kettle Pass. Three new places with people in them (Cinder Gap, the
// trading town in the basin; the Ashborn tribe's walled camp; the fire lookout and its hermit), two ruins with
// trouble in them (Mercy Falls and its hospital; the Sunset drive-in, where the Reel Kings sit), and four quests
// that cross each other:
//
//  - The Mercy Road (Mayor Odile Brandt): Cinder Gap's caravans keep vanishing. The trail runs through the Reel
//    Kings at the drive-in (fight them, buy them off, or run them out) to the hospital at Mercy Falls, where the
//    last caravan went on the mayor's secret orders. What you tell the town about that is up to you.
//  - The Burning Man (Elder Saba of the Ashborn): the tribe's Ember-Speaker says the man in the fire tower calls the
//    fires down. Kill him and bring his voice-box, prove he's a fire warden who has saved them twice, or find out
//    who has really been setting the fires.
//  - Mercy's Ledger (Doc Sorrel): the hospital's pharmacy stock, and what to do with it.
//  - Last Call (Juno at the Ember Room): her little brother ran off to the Reel Kings. Bring him home before it
//    comes to shooting at the drive-in.
//
// New in the story format (scripts/game.gd reads them): NPCS (new people, with flag/unless to come and go), LOCS (new
// places), VENDORS (their shops), GUARDS (who joins a fight), and spawns with always/group/neutral/flag/unless.

export const FACTIONS = {
  cinder: {n: 'Cinder Gap', leader: 'Mayor Odile Brandt', desc: 'A trading town in the basin past Kettle Pass. One street, one saloon, one water tower, and every caravan in the Ashwood stops there.'},
  ashborn: {n: 'The Ashborn', leader: 'Elder Saba', desc: 'A tribe that came out of the burning forest a generation ago and kept the fire as their god. They trade furs and meat and they do not like towers.'},
};
export const QUEST_REP = {
  mercy_road: {cinder: 3}, burning_man: {ashborn: 3}, mercy_ledger: {cinder: 1}, last_call: {cinder: 1},
};
export const NPC_FACTION = {odile: 'cinder', pike: 'cinder', juno: 'cinder', sorrel: 'cinder', abe: 'cinder', cg_guard1: 'cinder', cg_guard2: 'cinder',
  cg_folk1: 'cinder', cg_folk2: 'cinder', cg_folk3: 'cinder', hester2: 'cinder',
  saba: 'ashborn', tull: 'ashborn', ira: 'ashborn', ab_guard1: 'ashborn', ab_guard2: 'ashborn', ab_folk1: 'ashborn', ab_folk2: 'ashborn'};
export const VENDOR_FACTION = {pike: 'cinder', juno: 'cinder', abe: 'cinder', ira: 'ashborn'};
export const GUARDS = ['cg_guard1', 'cg_guard2', 'ab_guard1', 'ab_guard2'];

export const LOCS = {
  cinder_gap: {name: 'Cinder Gap', x: 820, z: -40, r: 46},
  ashborn: {name: 'Ashborn Camp', x: 1310, z: -330, r: 32},
  lookout: {name: 'Crane\'s Lookout', x: 990, z: -234, r: 20},
  mercy_falls: {name: 'Mercy Falls', x: 1120, z: 300, r: 56},
  drivein: {name: 'Sunset Drive-In', x: 690, z: 232, r: 32},
  kettle_pass: {name: 'Kettle Pass', x: 520, z: -64, r: 24},
};

const F = (body, skin, hat = null, coat = null, bulk = 1) => ({fem: true, body, skin, hat, coat, bulk});
const M = (body, skin, hat = null, coat = null, bulk = 1) => ({fem: false, body, skin, hat, coat, bulk});
const N = (id, name, x, z, rot, look, extra = {}) => Object.assign({id, name, x, z, rot, wander: null, scale: 1, look}, extra);
export const NPCS = [
  N('odile', 'Mayor Odile Brandt', 800.5, -26.0, 3.1416, F('#4a5a6a', '#c89a78', null, '#3a4250')),
  N('pike', 'Pike', 802, -55.6, 0, M('#6a5a38', '#d8a884', 'cap', null, 1.2)),
  N('juno', 'Juno Reyes', 814.5, -59.4, 0, F('#7a2a2a', '#a8724c')),
  N('sorrel', 'Doc Sorrel', 833.0, -53.2, 0, M('#d8d4c8', '#8a5a3a', null, '#c8c4b8')),
  N('abe', 'Abe Kinney', 855.0, -31.4, 3.1416, M('#3a3a30', '#e0ac88', 'cap', null, 1.25)),
  N('cg_guard1', 'Gap Watch', 780.5, -46.5, -1.5708, M('#5a5040', '#c89a78', 'helmet', '#4a4030', 1.1)),
  N('cg_guard2', 'Gap Watch', 780.5, -35.5, -1.5708, F('#5a5040', '#8a5a3a', 'helmet', '#4a4030', 1.05)),
  N('cg_folk1', 'Cinder Gap Settler', 812, -40, 0, F('#8a6a4a', '#d2a07a', 'wide'), {wander: {x: 815, z: -40, r: 22}}),
  N('cg_folk2', 'Cinder Gap Settler', 826, -38, 0, M('#4a5a3a', '#b8865a'), {wander: {x: 820, z: -40, r: 24}}),
  N('cg_folk3', 'Cinder Gap Settler', 795, -42, 0, M('#6a4a4a', '#e0ac88', 'cap'), {wander: {x: 800, z: -42, r: 18}}),
  N('hester2', 'Hester Vail', 791.0, -49.5, 0, F('#5a4a38', '#d2a07a', 'wide', '#6a5040'), {flag: 'hesterSafe'}),
  N('crane', 'Ellis Crane', 984.2, -238.2, 1.5708, M('#5a6a4a', '#d8a884', 'wide', '#4a5a3a', 0.95), {unless: 'craneDead'}),
  N('saba', 'Elder Saba', 1310, -343.2, 0, F('#6a4a30', '#8a5a3a', 'hood', '#5a3a28')),
  N('tull', 'Ember-Speaker Tull', 1325.5, -332.5, -1.5708, M('#2a1a14', '#a8724c', 'hood', '#3a1a10', 1.1), {unless: 'tullGone', fight: {hp: 160, dmg: 13, ranged: false}}),
  N('ira', 'Ira', 1321.5, -319.5, 2.4, F('#7a5a3a', '#b8865a'), {wander: {x: 1312, z: -324, r: 10}}),
  N('ab_guard1', 'Ashborn Warden', 1284.5, -334.0, -1.5708, M('#5a3a28', '#8a5a3a', 'hood', '#4a2a1a', 1.15)),
  N('ab_guard2', 'Ashborn Warden', 1284.5, -326.0, -1.5708, F('#5a3a28', '#a8724c', 'hood', '#4a2a1a', 1.1)),
  N('ab_folk1', 'Ashborn', 1300, -320, 0, M('#6a4a30', '#a8724c'), {wander: {x: 1308, z: -328, r: 12}}),
  N('ab_folk2', 'Ashborn', 1318, -338, 0, F('#6a4a30', '#8a5a3a', 'hood'), {wander: {x: 1310, z: -330, r: 11}}),
  N('hester', 'Hester Vail', 1124.0, 319.0, 3.1416, F('#5a4a38', '#d2a07a', 'wide', '#6a5040'), {unless: 'hesterSafe'}),
  N('marquee', 'Marquee', 690.0, 246.8, 3.1416, M('#2a2a2c', '#c89a78', 'wide', '#8a2a8a', 1.2), {unless: 'rkGone', fight: {hp: 230, dmg: 15, ranged: true}}),
  N('dex', 'Dex Reyes', 681.5, 225.5, 1.5708, M('#3a3a30', '#a8724c', 'cap'), {unless: 'dexHome', wander: {x: 684, z: 226, r: 5}}),
  N('dex2', 'Dex Reyes', 812.0, -58.2, 0, M('#3a3a30', '#a8724c', 'cap'), {flag: 'dexHome'}),
];

export const VENDORS = {
  pike: {name: 'Pike\'s Goods', caps: 700, buy: 1.35, sell: 0.55, town: true, likes: {junk: 1.3},
    stock: [['stimpak', 3], ['radaway', 2], ['purified_water', 6], ['jerky', 5], ['canned_beans', 4], ['flatbread', 4], ['ammo_9', 80], ['ammo_rifle', 30], ['shells', 24],
      ['ammo_44', 18], ['duct_tape', 4], ['scrap_metal', 6], ['bobby_pin', 8], ['molotov', 2], ['leather_jacket', 1], ['lever_rifle', 1], ['coffee_tin', 2], ['fuel_can', 2]]},
  juno: {name: 'The Ember Room', caps: 300, buy: 1.3, sell: 0.5, town: true, likes: {aid: 1.2},
    stock: [['moonshine', 6], ['prewar_cola', 4], ['cactus_water', 4], ['hunter_stew', 3], ['smoked_fish', 3], ['boar_ribs', 2], ['rad_tea', 3], ['coffee_tin', 2]]},
  abe: {name: 'Kinney Repairs', caps: 500, buy: 1.4, sell: 0.6, town: true, likes: {junk: 1.5},
    stock: [['scrap_metal', 10], ['gears', 6], ['circuit', 4], ['duct_tape', 6], ['cell', 30], ['frag', 3], ['prox_mine', 2], ['claw_hammer', 1], ['carbine', 1]]},
  ira: {name: 'Ira\'s Furs', caps: 250, buy: 1.25, sell: 0.65, likes: {aid: 1.3},
    stock: [['jerky', 8], ['roast_molerat', 4], ['iguana_stick', 4], ['pinyon_cake', 4], ['hollow_shrooms', 3], ['glowcap_tea', 2], ['bowie', 1], ['leather_jacket', 1]]},
};

export const ITEMS = {
  caravan_log: {n: 'Caravan Log', t: 'quest', w: 0.3, v: 0, desc: 'Hester Vail\'s trail book. The last entries: "Kings took the brahmin at the drive-in turn. Paid the screen tax. Pressing on to Mercy per O.B. Nobody is to know."'},
  mercy_ledger: {n: 'Mercy General Ledger', t: 'quest', w: 0.5, v: 0, desc: 'The hospital pharmacy\'s stock book, kept to the last week before the war. Half of it is still on the shelves, if you count what the ghouls left.'},
  mercy_meds: {n: 'Crate of Antibiotics', t: 'quest', w: 6, v: 0, desc: 'Sealed pre-war antibiotics, a whole case, from the Mercy General pharmacy. Doc Sorrel would trade a kidney for this. So would Pike.'},
  crane_radio: {n: 'Fire-Watch Radio', t: 'quest', w: 3, v: 0, desc: 'A battered forestry-service radio, hand-cranked, with "CRANE" scratched into the case. The Ashborn call it the Burning Man\'s voice.'},
  fire_log: {n: 'Fire-Watch Log', t: 'quest', w: 0.4, v: 0, desc: 'Ellis Crane\'s logbook: every smoke he\'s seen from the tower in eleven years, with times and bearings. Twice, flares fired over the Ashborn camp an hour before the fire reached it.'},
  tull_flint: {n: 'Oil-Soaked Rags and Flint', t: 'quest', w: 1, v: 0, desc: 'Found in the hollow under the Ember Mother: rags soaked in lamp oil, a striker, and a pouch of the red ochre only the Ember-Speaker wears.'},
  ember_charm: {n: 'Ember Charm', t: 'junk', w: 0.1, v: 40, desc: 'A twist of charred pine and red thread the Ashborn give to people the fire has decided not to eat. Elder Saba tied it on you herself.'},
  screen_ticket: {n: 'Drive-In Ticket', t: 'junk', w: 0, v: 2, desc: 'ADMIT ONE. SUNSET DRIVE-IN. Marquee hands these out to people he\'s decided not to shoot.'},
};

export const QUESTS = {
  mercy_road: {t: 'The Mercy Road',
    desc: 'Cinder Gap lives on its caravans, and three of them have gone down the Mercy Falls road this season and not come back. Mayor Brandt wants to know why, and wants it fixed.',
    stages: [
      {txt: 'Find the last caravan. The Mercy road runs south-east from Cinder Gap.', pos: () => ({x: 992, z: 165}), done: G => G.has('caravan_log')},
      {txt: 'The log says the Reel Kings at the Sunset Drive-In took a toll. Deal with Marquee: buy the road, run them off, or end them.', at: 'drivein',
        done: G => !!G.flags.rk_deal || G.flags.npcDead_marquee || G.allDead('rk', 5)},
      {txt: 'The last wagons went on to Mercy Falls "per O.B." Find out what happened at the hospital.', at: 'mercy_falls', done: G => !!G.flags.hesterFound},
      {txt: 'Clear the hospital so Hester Vail can get out.', at: 'mercy_falls', done: G => G.allDead('mf', 6)},
      {txt: 'Tell Mayor Brandt what happened at Mercy Falls, and decide whether Cinder Gap hears about her orders.', at: 'cinder_gap'}],
    reward: G => G.flags.mr_end === 'told' ? {xp: 420, caps: 150} : {xp: 380, caps: 400}},
  burning_man: {t: 'The Burning Man',
    desc: 'The Ashborn\'s Ember-Speaker says the man in the fire tower calls the fires down on the forest. Elder Saba isn\'t sure, and would rather you looked before her hunters do.',
    stages: [
      {txt: 'Go to the fire tower in the Ashwood and see the "Burning Man" for yourself.', at: 'lookout', done: G => !!G.flags.bm_met},
      {txt: G => G.flags.bm_hint ? 'Bring Elder Saba proof: Crane\'s fire log, his radio, or whatever is hidden under the Ember Mother.' : 'Bring Elder Saba proof one way or the other: Crane\'s fire log, or his radio.',
        at: 'ashborn', done: G => G.has('fire_log') || G.has('crane_radio') || G.has('tull_flint')},
      {txt: 'Put what you found before Elder Saba.', at: 'ashborn'}],
    reward: G => G.flags.bm_end === 'tull' ? {xp: 340, caps: 0} : G.flags.bm_end === 'radio' ? {xp: 220, caps: 120} : {xp: 300, caps: 60}},
  mercy_ledger: {t: 'Mercy\'s Ledger',
    desc: 'Doc Sorrel has three fevers in the back room and nothing to treat them with. The Mercy General pharmacy was the best-stocked in the county before the war.',
    stages: [
      {txt: 'Search the pharmacy at Mercy General, on the plateau south-east of Cinder Gap.', at: 'mercy_falls', done: G => G.has('mercy_meds')},
      {txt: 'Bring the antibiotics to Doc Sorrel. (Pike would pay for them too.)', at: 'cinder_gap'}],
    reward: G => G.flags.ml_end === 'pike' ? {xp: 120, caps: 0} : {xp: 240, caps: 80}},
  last_call: {t: 'Last Call',
    desc: 'Juno\'s little brother Dex ran off to the Reel Kings at the drive-in. She wants him home before somebody decides to clear the Kings out.',
    stages: [
      {txt: 'Find Dex Reyes at the Sunset Drive-In and talk him into coming home.', at: 'drivein', done: G => !!G.flags.dexHome || !!G.flags.npcDead_dex},
      {txt: 'Tell Juno.', at: 'cinder_gap'}],
    reward: G => G.flags.npcDead_dex ? {xp: 60, caps: 0} : {xp: 200, caps: 60}},
};

const T = (t, go, extra = {}) => Object.assign(go ? {t, go} : {t}, extra);
export const DIALOGUE = {
  // ---------------------------------------------------------------- Cinder Gap
  odile: {name: 'Mayor Odile Brandt', nodes: {
    hub: {say: G => G.flags.met_odile ? (G.questActive('mercy_road') ? 'Anything on the road?' : 'Mayor\'s office. Such as it is. What do you need?')
        : 'You came through Kettle Pass? On foot? Then you\'re either brave, lost or selling something. I\'m Odile Brandt. I run Cinder Gap, which mostly means I count the water and listen to people shout.',
      opts: [
        T('Tell me about Cinder Gap.', 'town', {act: G => G.setFlag('met_odile', 1)}),
        T('You look like you\'ve got a problem.', 'problem', {if: G => !G.questKnown('mercy_road'), act: G => G.setFlag('met_odile', 1)}),
        T('About the caravans.', 'road', {if: G => G.questActive('mercy_road') && G.qStage('mercy_road') < 4}),
        T('I found Hester Vail. She\'s alive, and she told me who sent her.', 'end', {if: G => G.questActive('mercy_road') && G.qStage('mercy_road') === 4}),
        T('Who else should I know around here?', 'people', {act: G => G.setFlag('met_odile', 1)}),
        {t: 'Goodbye.', act: G => G.setFlag('met_odile', 1)}]},
    town: {say: 'Forty-one people, one deep well, and the only road through the Ashwood that doesn\'t go uphill both ways. Caravans come in from Mercy, the Kettle, the Ashborn when they feel like trading. We feed them, water them, fix their axles and take a cut. That\'s the whole economy. It works when the caravans arrive.',
      opts: [T('And when they don\'t?', 'problem', {if: G => !G.questKnown('mercy_road')}), T('Back up a second.', 'hub')]},
    problem: {say: 'Three caravans down the Mercy road this season. None back. Not a wheel, not a mule, not a drover come limping in. The Kings at the old drive-in tax anything that passes, but they\'ve never kept a whole train before. I need someone who isn\'t from here to go and look. Someone the Kings won\'t recognise.',
      opts: [
        T('I\'ll find your caravans.', 'yes', {act: G => G.start('mercy_road')}),
        T('What\'s in it for me?', 'pay'),
        T('Not my road.', 'hub')]},
    pay: {say: 'Three hundred chits from the town chest, which is about a third of the town chest. And the Gap will remember your name kindly, which out here is worth more than you\'d think.',
      opts: [T('Deal.', 'yes', {act: G => G.start('mercy_road')}), T('Make it four hundred. Three caravans is a lot of trade.', 'pay_more', {check: ['charm', 6]}), T('I\'ll think about it.', 'hub')]},
    pay_more: {say: '...Four hundred. If you bring back the wagons, or what happened to them. Don\'t tell Pike I said yes that fast.',
      opts: [T('Deal.', 'yes', {act: G => { G.setFlag('mr_pay', 1); G.start('mercy_road'); }})]},
    yes: {say: 'The last train left eleven days ago: four wagons, Hester Vail driving the lead. Hester\'s careful. If she wrote anything down, it\'ll be in her trail book. Start on the road south-east, past the canyon ford.',
      opts: [T('Eleven days. I\'ll hurry.', 'hub')]},
    road: {say: G => G.qStage('mercy_road') === 0 ? 'South-east road, past the ford. If you find wreckage, look for Hester\'s trail book.'
        : G.qStage('mercy_road') === 1 ? 'The Kings. Of course. Marquee holds court in front of that screen like it\'s still showing something. I don\'t care how you settle it, as long as the road opens.'
        : 'Mercy Falls? Why would they... No. Go on. Tell me when you know.',
      opts: [T('One more thing about the last caravan.', 'secret', {if: G => G.has('caravan_log') && !G.flags.mr_pressed}), T('All right.', 'hub')]},
    secret: {say: 'Hester\'s log says "per O.B." Those are my initials, yes. I... the town council voted against sending anyone to Mercy. Ghouls, they said. But Doc\'s running out of medicine and the pharmacy\'s right there. So I asked Hester, quietly. If she\'s dead, that\'s on me.',
      opts: [T('Then let\'s hope she isn\'t.', 'hub', {act: G => G.setFlag('mr_pressed', 1)}),
        T('You didn\'t lose three caravans to Mercy. Only the last one went there.', 'secret2', {check: ['intellect', 6], act: G => G.setFlag('mr_pressed', 1)})]},
    secret2: {say: 'Right. The first two were the Kings, and I paid for that silence too. A mayor who loses caravans gets voted out; a mayor who loses them to bandits gets sympathy. ...You\'re going to do what you want with that. I know.',
      opts: [T('I will.', 'hub')]},
    end: {say: 'Alive. Thank God. And she told you, of course she did. So. Do I stand up in the Ember Room and tell forty people I sent their cousins into a ghoul nest behind their backs? Or do you let it lie, and I spend the next ten years making it up to them quietly?',
      opts: [
        T('They deserve the truth. Tell them, or I will.', 'end_told', {act: G => { G.setFlag('mr_end', 'told'); G.rep('cinder', 1); G.karma(6, 'Made the mayor come clean'); G.complete('mercy_road'); }}),
        T('Let it lie. You meant well and Hester\'s home.', 'end_kept', {act: G => { G.setFlag('mr_end', 'kept'); G.karma(-2, 'Kept the mayor\'s secret'); G.complete('mercy_road'); }}),
        T('Tell them yourself, and tell them why. They\'ll forgive the reason.', 'end_both', {check: ['charm', 7], act: G => { G.setFlag('mr_end', 'told'); G.setFlag('odileStays', 1); G.rep('cinder', 2); G.karma(8, 'Talked the mayor into the truth'); G.complete('mercy_road'); }})]},
    end_told: {say: 'Yes. Well. I\'d rather it came from me. Here: the town chest\'s share, minus what I\'ll owe Hester. I expect I\'ll be "former mayor" by the end of the week.',
      opts: [T('Goodbye, Odile.')]},
    end_kept: {say: G => `Thank you. I won't forget it, and neither will the chest. ${G.flags.mr_pay ? 'Four hundred, and a bit over.' : 'Four hundred, which is more than I promised.'} If anybody asks, the Kings took the wagons and you sorted the Kings.`,
      opts: [T('Goodbye.')]},
    end_both: {say: 'I said it. All of it, in the Ember Room with the shutters open. Juno poured me a drink after and nobody threw it at me. They want me to stay. God knows why. Thank you.',
      opts: [T('They know you\'ll tell them now. That\'s why.')]},
    people: {say: 'Pike runs the store and thinks he runs the town. Juno keeps the Ember Room and knows everything said in it. Doc Sorrel is the only medic between here and the Kettle. Abe Kinney fixes anything with a bolt in it. And east, in the hills, the Ashborn. Be polite to them. They remember.',
      opts: [T('Who are the Ashborn?', 'ashborn'), T('Thanks.', 'hub')]},
    ashborn: {say: 'A tribe. Came out of the forest fires when I was a girl and decided the fire had chosen them. They trade fair and fight hard. Lately their Ember-Speaker\'s been preaching against "the tower", which I assume means old Crane at the lookout. Crane\'s harmless. Mostly.',
      opts: [T('Good to know.', 'hub')]},
  }},
  pike: {name: 'Pike', nodes: {
    hub: {say: G => G.flags.met_pike ? 'Back again. Wallet first, conversation after.' : 'Pike\'s Goods. Everything from the Kettle to Mercy, at prices that are fair if you\'ve never been anywhere else. I\'m Pike. I also sit on the council, so be nice.',
      opts: [
        T('Let\'s trade.', null, {act: G => { G.setFlag('met_pike', 1); G.openTrade('pike'); }}),
        T('What\'s the word on the road?', 'word', {act: G => G.setFlag('met_pike', 1)}),
        T('You\'d pay for medicine, wouldn\'t you?', 'meds', {if: G => G.has('mercy_meds') && G.questActive('mercy_ledger')}),
        T('What do you think of the mayor?', 'mayor', {act: G => G.setFlag('met_pike', 1)}),
        {t: 'Goodbye.', act: G => G.setFlag('met_pike', 1)}]},
    word: {say: 'Word is the Mercy road\'s cursed, the Kings are getting greedy, and the Ashborn are sharpening things. Also, a caravan from the Kettle says the valley\'s got a new hero who walked out of a vault. You wouldn\'t know anything about that.',
      opts: [T('Never heard of them.', 'hub'), T('That\'s me.', 'hero')]},
    hero: {say: 'Ha. Then you\'re bad for business: people who walk out of vaults buy one of everything. Go on, make me rich.', opts: [T('Let\'s trade.', null, {act: G => G.openTrade('pike')}), T('Later.', 'hub')]},
    mayor: {say: 'Odile? Honest as a brick and about as flexible. She\'s been odd this season. Counting the chest twice. Asking Doc how long the medicine lasts. If you\'re working for her, ask her where the last caravan was really going.',
      opts: [T('You know something.', 'mayor2'), T('I\'ll keep it in mind.', 'hub')]},
    mayor2: {say: 'I know the last train loaded empty crates and water for a week, which is more water than you need for a three-day run to Mercy and back. I keep the books. Books notice.', opts: [T('Thanks, Pike.', 'hub')]},
    meds: {say: 'A full case? Sealed? Five hundred chits, right now, cash. Doc will tell you it\'s for the sick. I\'ll tell you the sick will pay me for it either way, and you\'ll be five hundred richer.',
      opts: [
        T('Sold.', 'meds_sold', {act: G => { G.take('mercy_meds', 1); G.addCaps(500); G.setFlag('ml_end', 'pike'); G.karma(-8, 'Sold the town\'s medicine to Pike'); G.rep('cinder', -2); G.complete('mercy_ledger'); }}),
        T('No. It goes to the Doc.', 'hub')]},
    meds_sold: {say: 'Pleasure. Doc\'s prices will be very reasonable, considering.', opts: [T('Goodbye.')]},
  }},
  juno: {name: 'Juno Reyes', nodes: {
    hub: {say: G => G.flags.dexHome && !G.questDone('last_call') ? 'He\'s here. He\'s really here. Talk to me before I start crying into the till.'
        : G.flags.met_juno ? 'What\'ll it be?' : 'Welcome to the Ember Room. It was the Mercy Falls Feed and Grain once; the sign\'s better now. I\'m Juno. First drink is half price if you tell me something I don\'t know.',
      opts: [
        T('I\'ll have a look at what you\'re pouring.', null, {act: G => { G.setFlag('met_juno', 1); G.openTrade('juno'); }}),
        T('Heard anything interesting?', 'rumours', {act: G => G.setFlag('met_juno', 1)}),
        T('You look like something\'s eating at you.', 'dex', {if: G => !G.questKnown('last_call'), act: G => G.setFlag('met_juno', 1)}),
        T('Dex is home.', 'dex_home', {if: G => G.questActive('last_call') && G.flags.dexHome}),
        T('I\'m sorry, Juno. Dex didn\'t make it.', 'dex_dead', {if: G => G.questActive('last_call') && G.flags.npcDead_dex}),
        {t: 'Goodbye.', act: G => G.setFlag('met_juno', 1)}]},
    rumours: {say: G => [
        'The Ashborn\'s Ember-Speaker came to trade last month and wouldn\'t drink. Said the fire drinks for him. I\'ve met that type. It\'s never the fire.',
        'Abe Kinney rebuilt a whole Corvega engine from two dead ones and a lawnmower. Doesn\'t drive. Just likes knowing it would.',
        'Crane, the old man in the fire tower, used to come in once a season for coffee and gossip. Hasn\'t for a year. Somebody should check he\'s breathing.',
        'There\'s a light at night up at Mercy General. Ghouls don\'t need lights.'][(G.P.level + (G.flags.rumour_n || 0)) % 4],
      opts: [T('Tell me another.', 'rumours', {act: G => G.setFlag('rumour_n', (G.flags.rumour_n || 0) + 1)}), T('Thanks.', 'hub')]},
    dex: {say: 'My brother. Dex. Nineteen, all elbows, thinks he\'s immortal. He ran off to the Reel Kings at the drive-in three weeks ago because Marquee gave him a jacket and called him "kid". If somebody clears the Kings out, he\'ll be in the middle of it. Would you... could you talk to him?',
      opts: [
        T('I\'ll bring him home.', 'dex_yes', {act: G => G.start('last_call')}),
        T('He made his choice.', 'hub')]},
    dex_yes: {say: 'Tell him... tell him Mum\'s ring is still on the shelf behind the bar, and if he wants it he has to come and get it himself. He\'ll know what that means.', opts: [T('I will.', 'hub', {act: G => G.setFlag('dex_ring', 1)})]},
    dex_home: {say: 'He walked in, sat down at that stool, and asked for the ring. Then he asked for a job. I gave him both. I don\'t have much, but here. And drinks are on the house. Forever. Within reason.',
      opts: [T('Glad I could help.', 'hub', {act: G => { G.karma(5, 'Brought Dex home'); G.complete('last_call'); }})]},
    dex_dead: {say: '...Right. Right. Thank you for telling me yourself. Leave me alone for a bit, would you?', opts: [T('I\'m sorry.', null, {act: G => G.complete('last_call')})]},
  }},
  dex2: {name: 'Dex Reyes', nodes: {
    hub: {say: 'Juno\'s got me washing glasses. Honestly? It\'s better than watching the screen with Marquee waiting for a movie that\'s never coming. Thanks for, you know. Talking sense.', opts: [T('Stay out of trouble, Dex.')]},
  }},
  sorrel: {name: 'Doc Sorrel', nodes: {
    hub: {say: G => G.flags.met_sorrel ? 'Sick, shot or curious?' : 'Sorrel. Doctor, by courtesy. I learned from a book and a man who learned from a book. Sit down if you\'re bleeding; stand up if you\'re not.',
      opts: [
        T('Can you patch me up?', 'heal', {act: G => G.setFlag('met_sorrel', 1)}),
        T('You look short of supplies.', 'meds', {if: G => !G.questKnown('mercy_ledger'), act: G => G.setFlag('met_sorrel', 1)}),
        T('I found the Mercy General pharmacy stock.', 'meds_back', {if: G => G.questActive('mercy_ledger') && G.has('mercy_meds')}),
        T('What do you know about Mercy Falls?', 'mercy', {act: G => G.setFlag('met_sorrel', 1)}),
        {t: 'Goodbye.', act: G => G.setFlag('met_sorrel', 1)}]},
    heal: {say: G => G.P.caps >= 40 ? 'Forty chits and you\'ll walk out lighter by a few holes. ...There. Don\'t do that again.' : 'Forty chits, and you don\'t have forty chits. Come back when you do, or when you\'re dying, whichever comes first.',
      opts: [T('Thanks, Doc.', 'hub', {act: G => { if (G.P.caps >= 40) { G.addCaps(-40); G.heal(); } }})]},
    meds: {say: 'Short? I\'m boiling bandages. Three fevers in the back and I\'m treating them with willow bark and optimism. The pharmacy at Mercy General was the best in the county. The ghouls don\'t take pills. If you went...',
      opts: [T('I\'ll see what\'s left.', 'meds_yes', {act: G => G.start('mercy_ledger')}), T('Not a chance.', 'hub')]},
    meds_yes: {say: 'East wing, behind the main hall. Look for the steel cage. And take this: if you breathe what\'s in there long enough, you\'ll want it.', opts: [T('Thanks.', 'hub', {act: G => G.give('radaway', 1)})]},
    meds_back: {say: 'A whole case. Sealed. You... I\'m going to sit down. That\'s three people who see next month. More. Here, everything in the tin, and if you\'re ever shot within a day\'s walk, crawl here.',
      opts: [T('Glad to help.', 'hub', {act: G => { G.take('mercy_meds', 1); G.setFlag('ml_end', 'sorrel'); G.give('stimpak', 3); G.karma(6, 'Brought the medicine home'); G.complete('mercy_ledger'); }})]},
    mercy: {say: 'It was a mill town with a waterfall, before the war took the river. The hospital served the whole valley. When the bombs fell people went there to be saved, and stayed, and... changed. Most of the ghouls up there were patients. Some of them were my teacher\'s teacher.',
      opts: [T('That\'s grim.', 'hub')]},
  }},
  abe: {name: 'Abe Kinney', nodes: {
    hub: {say: G => G.flags.met_abe ? 'What\'s broken?' : 'Abe Kinney. If it has bolts, I can fix it. If it has feelings, try Juno. You want a bench, there\'s one right there. Mind the oil.',
      opts: [
        T('Show me what you\'ve got.', null, {act: G => { G.setFlag('met_abe', 1); G.openTrade('abe'); }}),
        T('Tell me about yourself.', 'me', {act: G => G.setFlag('met_abe', 1)}),
        T('Know anything about old radios?', 'radio', {if: G => G.questActive('burning_man')}),
        {t: 'Goodbye.', act: G => G.setFlag('met_abe', 1)}]},
    me: {say: 'Came up the Mercy road as a boy on the back of a mule. My father fixed wagons. I fix wagons, generators, guns, the water tower pump twice a month and Pike\'s till when he kicks it. Mostly I fix things people say can\'t be fixed, because I like the look on their faces.',
      opts: [T('A good trade.', 'hub')]},
    radio: {say: 'Crane\'s? The forestry set? Hand-crank, longwave. I rebuilt the crank on it six years back. Ashborn think it talks to the fire. It talks to nobody: there\'s nobody left on that band. He just reads out the weather to the dark. Makes him feel useful. Don\'t we all.',
      opts: [T('Huh.', 'hub', {act: G => G.setFlag('bm_abe', 1)})]},
  }},
  cg_guard1: {name: 'Gap Watch', nodes: {
    hub: {say: G => G.questDone('mercy_road') ? 'Road\'s open, they say. First quiet week we\'ve had in a year.' : 'Weapons stay holstered in town. Fights go outside the wall. Trade goes to Pike. Questions go to the mayor.',
      opts: [T('What\'s out there?', 'out'), T('Understood.')]},
    out: {say: 'West, the pass back to the Kettle. South-east, the Mercy road: the Kings sit on it at the drive-in turn. North-east, the Ashwood, the lookout, and past that the Ashborn. Don\'t pick fruit in the Ashwood. Don\'t ask why.', opts: [T('Why?', 'why'), T('Thanks.')]},
    why: {say: 'Glows.', opts: [T('Fair.')]},
  }},
  cg_guard2: {name: 'Gap Watch', nodes: {
    hub: {say: 'Name\'s not important. Your business is. Keep it peaceful.', opts: [T('Will do.')]},
  }},
  hester: {name: 'Hester Vail', nodes: {
    hub: {say: G => G.flags.hesterFound ? (G.allDead('mf', 6) ? 'It\'s quiet. Is it... is it actually quiet? Then I\'m walking out of here and I\'m not stopping till I see the water tower.' : 'Still hear them in the hall. Clear them out and I\'ll run for it. I\'m not brave, I\'m just stubborn.')
        : 'Don\'t shoot! Don\'t... you\'re not one of them. You\'re talking. Oh, thank God. Hester. Hester Vail. Did Odile send you? She must have. Nobody else knew we were here.',
      opts: [
        T('What happened?', 'what', {if: G => !G.flags.hesterFound}),
        T('Go. It\'s clear. Cinder Gap is waiting for you.', 'go', {if: G => G.flags.hesterFound && G.allDead('mf', 6)}),
        T('Hang on. I\'ll clear the way.', null, {if: G => G.flags.hesterFound && !G.allDead('mf', 6)})]},
    what: {say: 'Odile asked me quiet: take the empty wagons to Mercy, load what\'s in the pharmacy, nobody needs to know. We got in fine. Then the ones in the wards woke up. The drovers ran. I locked myself in the cage with the pills and the water. Eleven days. I\'ve been talking to the shelves.',
      opts: [T('The drovers?', 'drovers', {act: G => G.setFlag('hesterFound', 1)}), T('I\'ll get you out.', 'hub', {act: G => G.setFlag('hesterFound', 1)})]},
    drovers: {say: 'Two made it to the trees, I think. Two didn\'t. ...The mules are all dead. Don\'t tell Pike, he\'ll want to bill me.', opts: [T('I\'ll get you out.', 'hub')]},
    go: {say: 'I\'m going. Tell Odile... no, I\'ll tell her myself. Take what\'s left in here; I\'ve marked the good shelves.', opts: [T('Safe road, Hester.', null, {act: G => { G.setFlag('hesterSafe', 1); G.addXp(80); }})]},
  }},
  hester2: {name: 'Hester Vail', nodes: {
    hub: {say: G => G.questDone('mercy_road') ? (G.flags.mr_end === 'told' ? 'Odile told them. Took guts. I\'m driving the Mercy run again come spring, with six guns this time and nobody\'s secrets.' : 'Odile and I have an understanding. I don\'t talk about Mercy, she pays me to not drive to Mercy. Seems fair.')
        : 'Eleven days in a cage and I\'m alive because you can shoot. I owe you a lifetime of free axle grease. Go and see the mayor.',
      opts: [T('Take care, Hester.')]},
  }},
  // ---------------------------------------------------------------- the lookout
  crane: {name: 'Ellis Crane', nodes: {
    hub: {say: G => G.flags.met_crane ? 'You again. Pull up a stump. The kettle\'s on, the forest\'s not, and that\'s a good day.'
        : 'Well, now. A visitor. Sit, sit. Ellis Crane, Forest Service, Ashwood District, retired by nobody, still on duty. The tower\'s mine and so is the view. You\'re welcome to both.',
      opts: [
        T('Forest Service?', 'service', {act: G => G.setFlag('met_crane', 1)}),
        T('The Ashborn call you the Burning Man.', 'burning', {if: G => G.questActive('burning_man'), act: G => { G.setFlag('met_crane', 1); G.setFlag('bm_met', 1); }}),
        T('Can I see your fire log?', 'log', {if: G => G.flags.bm_met && !G.has('fire_log') && !G.flags.bm_end}),
        T('Someone\'s been setting the fires.', 'arson', {if: G => G.flags.bm_met && !G.flags.bm_hint && !G.flags.bm_end}),
        T('Give me the radio, old man.', 'threat', {if: G => G.flags.bm_met && !G.has('crane_radio') && !G.flags.bm_end}),
        {t: 'Goodbye.', act: G => G.setFlag('met_crane', 1)}]},
    service: {say: 'Eleven years before the war and forty-odd after. Nobody told me to stop, so I didn\'t. I watch for smoke. When I see it, I take a bearing, I fire a flare over whoever\'s in the way, and I read the weather out on the radio in case anybody\'s listening. Nobody is. That\'s not the point.',
      opts: [T('What is the point?', 'point'), T('A long watch.', 'hub')]},
    point: {say: 'The point is somebody\'s doing it. A forest wants a lookout. A lookout wants a forest. We keep each other company.', opts: [T('I understand.', 'hub')]},
    burning: {say: 'Do they. ...Well. I suppose from the camp all they see is the flares going up and then the fire coming after. Cause and effect, to a child. I\'m not the cause, friend. I\'m the warning. Twice I\'ve fired over their camp an hour ahead of the burn. It\'s in my log.',
      opts: [T('Then show me the log.', 'log'), T('Their Ember-Speaker wants you dead.', 'tull')]},
    tull: {say: 'Tull. Yes, I\'ve met him. Came up the hill last spring, stood under the tower and shouted at it. Funny thing: both fires that hit their camp started on the east side, upwind, right where nothing burns on its own. Pines don\'t light themselves in the spring rain.',
      opts: [T('You think it\'s arson.', 'arson'), T('I\'ll keep that in mind.', 'hub')]},
    arson: {say: 'I think if you went and looked under that big burnt pine they hang their charms on, you might find something that smells of lamp oil. I can\'t go. They\'d skin me. You, they might only shout at.',
      opts: [T('I\'ll look.', 'hub', {act: G => G.setFlag('bm_hint', 1)})]},
    log: {say: 'Take it. Every smoke for eleven years, every bearing. If it keeps an old man\'s neck unstretched, it\'s done more good than most books. Bring it back when they\'re done arguing over it.',
      opts: [T('Thank you, Ellis.', 'hub', {act: G => { G.give('fire_log', 1); G.setFlag('bm_met', 1); }})]},
    threat: {say: 'The radio. Ah. You\'re that kind of visitor. ...No. It\'s the only voice I\'ve got. If you want it, you\'ll have to take it off a dead man, and I\'m slower than I was but I\'m not dead yet.',
      opts: [
        T('It wasn\'t a request.', 'threat_win', {check: ['might', 7], act: G => { G.give('crane_radio', 1); G.karma(-6, 'Robbed Ellis Crane'); G.setFlag('craneRobbed', 1); }}),
        T('Forget I asked.', 'hub')]},
    threat_win: {say: 'Fine. Fine! Take it. Take the voice off a man and see what the forest says to you after. Get off my hill.', opts: [T('...')]},
  }},
  // ---------------------------------------------------------------- the Ashborn
  saba: {name: 'Elder Saba', nodes: {
    hub: {say: G => G.flags.met_saba ? (G.flags.bm_end ? 'The fire watches you kindly, outsider. Sit by it when you want.' : 'Speak. The fire is listening, and so am I.')
        : 'You walked through our gate without a spear in your back. Either my wardens have gone soft or the fire likes you. I am Saba. I speak for the Ashborn, when they let me.',
      opts: [
        T('Who are the Ashborn?', 'who', {act: G => G.setFlag('met_saba', 1)}),
        T('Your wardens seem worried.', 'worry', {if: G => !G.questKnown('burning_man'), act: G => G.setFlag('met_saba', 1)}),
        T('I\'ve been to the tower.', 'report', {if: G => G.questActive('burning_man') && G.qStage('burning_man') >= 1 && (G.has('fire_log') || G.has('crane_radio') || G.has('tull_flint'))}),
        T('Can I trade with your people?', 'trade', {act: G => G.setFlag('met_saba', 1)}),
        {t: 'Goodbye.', act: G => G.setFlag('met_saba', 1)}]},
    who: {say: 'When the great fire took the forest, my mother was nine. She walked out of it with seven children who were not hers and none who were. The fire took everything and gave us each other. So we keep it. We feed it, we learn from it, we do not let it go out. Some of us think it speaks.',
      opts: [T('Do you?', 'speaks'), T('Thank you for telling me.', 'hub')]},
    speaks: {say: 'I think it crackles. Tull thinks it speaks. Tull is the Ember-Speaker, so he would know, he says.', opts: [T('I see.', 'hub')]},
    worry: {say: 'Twice in five years the fire came for the camp instead of the forest. Both times, the night before, red stars rose over the tower in the hills. Tull says the man there, the Burning Man, calls the fire down with his voice-box. He wants my hunters to go up the hill. I would rather someone who is not angry went first.',
      opts: [T('I\'ll go and look.', 'worry_yes', {act: G => G.start('burning_man')}), T('Not my business.', 'hub')]},
    worry_yes: {say: 'Good. Go to the tower. Look at him. Then come back and tell me what you saw, not what you were told. Bring me something I can hold up in front of the fire.', opts: [T('I will.', 'hub')]},
    report: {say: 'Show me.',
      opts: [
        T('[Show the fire log] He\'s a fire warden. Both times, his flares warned you an hour before the fire came.', 'r_log', {if: G => G.has('fire_log'),
          act: G => { G.take('fire_log', 1); G.setFlag('bm_end', 'log'); G.rep('ashborn', 2); G.karma(5, 'Spoke for Ellis Crane'); G.give('ember_charm', 1); G.complete('burning_man'); }}),
        T('[Show the oil rags and flint] These were under the Ember Mother. With Tull\'s ochre.', 'r_tull', {if: G => G.has('tull_flint')}),
        T('[Hand over the radio] Here\'s the Burning Man\'s voice.', 'r_radio', {if: G => G.has('crane_radio'),
          act: G => { G.take('crane_radio', 1); G.setFlag('bm_end', 'radio'); G.rep('ashborn', 1); G.karma(-4, 'Gave the Ashborn Crane\'s radio'); G.complete('burning_man'); }}),
        T('Not yet.', 'hub')]},
    r_log: {say: 'Red stars, and then fire... an hour apart. Every time. He was shouting at us to run, and we were too busy hating him to listen. ...I will go up the hill myself, with meat and an apology. Take this. It means the fire has decided not to eat you.',
      opts: [T('Thank you, Elder.', 'hub')]},
    r_tull: {say: G => `Tull's ochre. Lamp oil. Under the Mother herself. ...He made us afraid so we would need him to tell us what the fire wanted. ${G.flags.tullGone ? 'And he is already gone, I see. Good.' : 'Tull! Come here and look at what the outsider found.'}`,
      opts: [T('What happens now?', 'r_tull2', {act: G => { G.take('tull_flint', 1); G.setFlag('bm_end', 'tull'); G.rep('ashborn', 3); G.karma(7, 'Exposed the Ember-Speaker'); G.give('ember_charm', 1); G.complete('burning_man'); }})]},
    r_tull2: {say: 'Now he is not the Ember-Speaker. If he goes quietly, he goes. If he does not... Wardens, watch him. And you, outsider: thank you. The camp will remember who looked under the Mother when nobody else dared.',
      opts: [T('Goodbye.', null, {act: G => { if (!G.flags.tullGone) { G.setFlag('tullTurns', 1); G.fight('tull'); } }})]},
    r_radio: {say: 'So small. It does not look like it could call anything. ...Tull will be pleased. I am less pleased, and I do not know why. Here, for your trouble.', opts: [T('Goodbye.', 'hub', {act: G => G.addCaps(120)})]},
    trade: {say: 'Ira trades for the camp. Furs, meat, the good mushrooms. She is the one by the racks, laughing at something. She is always laughing at something.', opts: [T('Thank you.', 'hub')]},
  }},
  tull: {name: 'Ember-Speaker Tull', nodes: {
    hub: {say: G => G.flags.bm_end === 'radio' ? 'The voice is silenced. The fire will be quiet now. You did well, outsider. Better than our hunters.'
        : G.flags.bm_end === 'log' ? 'You brought the old man\'s scribbles to the Elder and she believes them. She is old too. Go away.'
        : 'Outsider. You stand close to the Ember Mother. Stand further.',
      opts: [
        T('Why do you hate the man in the tower?', 'tower', {if: G => !G.flags.bm_end}),
        T('What does the fire say?', 'fire'),
        T('Fires don\'t start on the wet side of a camp in spring. Somebody lit them.', 'accuse', {check: ['intellect', 7], if: G => G.flags.bm_hint && !G.flags.bm_end}),
        T('Goodbye.')]},
    tower: {say: 'He sits above us. He watches us. He fires red stars and the fire comes. Before he came the fire was ours, and it spoke through me. Now it listens to him. Bring me his voice-box and the fire will be ours again.',
      opts: [T('I\'ll see what I find.', 'hub')]},
    fire: {say: G => G.flags.bm_end === 'tull' ? 'It says nothing to me any more.' : 'It says the camp must stay apart. It says outsiders bring the burning. It says... it says many things, and it says them to me.', opts: [T('Convenient.', 'hub')]},
    accuse: {say: '...You have been listening to the old man. Leave this camp before I decide what the fire says about you.',
      opts: [T('I\'ll be back with proof.', 'hub'), T('You did it so they\'d need you. Leave quietly and nobody has to see the rags.', 'leave', {check: ['charm', 8], if: G => G.has('tull_flint')})]},
    leave: {say: 'You would... Hm. Better to be a living Speaker somewhere else than a dead liar here. Keep your rags. Tell Saba the fire sent me walking.',
      opts: [T('Go.', null, {act: G => { G.setFlag('tullGone', 1); G.karma(3, 'Let Tull walk away'); G.msg('Tull pulls his hood up and walks out through the gate without looking back.'); }})]},
  }},
  ira: {name: 'Ira', nodes: {
    hub: {say: G => G.flags.met_ira ? 'You came back! Want to trade or want to hear about the boar that nearly ate me?' : 'Ha! An outsider who looks at the racks instead of the spears. I\'m Ira. I trade for the camp, because I\'m the only one who can count past "many".',
      opts: [
        T('Let\'s trade.', null, {act: G => { G.setFlag('met_ira', 1); G.openTrade('ira'); }}),
        T('The boar that nearly ate you?', 'boar', {act: G => G.setFlag('met_ira', 1)}),
        T('What do you think of Tull?', 'tull', {act: G => G.setFlag('met_ira', 1)}),
        {t: 'Goodbye.', act: G => G.setFlag('met_ira', 1)}]},
    boar: {say: 'Big as a wagon! Well, a small wagon. A wheelbarrow. It came out of the ferns and I went up a tree so fast I left my boots on the ground. It ate one boot. I traded the other to Pike as "boar-tested".', opts: [T('Ha.', 'hub')]},
    tull: {say: 'He was nice, when we were small. Then he got the ochre and started hearing things. He goes out to the east side at night a lot. Says he\'s praying. I followed him once. He wasn\'t praying, he was digging.',
      opts: [T('Digging where?', 'dig'), T('Interesting.', 'hub')]},
    dig: {say: 'Under the Ember Mother. That\'s not allowed. I didn\'t tell anyone, because who would believe me over the Speaker? Maybe they\'d believe you.', opts: [T('Maybe.', 'hub', {act: G => G.setFlag('bm_hint', 1)})]},
  }},
  ab_guard1: {name: 'Ashborn Warden', nodes: {
    hub: {say: G => G.flags.bm_end === 'log' || G.flags.bm_end === 'tull' ? 'Friend of the fire. Pass.' : 'Walk slowly. Keep your hands where the fire can see them.', opts: [T('All right.')]},
  }},
  ab_guard2: {name: 'Ashborn Warden', nodes: {
    hub: {say: 'Outsiders trade with Ira. Outsiders speak with the Elder. Outsiders do not touch the Ember Mother.', opts: [T('Understood.')]},
  }},
  // ---------------------------------------------------------------- the drive-in
  marquee: {name: 'Marquee', nodes: {
    hub: {say: G => G.flags.rk_deal === 'toll' ? 'My favourite customer. The road\'s open, the chits come in, and nobody has to watch the second feature.'
        : 'Welcome, welcome, to the Sunset Drive-In! Tonight\'s feature, same as every night: nothing. Tickets are free. Leaving costs. I\'m Marquee, and these are the Reel Kings. What brings you to the pictures?',
      opts: [
        T('Cinder Gap\'s caravans. You took them.', 'caravans', {if: G => G.questActive('mercy_road') && G.qStage('mercy_road') === 1}),
        T('Why the drive-in?', 'why'),
        T('Dex Reyes runs with you.', 'dex', {if: G => G.questActive('last_call') && !G.flags.dexHome}),
        T('Goodbye.')]},
    why: {say: 'Because once upon a time a thousand people sat right here, in the dark, all looking the same way, and nobody shot anybody. I find that inspiring. Also, the screen makes a hell of a wall.', opts: [T('Poetic.', 'hub')]},
    caravans: {say: 'Took? We taxed. Two trains, fair and square: the screen tax, payable in mules. The third paid in chits and went on its merry way to Mercy, which is its own funeral. Anyway. You want the road open? Everything\'s got a price.',
      opts: [
        T('Name it.', 'price'),
        T('Here\'s my price: you pack up and leave the valley, today.', 'scare', {check: ['might', 7]}),
        T('A dead road pays you nothing. Take a cut from the Gap instead: steady money, no shooting.', 'toll', {check: ['charm', 6]}),
        T('The price is you.', 'fight')]},
    price: {say: 'Three hundred chits now, and the Gap pays the screen tax every season after. Small, civilised, regular. Like a subscription.',
      opts: [
        T('Here. Three hundred.', 'paid', {if: G => G.P.caps >= 300, act: G => { G.addCaps(-300); G.setFlag('rk_deal', 'toll'); G.rep('cinder', -1); G.give('screen_ticket', 1); }}),
        T('Too rich for me.', 'caravans')]},
    toll: {say: '...Steady money. No shooting. You know, I\'ve been waiting for someone to say something sensible to me for six years. All right. Tell Odile the Kings will take a toll, a small one, and anything going to Mercy is waved through. Have a ticket.',
      opts: [T('Pleasure doing business.', 'hub', {act: G => { G.setFlag('rk_deal', 'toll'); G.give('screen_ticket', 1); G.addXp(60); }})]},
    paid: {say: 'Lovely. Road\'s open. Enjoy the show.', opts: [T('There isn\'t a show.', 'hub')]},
    scare: {say: 'Leave the... ha. Ha. You mean it. You\'ve got the eyes. All right, all right. Kings! Pack the projector. We\'re touring. Somewhere with fewer heroes.',
      opts: [T('Good choice.', null, {act: G => { G.setFlag('rk_deal', 'gone'); G.setFlag('rkGone', 1); G.addXp(80); G.msg('The Reel Kings load what they own onto two carts and roll off south, Marquee waving from the back.'); }})]},
    fight: {say: 'Ah. A critic. Kings! House lights!',
      opts: [T('[Draw]', null, {act: G => { G.setFlag('rk_war', 1); G.makeHostile('rk0'); G.fight('marquee'); }})]},
    dex: {say: 'The kid? He\'s got heart and no aim. I like him. He\'s by the snack bar, pretending he isn\'t homesick. Go on, talk to him. If he wants to go, he goes. The Kings aren\'t a prison. We\'re a cinema.', opts: [T('Thanks.', 'hub')]},
  }},
  dex: {name: 'Dex Reyes', nodes: {
    hub: {say: 'You\'re not a King. Did Juno send you? She did. She always sends somebody.',
      opts: [
        T('She wants you home.', 'home', {if: G => G.questActive('last_call')}),
        T('Why\'d you join the Kings?', 'why'),
        T('Goodbye.')]},
    why: {say: 'Because Marquee says I\'m going places. In Cinder Gap all I\'m going is from the bar to the well and back. Here, at least, there\'s... I dunno. Jackets.', opts: [T('Jackets.', 'hub')]},
    home: {say: 'And do what, wash glasses? No. I\'m a King now. ...What did she say? Exactly?',
      opts: [
        T('That your mother\'s ring is behind the bar, and you have to come and get it yourself.', 'ring', {if: G => G.flags.dex_ring}),
        T('That the Kings are about to get cleared out, and she\'d like to bury you old, not this week.', 'scared', {check: ['charm', 6]}),
        T('You\'re coming home. Walk or be carried.', 'drag', {check: ['might', 6]}),
        T('Never mind.', 'hub')]},
    ring: {say: '...She kept it. She said she\'d sell it if I ever left. She kept it. ...Okay. Okay. Tell Marquee I said thanks for the jacket. I\'m keeping the jacket.',
      opts: [T('Go on home, Dex.', null, {act: G => { G.setFlag('dexHome', 1); G.addXp(60); G.msg('Dex shrugs his jacket straight and sets off up the road to Cinder Gap.'); }})]},
    scared: {say: 'Cleared... by you? Yeah. Yeah, you look like the clearing type. I\'m going. I\'m going! Tell Juno I was always going to.',
      opts: [T('Sure you were.', null, {act: G => { G.setFlag('dexHome', 1); G.addXp(40); }})]},
    drag: {say: 'Ow! All right! I\'m walking! You\'re worse than she is.', opts: [T('Move.', null, {act: G => { G.setFlag('dexHome', 1); G.addXp(30); }})]},
  }},
  cg_folk1: {name: 'Cinder Gap Settler', nodes: {hub: {say: G => ['Water\'s on at the tower after noon. Bring your own bucket.', 'You came over the pass? My uncle tried that once. Came back with no shoes and a lot of opinions.', 'Don\'t let Pike sell you the "boar-tested" boots.'][G.P.level % 3], opts: [T('Thanks.')]}}},
  cg_folk2: {name: 'Cinder Gap Settler', nodes: {hub: {say: G => G.questDone('mercy_road') ? 'Wagons are moving again. Feels like the whole town took a breath.' : 'Three caravans gone. My sister drove the second one.', opts: [T('I\'m sorry.')]}}},
  cg_folk3: {name: 'Cinder Gap Settler', nodes: {hub: {say: 'Abe fixed my rifle with a spoon. I don\'t know how. I don\'t want to know how.', opts: [T('Ha.')]}}},
  ab_folk1: {name: 'Ashborn', nodes: {hub: {say: G => G.flags.bm_end === 'tull' ? 'They say the Speaker lied to us. I knew his eyes were wrong.' : 'The fire is fed. The camp is safe. Go and speak to the Elder.', opts: [T('All right.')]}}},
  ab_folk2: {name: 'Ashborn', nodes: {hub: {say: 'Outsider. Your boots are loud. The forest hears you coming a mile off.', opts: [T('I\'ll work on it.')]}}},
};

// where the quests happen: the caravan wreck, the hospital pharmacy, Crane's radio, Tull's hollow
export const POINTS = {
  mr_wreck: {label: pt => G.questActive('mercy_road') && !G.has('caravan_log') ? 'Search the overturned wagon' : null,
    use: pt => { G.give('caravan_log', 1); G.give('ammo_rifle', 10); G.msg('A drover\'s trail book, wrapped in oilcloth under the seat. The last pages are in a hurry.'); checkQuests(); }},
  mf_pharmacy: {label: pt => (G.questActive('mercy_ledger') && !G.has('mercy_meds')) || !G.flags.mf_shelves ? 'Search the pharmacy shelves' : null,
    use: pt => { if (!G.flags.mf_shelves) { G.setFlag('mf_shelves', 1); G.give('stimpak', 2); G.give('radaway', 2); G.give('mercy_ledger', 1); }
      if (G.questActive('mercy_ledger') && !G.has('mercy_meds')) { G.give('mercy_meds', 1); G.msg('Behind the steel cage, a sealed case stencilled ANTIBIOTICS - DO NOT FREEZE.'); }
      else G.msg('Stimpaks, RadAway, and the pharmacy\'s stock book.'); checkQuests(); }},
  bm_radio: {label: pt => G.questActive('burning_man') && G.flags.bm_met && !G.has('crane_radio') && !G.flags.bm_end && !G.flags.craneRobbed ? 'Steal the fire-watch radio' : null,
    use: pt => { G.give('crane_radio', 1); G.setFlag('craneRobbed', 1); G.karma(-5, 'Stole Ellis Crane\'s radio'); G.msg('You lift the radio off its hook. The crank is still warm.'); checkQuests(); }},
  bm_cache: {label: pt => G.questActive('burning_man') && G.flags.bm_hint && !G.has('tull_flint') && !G.flags.bm_end ? 'Dig under the burnt pine' : null,
    use: pt => { G.give('tull_flint', 1); G.msg('Under a flat stone in the roots: oil-soaked rags, a striker, and a pouch of red ochre.'); checkQuests(); }},
};
export const WORLD_POINTS = [
  {id: 'mr_wreck', x: 993, z: 166, r: 3.0},
  {id: 'mf_pharmacy', x: 1126.5, z: 320.5, r: 2.4},
  {id: 'bm_radio', x: 980.6, z: -240.0, r: 2.4},
  {id: 'bm_cache', x: 1331.5, z: -335.5, r: 2.6},
];
// who lives out there: the Kings at the drive-in (they leave you alone unless you start something), ghouls and
// glowing ones in the hospital, a few things in the forest
const E = (id, type, x, z, extra = {}) => Object.assign({id, type, x, z, always: true}, extra);
export const SPAWNS = [
  E('rk0', 'raider', 684, 238, {name: 'Reel King', neutral: true, group: 'rk', unless: 'rkGone'}),
  E('rk1', 'raider', 696, 240, {name: 'Reel King', neutral: true, group: 'rk', unless: 'rkGone'}),
  E('rk2', 'marauder', 702, 228, {name: 'Reel King', neutral: true, group: 'rk', unless: 'rkGone'}),
  E('rk3', 'raider', 688, 224, {name: 'Reel King', neutral: true, group: 'rk', unless: 'rkGone'}),
  E('rk4', 'sniper', 708, 242, {name: 'Reel King Lookout', neutral: true, group: 'rk', unless: 'rkGone'}),
  E('mf0', 'ghoul', 1128, 309, {group: 'mf'}), E('mf1', 'ghoul', 1137, 311, {group: 'mf'}), E('mf2', 'glowhusk', 1131, 318, {group: 'mf'}),
  E('mf3', 'ghoul', 1100, 304, {group: 'mf'}), E('mf4', 'ghoul', 1150, 293, {group: 'mf'}), E('mf5', 'glowhusk', 1140, 318, {name: 'Matron', group: 'mf'}),
  E('aw0', 'boar', 1060, -120), E('aw1', 'boar', 1066, -112), E('aw2', 'stalker', 1180, -60), E('aw3', 'hound', 940, -300), E('aw4', 'hound', 946, -306),
  E('aw5', 'radscorp', 1240, 120), E('aw6', 'jackal', 760, 140), E('aw7', 'jackal', 768, 146), E('aw8', 'vulture', 1000, 60), E('aw9', 'tusker', 1210, -200),
];
// the caravan wreck on the Mercy road
export const PROPS = [
  {kind: 'wagon_burnt', x: 995, z: 163.5, rot: 0.8},
];
export const TRIGGERS = [
  {if: G => G.visited('cinder_gap') && !G.flags.cg_hello, do: G => { G.setFlag('cg_hello', 1); G.setFlag('radio', 'crane_watch'); G.msg('Cinder Gap. The mayor\'s office is the board building with TOWN HALL on it.'); }},
  {if: G => G.flags.rk_deal === 'gone' && G.questActive('last_call') && !G.flags.dexHome && !G.flags.dexLeft, do: G => { G.setFlag('dexLeft', 1); G.setFlag('dexHome', 1); G.msg('Dex didn\'t go south with the Kings. Word is he turned up at the Ember Room.'); }},
  {if: G => G.flags.tullTurns && G.flags.npcDead_tull && !G.flags.tullGone, do: G => G.setFlag('tullGone', 1)},
];
export const RADIO = {
  crane_watch: {h: 'LONGWAVE: ASHWOOD FIRE WATCH', who: 'crane', t: `> CRANE, E. — TOWER SEVEN — ASHWOOD DISTRICT

Fire watch, evening report. Wind west-north-west, light. Humidity good. No smoke on any bearing.

Visibility to the Kettle is fine. Visibility to the Ashborn camp is fine. Somebody down there has a cookfire going with too much green wood in it; I can smell it from here.

The forest is asleep. I'm not. This is Tower Seven, signing off, same time tomorrow, same as always.

> END`},
};
export const EPILOGUE = [
  {if: G => G.flags.mr_end === 'told' && G.flags.odileStays, t: 'Odile Brandt stayed mayor of Cinder Gap. Every season she reads the town chest out loud in the Ember Room, to the last chit, and nobody has ever asked her to stop.'},
  {if: G => G.flags.mr_end === 'told' && !G.flags.odileStays, t: 'Odile Brandt stood down, and Pike ran Cinder Gap for two years, badly. When they asked her back, she said yes on the condition that Pike sweep the street. He did. Badly.'},
  {if: G => G.flags.mr_end === 'kept', t: 'Cinder Gap never learned who sent the last caravan to Mercy. Odile Brandt built a clinic with her own savings the next year, and never said why.'},
  {if: G => G.flags.rk_deal === 'toll', t: 'The Reel Kings took their screen tax every season, and Marquee started showing shadow plays on the old screen on summer nights. People came from as far as the Kettle to watch.'},
  {if: G => G.flags.rk_deal === 'gone', t: 'The Reel Kings rolled south and were never seen in the Ashwood again. Somebody painted THE END across the drive-in screen. Nobody admits to it.'},
  {if: G => G.flags.rk_war, t: 'The Sunset Drive-In stood empty after the shooting. Its screen still catches the last light every evening, showing nothing, to nobody.'},
  {if: G => G.flags.bm_end === 'log', t: 'Elder Saba walked up the hill to the fire tower with meat and an apology. Ellis Crane still reads the weather into the dark, but now, when he says "visibility to the Ashborn camp is fine", somebody down there waves.'},
  {if: G => G.flags.bm_end === 'tull', t: 'The Ashborn chose a new Ember-Speaker by lot, which Elder Saba said was what the fire would have wanted. No fire has come for the camp since.'},
  {if: G => G.flags.bm_end === 'radio', t: 'Tower Seven fell silent. The next summer a fire started east of the Ashborn camp, upwind, in the spring rain, and there was nobody on the hill to fire a warning.'},
  {if: G => G.flags.ml_end === 'sorrel', t: 'Doc Sorrel\'s three fevers all walked out of the clinic. She kept the empty antibiotics case on a shelf, and showed it to anyone who said the old world had nothing left to give.'},
  {if: G => G.flags.ml_end === 'pike', t: 'Pike sold the Mercy antibiotics one tablet at a time. Doc Sorrel never spoke to him again, and treated him last, every time, for the rest of his life.'},
  {if: G => G.questDone('last_call') && !G.flags.npcDead_dex, t: 'Dex Reyes took over the Ember Room when Juno married a caravan guard from the Kettle. He still wears the Kings\' jacket behind the bar.'},
];
