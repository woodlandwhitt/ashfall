// Build 21 story layer: quests for build 20's three new places.
//
// The Toll Road: Hob Kettering, a hauler camped on the north-east highway, wants Wayside 9's tollmen gone so the road
// runs again. Holloway Ground: Ada Holloway keeps watch over her family's burnt farm from its gate and can't go down while
// the dead walk the fields. Dead Air: Relay Station K's sentries still keep a post nobody manned for seventy years; put
// them down and the relay can talk again, and Meridian Free Radio gets a second mast.

const F = (body, skin, hat = null, coat = null, bulk = 1) => ({fem: true, body, skin, hat, coat, bulk});
const M = (body, skin, hat = null, coat = null, bulk = 1) => ({fem: false, body, skin, hat, coat, bulk});
const N = (id, name, x, z, rot, look, extra = {}) => Object.assign({id, name, x, z, rot, wander: null, scale: 1, look}, extra);
const T = (t, go, extra = {}) => Object.assign(go ? {t, go} : {t}, extra);

export const NPCS = [
  N('hob', 'Hob Kettering', 872.0, -684.0, 0.4, M('#4a3a2a', '#c89a78', 'cap', '#5a3a22', 1.2)),
  N('ada', 'Ada Holloway', -296.5, -567.0, 3.0, F('#3a4a2a', '#d8a07a', null, '#4a3a2a', 0.95)),
];
export const NPC_FACTION = {};

export const QUESTS = {
  toll_road: {t: 'The Toll Road',
    desc: 'Hob Kettering hauls salt and scrap between the Kettle road towns. Raiders have made the Wayside 9 fuel stop a toll post on the north-east highway, and Hob hasn\'t paid.',
    stages: [
      {txt: 'Clear the tollmen out of Wayside 9.', at: 'wayside', done: G => G.allDead('ws', 4)},
      {txt: 'Tell Hob the road is open.', at: 'wayside'}],
    reward: {xp: 260, caps: 120}},
  holloway_ground: {t: 'Holloway Ground',
    desc: 'Ada Holloway grew up on the farm west of Northgate. The house burnt, her people are buried by the barn, and the dead walk the fields now.',
    stages: [
      {txt: 'Put down what walks Holloway Farm\'s fields.', at: 'holloway', done: G => G.allDead('hf', 4)},
      {txt: 'Find the Holloway graves behind the barn and see they\'re whole.', at: 'holloway', done: G => !!G.flags.hf_graves},
      {txt: 'Go back to Ada at the farm gate.', at: 'holloway'}],
    reward: {xp: 240, caps: 60}},
  dead_air: {t: 'Dead Air',
    desc: 'Relay Station K, a signals post on a rise in the Ashwood, is still guarded by its sentry robots. Its mast still stands.',
    stages: [
      {txt: 'Deal with the relay\'s sentries.', at: 'relay_k', done: G => G.allDead('rk', 2)},
      {txt: 'Bring the relay console back to life.', at: 'relay_k', done: G => !!G.flags.relay_on},
      {txt: 'Listen to Meridian Free Radio.', at: 'relay_k', done: G => !!G.flags.relay_heard, auto: true}],
    reward: {xp: 300}},
};
export const QUEST_REP = {};

export const DIALOGUE = {
  hob: {name: 'Hob Kettering', nodes: {
    hub: {say: G => G.questDone('toll_road') ? 'Road\'s open, and the salt\'s moving. Every hauler on the Kettle road owes you a drink. I\'m collecting them for you.'
        : G.questActive('toll_road') && G.allDead('ws', 4) ? 'No smoke over Wayside this morning. That you?'
        : G.questActive('toll_road') ? 'Wayside\'s that way, up the highway. Four of them, last I counted, and one with a long rifle up on the service shed.'
        : 'Don\'t mind the truck. She\'s dry. Every drop of fuel between here and the Kettle road is sitting in Wayside 9\'s tanks, and the fellas sitting on it want fifty caps a wheel.',
      opts: [
        T('Who runs Wayside 9?', 'who', {if: G => !G.questKnown('toll_road')}),
        T('It\'s done. Wayside\'s clear.', 'done', {if: G => G.questActive('toll_road') && G.allDead('ws', 4)}),
        T('Safe roads.')]},
    who: {say: 'Tollmen. They took the old fuel stop when the owners died and they\'ve been charging since. Their boss carries a sledge and calls himself the Toll Boss, like it\'s a title. Clear them out and the road runs again, and I\'ll pay what I\'d have paid them. More.',
      opts: [T('I\'ll clear the road.', 'hub', {act: G => G.start('toll_road')}), T('Not my fight.', 'hub')]},
    done: {say: 'Ha! Then she rolls tonight. Here: a hundred and twenty, and the spare jerry can I was saving for my own funeral. Stop by any Kettle road stall and say Hob sent you.',
      opts: [T('Drive safe.', 'hub', {act: G => { G.give('fuel_can', 1); G.complete('toll_road'); }})]},
  }},
  ada: {name: 'Ada Holloway', nodes: {
    hub: {say: G => G.questDone('holloway_ground') ? 'I went down this morning and sat with them. First time in six years. Thank you.'
        : G.questActive('holloway_ground') && G.allDead('hf', 4) && G.flags.hf_graves ? 'You\'re back. Are they... is it quiet down there?'
        : G.questActive('holloway_ground') ? 'Down the slope, past the fence. Mind the barn, they sleep in the shade.'
        : 'That\'s Holloway Farm down there. Was. Eggs, milk, honey, and no trespassers, my father\'s sign says. He\'d have a word for what\'s walking his fields now.',
      opts: [
        T('What happened to the farm?', 'what', {if: G => !G.questKnown('holloway_ground')}),
        T('The fields are clear, and the graves are whole.', 'done', {if: G => G.questActive('holloway_ground') && G.allDead('hf', 4) && !!G.flags.hf_graves}),
        T('Take care, Ada.')]},
    what: {say: 'Fever came up from the river six years back. Took my mother and my brothers. Father buried them by the barn and then burnt the house with himself in it. Something got into the graves after. I watch from up here. I can\'t go down. Not while they walk.',
      opts: [T('I\'ll clear the fields and look at the graves.', 'hub', {act: G => G.start('holloway_ground')}), T('I\'m sorry.', 'hub')]},
    done: {say: 'Then I can bury them again. Properly. Take this. It was my father\'s. He\'d want it fired at something that deserves it.',
      opts: [T('Thank you.', 'hub', {act: G => { G.give('stimpak', 2); G.give('ammo_44', 24); G.complete('holloway_ground'); }})]},
  }},
};

export const POINTS = {
  hf_graves: {label: pt => G.questActive('holloway_ground') && !G.flags.hf_graves ? 'Look at the Holloway graves' : null,
    use: pt => { G.setFlag('hf_graves', 1); G.addXp(40); G.msg('Three graves and a fourth, newer, with no name on it. The earth on two has been dug at from below. You push it back and tamp it down with your boot.'); checkQuests(); }},
  rk_console: {label: pt => G.flags.relay_on ? null : G.questActive('dead_air') && G.allDead('rk', 2) ? (G.stat('intellect') >= 6 || G.count('circuit') >= 1 ? 'Bring the relay console back up' : 'A dead relay console (Intellect 6 or a circuit board)') : null,
    use: pt => {
      if (G.stat('intellect') < 6 && G.count('circuit') < 1) { G.msg('The console\'s board is cooked. You\'d need to know your way round one, or have parts to swap in.'); return; }
      if (G.stat('intellect') < 6) G.take('circuit', 1);
      G.setFlag('relay_on', 1); G.setFlag('radio', 'relay_k'); G.addXp(80);
      G.msg('The relay hums, then sings. Somewhere out on the mast a light comes on, and the console prints: LINK UP. MERIDIAN FREE RADIO. CARRIER ACCEPTED.'); checkQuests(); }},
};
export const WORLD_POINTS = [
  {id: 'hf_graves', x: -284.0, z: -597.0, r: 2.6},
  {id: 'rk_console', x: 1000.0, z: 100.0, r: 2.8},
];

export const TRIGGERS = [
  {if: G => G.visited('relay_k') && !G.questKnown('dead_air'), do: G => G.start('dead_air')},
  {if: G => G.questActive('dead_air') && !!G.flags.relay_on && G.flags.radio !== 'relay_k' && !G.flags.relay_heard, do: G => G.setFlag('relay_heard', 1)},
];

export const RADIO = {
  relay_k: {h: 'MERIDIAN FREE RADIO — RELAY K', who: 'radio', t: `> MERIDIAN FREE RADIO, NOW ON TWO MASTS

Well, would you listen to that. This is Meridian Free Radio, and for the first time since anyone can remember, we're coming to you from two places at once.

Somebody walked into Relay Station K in the Ashwood, said something firm to its robots, and switched the old link back on. Whoever you are: thank you. The north can hear us clear now, and so can the haulers on the north-east highway.

> END`},
};

export const EPILOGUE = [
  {if: G => G.questDone('toll_road'), t: 'Hob Kettering\'s truck ran the north-east highway for eleven more years. Wayside 9 sold fuel again, honestly, under a sign that read HOB SENT YOU.'},
  {if: G => G.questDone('holloway_ground'), t: 'Ada Holloway went down to the farm and stayed. The barn got a roof, the fields got a crop, and the graves got a fence that nothing ever dug under again.'},
  {if: G => G.questDone('dead_air'), t: 'Relay Station K carried Meridian Free Radio across the north for as long as the mast stood, and its sentries, deactivated, were painted bright blue and kept as the station\'s mascots.'},
];
