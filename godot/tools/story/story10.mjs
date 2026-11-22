// Ashfall: Meridian, build 10 story additions, written the same way as the WebView build's data.js (quests,
// conversations, world objects and epilogues with G => ... functions). tools/story/build.mjs turns this into
// data/story.json, which the game merges over data/logic.json when it starts.
//
//  - The valley's powers as factions, each with a standing that rises and falls with the work you do for them
//    and with what you choose: Dustwell, Saltreach, the Lamplighters, Gantry Yard, Haven 12 and the Silver Spur.
//  - A new main-story beat, "Five Hands on One Lever": once the race for the Meridian keycard starts, every power
//    in the valley makes its claim on the core, and you tell Sheriff Voss whose side you're on. Keeping or
//    breaking that word follows you into the ending.
//  - Companion quests for Jory Vance ("The Lead Wagon") and Sable ("Burning Bridges").
//  - Radio broadcasts and epilogue paragraphs for all of it.

export const FACTIONS = {
  dustwell: {n: 'Dustwell', leader: 'Sheriff Marla Voss', desc: 'The valley\'s oldest town, built around a well that is going green. Hard, fair, and running out of time.'},
  saltreach: {n: 'Saltreach', leader: 'Ines Duarte', desc: 'Salt-traders on the eastern flats. They count everything, share by measure, and turn nobody away.'},
  lamplight: {n: 'The Lamplighters', leader: 'Ro Castellan', desc: 'Hooded keepers of the old plant\'s manuals. They woke the Meridian core on purpose, to light the valley.'},
  gantry: {n: 'Gantry Yard', leader: 'Warlord Kess', desc: 'Kess\'s salvage crews and the guns that guard them. Everything in the yard is for sale, and so is the yard.'},
  haven: {n: 'Haven 12', leader: 'The Overseer', desc: 'Your shelter. Four hundred people behind a steel door, counting cups of water.'},
  spur: {n: 'The Silver Spur', leader: 'Madame Vex', desc: 'The casino in the old motor court. Neutral ground, as long as the house gets its cut.'},
};
// who you've worked for: finishing their quests raises your standing with them
export const QUEST_REP = {
  bad_water: {dustwell: 3}, dry_well: {dustwell: 2}, hounds: {dustwell: 1}, long_sleep: {dustwell: 1}, static: {dustwell: 1}, scrap: {dustwell: 1},
  old_iron: {dustwell: 1}, clean_hands: {dustwell: 1}, lost_patrol: {dustwell: 2}, vulture_jack: {dustwell: 2}, tusker: {dustwell: 1}, rustlers: {dustwell: 1},
  old_scar: {dustwell: 1}, tamsin_tune: {dustwell: 1}, dry_hole_brew: {dustwell: 1}, rad_fever: {dustwell: 2}, boost: {dustwell: 1}, black_box: {dustwell: 1},
  salt_wagons: {saltreach: 2}, chapel_bell: {saltreach: 1}, lost_brother: {saltreach: 1}, injector: {saltreach: 1}, water_rights: {saltreach: 2, dustwell: 1},
  inn_thief: {saltreach: 1}, sheriff_wanted: {saltreach: 2}, iron_crown: {saltreach: 3}, turncoat: {saltreach: 1}, deep_vein: {saltreach: 1}, remedy: {saltreach: 1},
  watcher: {saltreach: 1}, silent_choir: {saltreach: 1}, grounded: {saltreach: 1}, last_flight: {saltreach: 1},
  signal: {lamplight: 1}, keys: {lamplight: 1},
  yard_work: {gantry: 3, dustwell: -1},
  daylight: {haven: 1}, vault_seeds: {haven: 2}, real_meal: {haven: 1}, meltdown_logs: {haven: 1},
  patsy: {spur: 1}, high_roller: {spur: 1}, pockets_debt: {spur: 2},
};
// shops belong to someone: your standing with them moves the prices
export const VENDOR_FACTION = {duggan: 'dustwell', cass: 'dustwell', brannock: 'dustwell', halloran: 'dustwell', wick: 'dustwell', hollis: 'dustwell',
  kess: 'gantry', ro: 'lamplight', vex: 'spur', della: 'spur', oskar: 'saltreach', jun: 'saltreach', hale: 'saltreach', maren: 'saltreach', ezra: 'saltreach'};

export const ITEMS = {
  finch_strongbox: {n: 'Finch\'s Strongbox', t: 'quest', w: 4, v: 0, desc: 'A dented steel box from Finch\'s lead wagon. Inside: survey maps drawn before the war, wrapped in oilcloth.'},
  kess_ledger: {n: 'Kess\'s Ledger', t: 'quest', w: 0.5, v: 0, desc: 'Every name in Dustwell who sold Kess water on the side, and what she means to charge per cup when the wells fail.'},
  council_token: {n: 'Tin Star', t: 'junk', w: 0.1, v: 5, desc: 'Sheriff Voss pinned it on you after the council. It means you speak for nobody but yourself, which is rarer than it sounds.'},
};

export const QUESTS = {
  council: {t: 'Five Hands on One Lever', main: true,
    desc: 'Word of the keycard has spread. Everyone with a stake in the valley wants the Meridian core run their way, and Sheriff Voss wants to know whose side you\'re on before anybody starts shooting.',
    stages: [
      {txt: G => `Hear each claim on the core: Sheriff Voss in Dustwell, Ines in Saltreach, Ro at the Burned Chapel, Kess at Gantry Yard and the Overseer on your wrist radio (${['dustwell', 'saltreach', 'lamplight', 'gantry', 'haven'].filter(f => G.flags['heard_' + f]).length}/5).`,
        at: 'dustwell', done: G => ['dustwell', 'saltreach', 'lamplight', 'gantry', 'haven'].filter(f => G.flags['heard_' + f]).length >= 4},
      {txt: 'Tell Sheriff Voss in Dustwell whose side you\'re on.', at: 'dustwell', done: G => !!G.flags.pledge, auto: true}],
    reward: {xp: 260, caps: 0}},
  jory_wagon: {t: 'The Lead Wagon',
    desc: 'Two years ago Vulture Jack\'s crew took Finch\'s lead wagon on the western road, and Jory was the guard who lived. The strongbox never turned up.',
    stages: [
      {txt: 'Find the wreck of Finch\'s lead wagon on the western road, past the Burned Chapel, and recover the strongbox.', pos: () => ({x: -262, z: 128}), done: G => G.has('finch_strongbox')},
      {txt: 'Return the strongbox to Odalys Finch at the Dry Overpass, or sell the maps inside to Madame Vex at the Silver Spur.', at: 'ruinC'}],
    reward: G => G.flags.jory_box === 'finch' ? {xp: 200, caps: 0} : {xp: 120, caps: 0}},
  sable_ledger: {t: 'Burning Bridges',
    desc: 'Sable ran with Kess for six years. She left with a grudge and a secret: Kess keeps a ledger of everyone in Dustwell who has been selling her water.',
    stages: [
      {txt: 'Take Kess\'s ledger from her stash in Gantry Yard.', pos: () => ({x: 133, z: -5}), done: G => G.has('kess_ledger')},
      {txt: 'Decide what happens to the ledger: Sheriff Voss, Kess herself, or Sable\'s lighter.', at: 'dustwell'}],
    reward: {xp: 180, caps: 0}},
};

// lines spoken by people already in the game, as new branches of their conversations
export const DIALOGUE = {
  sheriff: {nodes: {
    c_claim: {say: 'Dustwell wants water. That\'s all it ever wanted. Light the core and Halloran says the leak into the aquifer seals itself. Kill the core and we limp along on the purifier chip, if we ever get it back. Either way, the town doesn\'t sell it and doesn\'t ration it.',
      opts: [{t: 'And if Haven 12 gets the regulator instead?', go: 'c_haven'}, {t: 'I\'ll hear the others.', go: 'hub'}]},
    c_haven: {say: 'Then four hundred people live who\'d otherwise die, and Dustwell drinks green water for another ten years. I\'m not going to tell you that\'s the wrong trade. I\'m going to tell you I\'d make the other one.', opts: [{t: 'Understood.', go: 'hub'}]},
    c_pledge: {say: G => `Go on, then. ${G.flags.heard_gantry ? 'Even Kess' : 'Everyone'} has had a turn. Who gets the core?`,
      opts: [
        {t: 'Dustwell. Clean wells first.', go: 'c_done', act: G => { G.pledge('dustwell'); G.karma(4, 'Stood with Dustwell'); }},
        {t: 'Saltreach. Ines\'s way: measured shares, nobody owns it.', if: G => G.flags.heard_saltreach, go: 'c_done', act: G => { G.pledge('saltreach'); G.karma(5, 'Stood for a fair share'); }},
        {t: 'The Lamplighters. Ro lights it, the whole valley gets it.', if: G => G.flags.heard_lamplight, go: 'c_done', act: G => { G.pledge('lamplight'); G.karma(3, 'Backed the Lamplighters'); }},
        {t: 'Haven 12. My people come first.', if: G => G.flags.heard_haven, go: 'c_done', act: G => G.pledge('haven')},
        {t: 'Kess. She\'s the only one who can hold it.', if: G => G.flags.heard_gantry, go: 'c_kess', act: G => { G.pledge('gantry'); G.karma(-10, 'Sided with the warlord'); }},
        {t: 'Nobody. I\'ll decide in front of the core.', go: 'c_none', act: G => { G.setFlag('pledge', 'none'); G.give('council_token', 1); G.complete('council'); }}]},
    c_done: {say: 'All right. I\'ll pass it round. Wear this. It\'s tin, and it means you said it out loud in front of me. Out here, that\'s most of what a promise is.', opts: [{t: 'Thanks, Sheriff.', go: 'hub'}]},
    c_kess: {say: 'Kess. ...I asked, and you answered. Keep the star. I\'d rather know where you stand than guess. Don\'t come to my town expecting to be bought a drink.', opts: [{t: 'Fair.', go: 'hub'}]},
    c_none: {say: 'Nobody. Smartest answer and the most dangerous one. Take the star anyway. When you\'re standing in that chamber, remember everybody you didn\'t choose is waiting outside it.', opts: [{t: 'I will.', go: 'hub'}]},
    l_read: {say: 'Let me see that. ...Pell Haskins. Mordecai at the well-house. My own cousin. Every one of them selling Kess our water by the barrel, and Kess writing it down so she\'d know who to squeeze. Where did you get this?',
      opts: [{t: 'Sable took me to it. She used to run with Kess.', go: 'l_done', act: G => { G.take('kess_ledger', 1); G.setFlag('ledger', 'sheriff'); G.rep('dustwell', 3); G.rep('gantry', -4); G.karma(6, 'Exposed Kess\'s water racket'); G.complete('sable_ledger'); }}]},
    l_done: {say: 'Then thank her for me, and tell her the town owes her one, which is a sentence I never expected to say about one of Kess\'s people. I\'ll handle my cousin myself.', opts: [{t: 'Goodbye.'}]},
  }},
  ines: {nodes: {
    i_claim: {say: 'Saltreach doesn\'t want the core. We want what comes out of it. A lit core seals the leak under the flats, and the deep aquifer is clean for everyone. Measured shares, written down, and a joint crew to run it. Nobody owns water. They only borrow it.',
      opts: [{t: 'And if it goes to Haven 12, or Kess?', go: 'i_else'}, {t: 'I\'ll remember that.', go: 'hub', act: G => G.setFlag('heard_saltreach', 1)}]},
    i_else: {say: 'Haven is a sealed box with a sad story. I don\'t blame them, but I won\'t pay for them either. Kess is a tax with a gun. If she gets it, Saltreach will be counting her cups instead of our salt.', opts: [{t: 'Understood.', go: 'hub', act: G => G.setFlag('heard_saltreach', 1)}]},
  }},
  ro: {nodes: {
    r_claim: {say: 'You already know what I want. I woke it. My grandmother kept the manuals in her coat for fifty years so somebody could. Lit, it powers every pump from here to the salt. Cold, it\'s a tomb with a fence round it.',
      opts: [{t: 'People say you put the valley in danger.', go: 'r_risk'}, {t: 'I\'ll weigh it.', go: 'hub', act: G => G.setFlag('heard_lamplight', 1)}]},
    r_risk: {say: 'I did. The leak was already there; I made it loud enough that somebody would have to fix it. That\'s a crime, probably. So is letting a valley drink poison quietly.', opts: [{t: 'Fair point.', go: 'hub', act: G => G.setFlag('heard_lamplight', 1)}]},
  }},
  kess: {nodes: {
    k_claim: {say: 'Here\'s my claim: I\'m the only one who can hold it. Voss has six deputies. Ines has accountants. Ro has a church with no roof. I have the yard, the guns and the pumps. Bring me the regulator and the valley drinks every day. At a price. Everything has a price.',
      opts: [{t: 'And if I don\'t?', go: 'k_threat'}, {t: 'I\'ll think about it.', go: 'hub', act: G => G.setFlag('heard_gantry', 1)}]},
    k_threat: {say: 'Then someone else holds it and I take it off them. It\'ll just cost more, and you won\'t get a cut. Go on. Ask the others. I like being the last one you hear.', opts: [{t: 'Noted.', go: 'hub', act: G => G.setFlag('heard_gantry', 1)}]},
    l_back: {say: 'My ledger. Sable, of course; she always did like reading over my shoulder. Three hundred chits and we forget this happened. Where is she?',
      opts: [{t: 'Out of your reach. Here. Take it.', go: 'l_paid', act: G => { G.take('kess_ledger', 1); G.addCaps(300); G.setFlag('ledger', 'kess'); G.rep('gantry', 3); G.karma(-4, 'Sold Sable out to Kess'); if (G.inParty('sable')) G.dismiss('sable'); G.setFlag('sableGone', 1); G.complete('sable_ledger'); }},
        {t: 'Never mind.', go: 'hub'}]},
    l_paid: {say: 'Pleasure. If she comes back round, I\'ll know you sent her. Don\'t send her.', opts: [{t: 'Goodbye.'}]},
  }},
  finch: {nodes: {
    f_box: {say: 'That\'s... that\'s my lead wagon\'s box. The maps. My mother drew half of these and her father drew the rest. Jory found it? Tell him the debt\'s paid. Tell him it was never his to pay. I\'ll put his name on the coastal sheet.',
      opts: [{t: 'He\'ll be glad to hear it.', go: 'hub', act: G => { G.take('finch_strongbox', 1); G.setFlag('jory_box', 'finch'); G.setFlag('finchFriend', 1); G.rep('dustwell', 1); G.karma(5, 'Returned Finch\'s maps'); G.complete('jory_wagon'); }}]},
  }},
  vex: {nodes: {
    v_maps: {say: 'Pre-war survey sheets, oilcloth and all. People will pay to know where the old roads go. Four hundred chits, and the house never asks where things come from.',
      opts: [{t: 'Sold.', go: 'v_sold', act: G => { G.take('finch_strongbox', 1); G.addCaps(400); G.setFlag('jory_box', 'vex'); G.rep('spur', 2); G.karma(-6, 'Sold Finch\'s maps'); if (G.inParty('jory')) G.dismiss('jory'); G.setFlag('joryGone', 1); G.complete('jory_wagon'); }},
        {t: 'Actually, they\'re not for sale.', go: 'hub'}]},
    v_sold: {say: 'A pleasure. If your bodyguard comes asking, I bought them off a stranger.', opts: [{t: 'Goodbye.'}]},
  }},
  jory: {nodes: {
    j_ask: {say: 'Once. Two years back, western road past the chapel. Vulture Jack\'s crew came out of the scrub at dusk. I got two of them, they got the driver and the lead wagon. Finch never said a word about it. That\'s worse.',
      opts: [{t: 'Was anything left?', go: 'j_box'}, {t: 'That\'s not on you.', go: 'party'}]},
    j_box: {say: 'The strongbox. Finch\'s family maps, pre-war. Jack\'s lot couldn\'t open it and couldn\'t sell what they couldn\'t open. If it\'s anywhere, it\'s by the wreck. Some of his crew still camp out there.',
      opts: [{t: 'Then let\'s go get it.', go: 'j_go', act: G => G.start('jory_wagon')}, {t: 'Another time.', go: 'party'}]},
    j_go: {say: 'Yeah? ...Yeah. All right. Western road, past the Burned Chapel, where the ditch runs black. I\'ll know it.', opts: [{t: 'Let\'s move.', go: 'party'}]},
    j_sold: {say: 'You sold them. To Vex. I told you whose they were. ...I\'m done. Pay me what you like; I won\'t be counting it.', opts: [{t: 'Jory—'}]},
  }},
  sable: {nodes: {
    s_ask: {say: 'Six years. I left because she started writing down people instead of crates. There\'s a ledger in her stash: every Dustwell fool who sold her water on the quiet. When the wells fail, she squeezes them first.',
      opts: [{t: 'So we take it.', go: 's_go', act: G => G.start('sable_ledger')}, {t: 'Not my fight.', go: 'party'}]},
    s_go: {say: 'Now you\'re fun. Her stash is the locker by the crane, east side of the yard. Walk in like you belong there. Nobody looks at people who look bored.', opts: [{t: 'Let\'s go.', go: 'party'}]},
    s_burn: {say: 'Give it here. ...You know what\'s nice about paper? It doesn\'t get a second opinion.',
      opts: [{t: 'Burn it.', go: 's_burned', act: G => { G.take('kess_ledger', 1); G.setFlag('ledger', 'burned'); G.setFlag('sableTrust', 1); G.karma(1, 'Let Sable burn the ledger'); G.complete('sable_ledger'); }}, {t: 'Wait. Not yet.', go: 'party'}]},
    s_burned: {say: 'There. Kess doesn\'t know who sold her out, Dustwell doesn\'t know who sold them out, and I sleep better. I owe you one. I don\'t say that.', opts: [{t: 'I know.', go: 'party'}]},
  }},
};

// new choices added to existing conversations, before their last option
export const INJECT = [
  {npc: 'sheriff', node: 'hub', opts: [
    {t: 'Everyone wants the core. What does Dustwell want?', if: G => G.questActive('council') && G.qStage('council') === 0 && !G.flags.heard_dustwell, go: 'c_claim', act: G => G.setFlag('heard_dustwell', 1)},
    {t: 'I\'ve heard the claims. Here\'s where I stand.', if: G => G.questActive('council') && G.qStage('council') === 1, go: 'c_pledge'},
    {t: 'Kess\'s ledger. Read it.', if: G => G.has('kess_ledger') && G.questActive('sable_ledger'), go: 'l_read'}]},
  {npc: 'ines', node: 'hub', opts: [
    {t: 'About the Meridian core. What does Saltreach want?', if: G => G.questActive('council') && !G.flags.heard_saltreach, go: 'i_claim'}]},
  {npc: 'ro', node: 'hub', opts: [
    {t: 'Everyone\'s lining up for the core. Tell me again what you want.', if: G => G.questActive('council') && !G.flags.heard_lamplight, go: 'r_claim'}]},
  {npc: 'kess', node: 'hub', opts: [
    {t: 'Word is you want the regulator.', if: G => G.questActive('council') && !G.flags.heard_gantry, go: 'k_claim'},
    {t: 'I have something of yours. A ledger.', if: G => G.has('kess_ledger') && G.questActive('sable_ledger'), go: 'l_back'}]},
  {npc: 'finch', node: 'hub', opts: [
    {t: 'Your lead wagon\'s strongbox. Jory found the wreck.', if: G => G.has('finch_strongbox'), go: 'f_box'}]},
  {npc: 'vex', node: 'hub', opts: [
    {t: 'I have a box of pre-war survey maps.', if: G => G.has('finch_strongbox'), go: 'v_maps'}]},
  {npc: 'jory', node: 'party', opts: [
    {t: 'Ever lose one of Finch\'s wagons?', if: G => !G.questKnown('jory_wagon') && G.P.level >= 3, go: 'j_ask'}]},
  {npc: 'sable', node: 'party', opts: [
    {t: 'Why did you leave Kess?', if: G => !G.questKnown('sable_ledger'), go: 's_ask'},
    {t: 'The ledger. You wanted to burn it.', if: G => G.has('kess_ledger') && G.questActive('sable_ledger'), go: 's_burn'}]},
];

// world objects quests use (QUEST_POINTS) and where they stand
export const POINTS = {
  jory_box: {label: pt => G.questActive('jory_wagon') && !G.has('finch_strongbox') ? 'Pry open the wagon\'s strongbox' : null,
    use: pt => { G.give('finch_strongbox', 1); G.msg('The lock gives. Oilcloth, and maps older than the war.'); checkQuests(); }},
  kess_ledger: {label: pt => G.questActive('sable_ledger') && !G.has('kess_ledger') ? 'Take Kess\'s ledger' : null,
    use: pt => { G.give('kess_ledger', 1); G.karma(-1, 'Stole from Kess'); G.msg('A cloth-bound ledger. Names, dates, barrels.'); checkQuests(); }},
};
export const WORLD_POINTS = [
  {id: 'jory_box', x: -262, z: 128, r: 2.6},
  {id: 'kess_ledger', x: 133.2, z: -5.2, r: 2.2},
];
// people who come with a quest (they appear when it starts)
export const SPAWNS = [
  {id: 'jw_1', type: 'raider', x: -255, z: 135, onStart: 'jory_wagon'},
  {id: 'jw_2', type: 'raider', x: -268, z: 121, onStart: 'jory_wagon'},
  {id: 'jw_3', type: 'raider', x: -258, z: 117, onStart: 'jory_wagon'},
  {id: 'jw_4', type: 'sniper', x: -275, z: 138, onStart: 'jory_wagon'},
];
// scenery for the quests: the burnt-out lead wagon
export const PROPS = [
  {kind: 'wagon_burnt', x: -263.5, z: 130, rot: 0.6},
];
// things that happen when the story allows: start a quest, set a flag, play a broadcast
export const TRIGGERS = [
  {if: G => G.questKnown('keys') && !G.questKnown('council'), do: G => { G.start('council'); G.setFlag('heard_haven', 1); G.setFlag('radio', 'council_haven'); }},
  {if: G => G.flags.jory_box === 'vex' && !G.flags.joryTold, do: G => { G.setFlag('joryTold', 1); G.msg('Word reaches Jory about the maps. He\'s gone back to Finch\'s camp, and he won\'t be coming with you again.'); }},
];
export const RADIO = {
  council_haven: {h: 'INCOMING: HAVEN 12 // OVERSEER', t: `> PRIORITY SIGNAL — WRIST UNIT 12-0447

I am told the people up there are holding a meeting about our regulator.

Let me be plain, so you can repeat it. Haven 12 does not want the reactor. We do not want their water or their power. We want one part, which keeps four hundred people breathing, and then we want to be left alone.

I can't make you choose us. I'm asking you to remember who raised you.

> END`},
};
// new closing paragraphs, shown before the last line of the ending
export const EPILOGUE = [
  {if: G => G.flags.pledge === 'dustwell' && G.flags.ending === 'dustwell', t: 'You told Sheriff Voss the water was Dustwell\'s, and it was. She wore her own tin star to the purifier\'s first run and pinned it on the pump.'},
  {if: G => G.flags.pledge === 'saltreach' && (G.flags.ending === 'lamplight' || G.flags.ending === 'dustwell'), t: 'Ines Duarte wrote the shares on the wall of the Saltreach well-house in white paint. Your line says "one cup, for the one who kept their word."'},
  {if: G => G.flags.pledge === 'lamplight' && G.flags.ending === 'lamplight', t: 'The Lamplighters lit a lantern for every promise kept that year. There were not many. Yours hung highest.'},
  {if: G => G.flags.pledge === 'haven' && G.flags.ending === 'sealed', t: 'The Overseer read your name aloud at the next ration count. Four hundred people stood up for it.'},
  {if: G => G.flags.pledge === 'gantry' && G.flags.ending === 'warlord', t: 'Kess paid you exactly what she promised, which was the only honest thing anyone in the valley expected of her.'},
  {if: G => G.flags.pledge && G.flags.pledge !== 'none' && G.flags.ending && !({dustwell: ['dustwell'], saltreach: ['lamplight', 'dustwell'], lamplight: ['lamplight'], haven: ['sealed'], gantry: ['warlord']}[G.flags.pledge] || []).includes(G.flags.ending),
    t: 'You stood in Sheriff Voss\'s office and named a side, and then you chose another. People in the valley still repeat what you said. They say it the way you say a joke nobody laughs at.'},
  {if: G => G.flags.pledge === 'none', t: 'You never told the council whose side you were on. Some called it wisdom. Most just remembered the tin star, and that you had worn it without ever saying a word.'},
  {if: G => G.flags.jory_box === 'finch', t: 'Odalys Finch\'s coastal sheet came out the next spring. In the corner, in small careful letters: "Survey escort: J. Vance. Debt: none."'},
  {if: G => G.flags.jory_box === 'vex', t: 'The Spur sold Finch\'s maps one sheet at a time. Jory Vance never hired out again; he drives Finch\'s lead wagon himself now, and doesn\'t talk about why.'},
  {if: G => G.flags.ledger === 'sheriff', t: 'Dustwell\'s water-sellers were made to stand at the well and hand out cups for a month. Kess never found out who gave her ledger away. She suspected everybody, which suited Sable fine.'},
  {if: G => G.flags.ledger === 'kess', t: 'Kess got her ledger back and her squeeze went on. Sable was seen once more, on the Saltreach road, and did not wave.'},
  {if: G => G.flags.ledger === 'burned', t: 'Somewhere in a ditch east of Gantry Yard there is a little circle of ash. Sable visits it, she says, for the view.'},
  {if: G => (G.flags.rep_saltreach || 0) >= 8, t: 'Saltreach named its newest well after you. It is the deepest, and the only one that never tastes of salt.'},
  {if: G => (G.flags.rep_gantry || 0) <= -6, t: 'At Gantry Yard there is a picture of you nailed to the crane, and a bounty under it that nobody has collected.'},
];
