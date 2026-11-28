// Build 25 story layer: houses for sale (scripts/homes.gd does the houses themselves).
//
// Squatters' Rights: Mags Tinley holds the key to the Tinsmith's Shack at the east end of Cinder Gap, but scuttlers
// have nested under its floor since the tinsmith died. Clear them and she'll knock a quarter off. A Roof Over Your
// Head: Row House Nine on Lantern Row lost half its roof in the spring storms; Orla Penn will sell it for a song to
// whoever helps her patch it. The Lockwood Deed: old Silas Lockwood drowned with his boat and his deed; Deacon Hale,
// the harbourmaster's clerk, can't sell the Lockwood Place without it. Find the lockbox and the house is yours for a
// filing fee. Housewarming: once you own a house, make it a home.

const F = (body, skin, hat = null, coat = null, bulk = 1) => ({fem: true, body, skin, hat, coat, bulk});
const M = (body, skin, hat = null, coat = null, bulk = 1) => ({fem: false, body, skin, hat, coat, bulk});
const N = (id, name, x, z, rot, look, extra = {}) => Object.assign({id, name, x, z, rot, wander: null, scale: 1, look}, extra);
const T = (t, go, extra = {}) => Object.assign(go ? {t, go} : {t}, extra);
const E = (id, type, x, z, extra = {}) => Object.assign({id, type, x, z, always: true}, extra);

export const NPCS = [
  N('mags_t', 'Mags Tinley', 849.6, -46.4, 3.4, F('#5a4a3a', '#c89070', 'cap', '#3a3a3a', 1.05)),
  N('orla', 'Orla Penn', 627.0, 127.6, 0.3, F('#4a5a6a', '#8a5a3a', null, '#5a4a3a', 0.95)),
  N('deacon', 'Deacon Hale', -16.6, -749.0, -1.4, M('#2a2a2a', '#e0b090', 'wide', '#3a3226', 1.0)),
];
export const NPC_FACTION = {mags_t: 'cinder', orla: 'lamplight', deacon: 'stillwater'};

export const ITEMS = {
  lockwood_deed: {n: 'The Lockwood Deed', t: 'quest', w: 0.1, v: 0, desc: 'A deed to the Lockwood Place, Stillwater, sealed in oilcloth inside a tin lockbox. Still legible. Silas Lockwood signed it in a careful, square hand.'},
  house_key: {n: 'House Key', t: 'junk', w: 0, v: 0, desc: 'A key on a loop of wire. It opens a door that is yours.'},
};

export const SPAWNS = [
  E('sq0', 'scuttler', 845.0, -55.0, {onStart: 'squatters_rights', name: 'Floor Scuttler'}),
  E('sq1', 'scuttler', 848.0, -51.5, {onStart: 'squatters_rights', name: 'Floor Scuttler'}),
  E('sq2', 'scuttler', 843.5, -50.5, {onStart: 'squatters_rights', name: 'Scuttler Broodmother'}),
];

export const QUESTS = {
  squatters_rights: {t: 'Squatters\' Rights',
    desc: 'Mags Tinley has the key to the Tinsmith\'s Shack at the east end of Cinder Gap. Scuttlers have nested under its floorboards since old Abner died, and nobody will buy it with them in it.',
    stages: [
      {txt: 'Clear the scuttlers out of the Tinsmith\'s Shack.', at: 'cinder_gap', done: G => G.allDead('sq', 3)},
      {txt: 'Tell Mags Tinley the shack is clear.', at: 'cinder_gap'}],
    reward: {xp: 150}},
  roof_over_head: {t: 'A Roof Over Your Head',
    desc: 'Row House Nine on Lantern Row lost half its roof to the spring storms. Orla Penn, who keeps the Row\'s empty houses, will let it go cheap to anyone who helps her put a roof back on it.',
    stages: [
      {txt: 'Look at the damage to Row House Nine.', at: 'lantern_row', done: G => !!G.flags.rh_looked},
      {txt: 'Bring Orla 6 scrap metal and 2 rolls of duct tape.', at: 'lantern_row', done: G => !!G.flags.rh_patched, auto: true}],
    reward: {xp: 140}},
  lockwood_deed: {t: 'The Lockwood Deed',
    desc: 'Silas Lockwood drowned when his boat went down off Stillwater, and his deed went with him. Deacon Hale can\'t sell the Lockwood Place without it. Silas kept his papers in a lockbox under the boathouse floor, the boatmen say.',
    stages: [
      {txt: 'Find Silas Lockwood\'s lockbox at the boathouse.', at: 'stillwater', done: G => G.has('lockwood_deed')},
      {txt: 'Take the deed to Deacon Hale.', at: 'stillwater'}],
    reward: {xp: 180}},
  housewarming: {t: 'Housewarming',
    desc: 'A house is four walls and a roof. A home is something else. Make it yours.',
    stages: [
      {txt: 'Furnish your home: three pieces of your own choosing (the ledger by the door).', done: G => G.homeFurnished() >= 3},
      {txt: 'Put in companion bunks and ask a companion to live with you.', done: G => G.homeResidents() >= 1},
      {txt: 'Sleep a night in your own bed.', done: G => !!G.flags.home_slept, auto: true}],
    reward: {xp: 250, caps: 100}},
};
export const QUEST_REP = {squatters_rights: {cinder: 1}, roof_over_head: {lamplight: 1}, lockwood_deed: {stillwater: 1}};

// what each seller says about the price (the house, the quote, a haggle), the same for all three. The functions are
// written out with the house's id in them (eval at build time): the story's functions can't see this file's variables
const fn = src => eval(src);
const sale = (home) => ({
  price: {say: fn(`G => G.homeRefused('${home}') ? "I'm sorry. The town won't have it. Not to you, not after what you've done here."
      : 'For you: ' + G.homeQuote('${home}') + ". That's the house as it stands: a roof, four walls, a cot and a footlocker. Make it what you like after."`),
    opts: [
      T(fn(`G => "I'll take it. (" + G.homePrice('${home}') + ' caps)'`), 'sold', {if: fn(`G => !G.homeRefused('${home}') && G.caps >= G.homePrice('${home}')`), act: fn(`G => G.buyHome('${home}')`)}),
      T('Could you do any better on the price?', 'haggle', {if: fn(`G => !G.homeRefused('${home}') && !G.flags.haggle_${home} && !G.flags.haggled_${home}`), check: ['charm', 6]}),
      T('Not yet. I\'ll be back.', 'hub')]},
  haggle: {say: 'You\'ve got a way about you, you know that? Fine. I\'ll take a tenth off and tell myself it was my idea.',
    opts: [T('Thank you.', 'price', {act: fn(`G => G.setFlag('haggle_${home}', 1)`)})]},
  sold: {say: 'Then it\'s yours. Here\'s the key. The ledger by the door has the names of people in town who\'ll fit the place out for you, and what they charge. Welcome home.',
    opts: [T('Thank you.', 'hub', {act: G => G.give('house_key', 1)})]},
});

export const DIALOGUE = {
  mags_t: {name: 'Mags Tinley', nodes: Object.assign({
    hub: {say: G => G.ownsHome('cinder') ? 'How\'s the old shack? Abner would\'ve liked somebody living in it again. He hated the quiet.'
        : G.questActive('squatters_rights') && G.allDead('sq', 3) ? 'It\'s gone quiet in there. Did you... all of them? Even the big one?'
        : G.questActive('squatters_rights') ? 'They\'re under the floor. Mind the big one; she\'s been laying.'
        : 'That shack behind me was Abner Tinley\'s. My uncle. Forty years of pots and pans and kettles out of it. It\'s for sale, if you\'re looking for somewhere to put your boots up.',
      opts: [
        T('Tell me about the shack.', 'about', {if: G => !G.ownsHome('cinder')}),
        T('The scuttlers are dead. All of them.', 'sq_done', {if: G => G.questActive('squatters_rights') && G.allDead('sq', 3)}),
        T('What would it cost me?', 'price', {if: G => !G.ownsHome('cinder')}),
        T('Take care, Mags.')]},
    about: {say: 'Tin roof, two windows, a stove flue, a good dry floor. Only problem: scuttlers got in under the boards after Abner passed and laid a nest. Nobody\'ll buy it with them in it, and I\'m not going in there. Clear them out and I\'ll knock a quarter off, gladly.',
      opts: [T('I\'ll clear them out.', 'hub', {if: G => !G.questKnown('squatters_rights'), act: G => G.start('squatters_rights')}), T('What would it cost me as it is?', 'price'), T('I\'ll think about it.', 'hub')]},
    sq_done: {say: 'Bless you. I\'ll air it out and burn some sage. A quarter off, like I said, and the town owes you one besides.',
      opts: [T('Glad to help.', 'hub', {act: G => G.complete('squatters_rights')})]},
  }, sale('cinder'))},
  orla: {name: 'Orla Penn', nodes: Object.assign({
    hub: {say: G => G.ownsHome('lantern') ? 'Keeping the rain out? Good. That patch will outlast the both of us.'
        : G.questDone('roof_over_head') ? 'There she is, roof and all. Still yours for the asking, at the price I promised.'
        : G.questActive('roof_over_head') && G.flags.rh_looked ? 'Bad, isn\'t it? Bring me the scrap and the tape and we\'ll have her dry by nightfall.'
        : 'Row House Nine, that one. Lost half its roof to the spring storms and nobody\'s lived there since. I keep the Row\'s empty houses. It\'s for sale, if you don\'t mind a draught.',
      opts: [
        T('What happened to the roof?', 'about', {if: G => !G.questKnown('roof_over_head') && !G.ownsHome('lantern')}),
        T('Here\'s the scrap and the tape.', 'rh_give', {if: G => G.questActive('roof_over_head') && !!G.flags.rh_looked && !G.flags.rh_patched && G.count('scrap_metal') >= 6 && G.count('duct_tape') >= 2}),
        T('What would it cost me?', 'price', {if: G => !G.ownsHome('lantern')}),
        T('See you, Orla.')]},
    about: {say: 'Storm took the back sheets clean off and dropped them in the Lantern\'s yard. The rafters are sound. It wants six good sheets of scrap and some tape to seal the seams, and somebody to hold the ladder. Help me and I\'ll let it go for less than the tin\'s worth.',
      opts: [T('I\'ll help you patch it.', 'hub', {act: G => G.start('roof_over_head')}), T('What would it cost me as it is?', 'price'), T('Maybe later.', 'hub')]},
    rh_give: {say: 'That\'ll do it. Hold the ladder. ... There. Hear that? That\'s the wind going round the house instead of through it.',
      opts: [T('Good as new.', 'hub', {act: G => { G.take('scrap_metal', 6); G.take('duct_tape', 2); G.setFlag('rh_patched', 1); G.addXp(40); checkQuests(); }})]},
  }, sale('lantern'))},
  deacon: {name: 'Deacon Hale', nodes: Object.assign({
    hub: {say: G => G.ownsHome('stillwater') ? 'The Lockwood Place has its lamp lit again. Folk on the water have noticed. They say it\'s good luck.'
        : G.questActive('lockwood_deed') && G.has('lockwood_deed') ? 'Is that... oilcloth? Let me see it.'
        : G.questDone('lockwood_deed') ? 'The Lockwood Place is yours for the filing fee, whenever you like.'
        : 'Afternoon. If you\'re here about the Lockwood Place, I\'m afraid I can\'t sell it. Not without the deed.',
      opts: [
        T('Why not?', 'about', {if: G => !G.questKnown('lockwood_deed')}),
        T('I found Silas\'s deed.', 'deed', {if: G => G.questActive('lockwood_deed') && G.has('lockwood_deed')}),
        T('What would it cost me?', 'price', {if: G => G.questDone('lockwood_deed') && !G.ownsHome('stillwater')}),
        T('Good day, Deacon.')]},
    about: {say: 'Silas Lockwood had no kin, and he took his deed out fishing with him, the old fool, the day his boat went down. The co-op won\'t let me sell a house nobody can prove was his to leave. The boatmen say he kept his papers in a tin lockbox under the boathouse floor. If you found it, I could sell you the place for the filing fee.',
      opts: [T('I\'ll look in the boathouse.', 'hub', {act: G => G.start('lockwood_deed')}), T('Good luck with it.', 'hub')]},
    deed: {say: 'Well, I\'ll be. Signed and witnessed. Then the Lockwood Place can be sold, and since you found it, it\'ll be sold to you, for what it costs me to file the paper.',
      opts: [T('Thank you, Deacon.', 'hub', {act: G => { G.take('lockwood_deed', 1); G.complete('lockwood_deed'); }})]},
  }, sale('stillwater'))},
};

export const POINTS = {
  rh_roof: {label: pt => G.questActive('roof_over_head') && !G.flags.rh_looked ? 'Look at the hole in the roof' : null,
    use: pt => { G.setFlag('rh_looked', 1); G.msg('The back half of the roof is open to the sky. The rafters are sound, but rain has had the floor for a season. It needs sheets and tape.'); checkQuests(); }},
  lw_lockbox: {label: pt => G.questActive('lockwood_deed') && !G.has('lockwood_deed') ? 'Prise up the loose boards' : null,
    use: pt => { G.give('lockwood_deed', 1); G.addXp(40); G.msg('Under the third board from the wall: a tin lockbox, rusted shut. You knock the hasp off. Inside, wrapped in oilcloth, the deed to the Lockwood Place, and a photograph of a woman on a pier.'); checkQuests(); }},
};
export const WORLD_POINTS = [
  {id: 'rh_roof', x: 624.0, z: 129.0, r: 3.0},
  {id: 'lw_lockbox', x: -93.0, z: -740.0, r: 2.6},
];

export const EPILOGUE = [
  {if: G => G.ownsAnyHome(), t: 'Whatever else the Wanderer was, they were a neighbour. The house they kept stood long after, and the people who lived in it after them told stories about who had lived there first.'},
  {if: G => G.homeResidents() >= 1, t: 'The companions who shared the Wanderer\'s roof never quite stopped calling it home, even years later, even when they had homes of their own.'},
];
