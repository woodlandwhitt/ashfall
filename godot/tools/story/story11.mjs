// Build 11 story layer: Deputy Renn as a companion and his quest (Old Colours), the companions' personal
// conversations (approval and loyalty), and the closing lines for all of it. Same shape as story10.mjs; build.mjs
// merges the two (objects key by key, arrays end to end).

export const QUEST_REP = {
  old_colours: {saltreach: 2},
};
export const NPC_FACTION = {renn2: 'saltreach'};

export const COMPANIONS = {
  renn2: {n: 'Renn', hp: 150, dmg: 14, range: 40, atk: 0.8, spd: 5.8, ranged: true, minKarma: -25,
    barks: {
      combat: ['Here they come!', 'Watch the flank!', 'I see them. Left side!', 'Stay low!'],
      kill: ['Got him.', 'That\'s one.', 'Down and staying down.'],
      hurt: ['Ah! I\'m fine. I\'m fine.', 'Hit! Keep going!'],
      idle: ['Ines says I can keep the badge if I stop polishing it.', 'Lizard tastes better when nobody\'s hunting you.',
        'I used to watch this road from the other side.', 'You ever owe somebody your whole life? It\'s heavy. Good heavy.'],
      leave: 'I left the Gulch to get away from people like you. I\'m going home.'}},
};

export const ITEMS = {
  route_list: {n: 'Wagon Routes', t: 'quest', w: 0, v: 0, desc: 'Saltreach\'s salt-wagon routes and times for the month, copied out in a neat merchant\'s hand. Found on Mags Coyle.'},
  deputy_star: {n: 'Saltreach Badge', t: 'junk', w: 0.1, v: 5, desc: 'Renn\'s spare deputy\'s badge, a salt-crusted tin star. He says you earned it more than he did.'},
};

export const QUESTS = {
  old_colours: {t: 'Old Colours',
    desc: 'Mags Coyle of Rattlesnake Gulch has put a price on Renn\'s head for deserting. Her crew is camped in the dry wash below the Gulch, waiting on the salt wagons.',
    stages: [
      {txt: 'Deal with Mags Coyle\'s crew in the dry wash south-east of Rattlesnake Gulch.', pos: () => ({x: -332, z: 252}), done: G => G.killed('oc_boss')},
      {txt: 'Search Coyle\'s camp.', pos: () => ({x: -334, z: 255}), done: G => G.has('route_list')},
      {txt: 'Somebody in Saltreach sold Coyle the wagon routes. Talk it over with Renn.', done: G => !!G.flags.oc_seen},
      {txt: 'Decide what happens to Oskar Vane: take the routes to Mayor Ines, or have it out with Oskar yourself.', at: 'saltreach'}],
    reward: {xp: 240, caps: 0}},
};

export const DIALOGUE = {
  renn2: {nodes: {
    r_join: {say: 'Ines would tell me to go. She\'d also tell me to bring back whatever I borrow, so try not to get me shot. All right. Saltreach can spare one deputy.',
      opts: [{t: 'Welcome aboard.', act: G => { G.recruit('renn2'); G.approve('renn2', 5); }}]},
    r_refuse: {say: 'No. I know what you are now. I used to be it.', opts: [{t: 'Fine.'}]},
    party: {say: G => G.loyal('renn2') ? 'Partner.' : 'Need something?', opts: [
      {t: 'Wait here.', if: G => G.partyState('renn2') !== 'wait', act: G => G.partyCmd('renn2', 'wait')},
      {t: 'With me.', if: G => G.partyState('renn2') === 'wait', act: G => G.partyCmd('renn2', 'follow')},
      {t: 'How are you holding up?', go: 'talk'},
      {t: 'Something\'s eating at you.', if: G => !G.questKnown('old_colours'), go: 'r_ask'},
      {t: 'Coyle had a list on her.', if: G => G.has('route_list') && !G.flags.oc_seen, go: 'r_list'},
      {t: 'You\'ve changed, Renn.', if: G => !G.loyal('renn2') && G.approval('renn2') >= 30 && G.questDone('old_colours'), go: 'r_loyal'},
      {t: 'Head back to Saltreach.', act: G => G.dismiss('renn2')},
      {t: 'Nothing.'}]},
    talk: {say: G => G.approval('renn2') >= 40 ? 'Better than I have any right to be. I wake up and nobody\'s looking for me. Except you, and you\'re asking how I am. Weird.'
      : G.approval('renn2') <= -15 ? 'Honestly? You\'re starting to remind me of the Gulch. I\'m not saying that to be cruel.'
      : 'Sore feet. Clean conscience. Mostly clean. Getting there.', opts: [{t: 'Back to it.', go: 'party'}]},
    r_ask: {say: 'A Gulch rider came through Saltreach last week. Coyle\'s people. Mags has put two hundred chits on the deserter, alive or otherwise. That\'s me. Her crew\'s sitting in the dry wash under the Gulch, waiting for the salt wagons, and for me.',
      opts: [{t: 'Then we go to them.', go: 'r_go', act: G => G.start('old_colours')}, {t: 'Not today.', go: 'party'}]},
    r_go: {say: 'I was hoping you\'d say that. I was also hoping you wouldn\'t. Dry wash, south-east of the Gulch. Coyle wears a red scarf. She\'ll want to talk first. Don\'t let her.', opts: [{t: 'Let\'s move.', go: 'party'}]},
    r_list: {say: 'Let me see. ...That\'s the wagon schedule for the whole month. And that hand, all loops and no blots, that\'s Oskar Vane\'s. He\'s been selling his own town\'s routes to the Gulch. Probably so the other salt companies get hit and his crust goes up in price.',
      opts: [{t: 'We take this to Ines.', go: 'r_ines', act: G => { G.setFlag('oc_seen', 1); G.approve('renn2', 5); }},
        {t: 'Let\'s have a word with Oskar first.', go: 'r_oskar', act: G => G.setFlag('oc_seen', 1)}]},
    r_ines: {say: 'Good. Ines will want to read it twice and then shout once. I\'ll stand behind you. It\'s my town now. Funny how fast that happens.', opts: [{t: 'Let\'s go.', go: 'party'}]},
    r_oskar: {say: 'All right. But if he offers you money, I\'m going to be standing right there, and I\'m going to remember what you say.', opts: [{t: 'Noted.', go: 'party'}]},
    r_loyal: {say: 'Have I? ...Yeah. In the Gulch you learn that everybody\'s a price. Then you walked out of nowhere and treated me like I was a person who could be trusted with a rifle. So. Whatever you need, wherever. That\'s not a deputy talking. That\'s me. Here, take the spare badge.',
      opts: [{t: 'Thank you, Renn.', go: 'party', act: G => { G.give('deputy_star', 1); G.makeLoyal('renn2'); }}]},
  }},
  ines: {nodes: {
    oc_ines: {say: 'Oskar. Oskar Vane, whose salt I have eaten at my own table. ...Thank you. And thank Renn, who I see is standing very straight. Saltreach will fine him every chit the Gulch ever paid him and he\'ll pan the flats by hand for a year. In public.',
      opts: [{t: 'Fair.', go: 'hub', act: G => { G.take('route_list', 1); G.setFlag('oc', 'ines'); G.rep('saltreach', 3); G.karma(5, 'Exposed the route seller'); G.approve('renn2', 10); G.complete('old_colours'); }}]},
  }},
  oskar: {nodes: {
    oc_face: {say: 'Ah. That\'s my handwriting. ...Before you say anything: the Gulch was going to hit someone\'s wagons. I made sure it wasn\'t mine. That\'s not a crime, that\'s business. Here, two hundred and fifty chits, and you lose that list in the salt pan.',
      opts: [{t: 'Take the money.', go: 'oc_bribed', act: G => { G.take('route_list', 1); G.addCaps(250); G.setFlag('oc', 'bribe'); G.karma(-6, 'Took Oskar\'s bribe'); G.approve('renn2', -30, 'He watched you take the money'); G.complete('old_colours'); }},
        {t: 'People died on those wagons. You\'re going to pay their families. Today.', check: ['charm', 6], go: 'oc_pays', act: G => { G.take('route_list', 1); G.setFlag('oc', 'oskar'); G.rep('saltreach', 2); G.karma(4, 'Made Oskar pay the families'); G.approve('renn2', 12); G.complete('old_colours'); }},
        {t: 'Save it for Ines.', go: 'hub'}]},
    oc_bribed: {say: 'Sensible. You\'d be surprised how rarely I meet someone sensible. Your friend with the badge is giving me a look, by the way.', opts: [{t: 'Goodbye.'}]},
    oc_pays: {say: '...Fine. Fine! The families. Out of my own pocket. You\'ve a nasty way of being right. Don\'t tell Ines. Please. I\'ll pay double if you don\'t tell Ines.', opts: [{t: 'Just pay them.'}]},
  }},
  jory: {nodes: {
    talk: {say: G => G.approval('jory') >= 40 ? 'Honestly? Best job I\'ve had. You make me feel like the good guys still exist.'
      : G.approval('jory') <= -15 ? 'I\'m watching you, boss. Don\'t give me a reason.'
      : 'Feet hurt. Rifle\'s clean. That\'s a good day out here.', opts: [{t: 'Back to it.', go: 'party'}]},
    j_loyal: {say: 'Trust you? ...I hired out for ten years and I never once turned my back on the person paying me. I turn it on you now and I don\'t think about it. That\'s new. Don\'t make me regret it. You won\'t. I know that.',
      opts: [{t: 'Partners, then.', go: 'party', act: G => G.makeLoyal('jory')}]},
    j_refuse: {say: 'We\'re done. I don\'t work for you, and I don\'t want your chits.', opts: [{t: 'Jory...'}]},
  }},
  sable: {nodes: {
    talk: {say: G => G.approval('sable') >= 40 ? 'Bored? With you? You walk into a room and something always catches fire. I love it.'
      : G.approval('sable') <= -15 ? 'You\'re turning into a saint, you know that? It\'s disgusting.'
      : 'Fine. Hungry. Bit bored. Point me at something.', opts: [{t: 'Back to it.', go: 'party'}]},
    s_loyal: {say: 'Bored? No. That\'s the strange part. Kess paid better and I never once wanted to stay. You don\'t ask me to be nice, you don\'t ask me to be sorry. You just keep walking into trouble and assuming I\'ll follow. I will. Don\'t tell anyone.',
      opts: [{t: 'Your secret\'s safe.', go: 'party', act: G => G.makeLoyal('sable')}]},
    s_refuse: {say: 'No. You had your chance to be interesting.', opts: [{t: 'Fine.'}]},
  }},
};

// who you meet first when you walk up to someone (replaces the original's choice)
export const ENTRY = {
  renn2: G => G.inParty('renn2') ? 'party' : G.flags.left_renn2 ? 'r_refuse' : 'hub',
  jory: G => G.inParty('jory') ? 'party' : (G.flags.left_jory || G.flags.joryGone) ? 'j_refuse' : G.P.karma <= -40 ? 'refuse' : 'intro',
  sable: G => G.inParty('sable') ? 'party' : (G.flags.left_sable || G.flags.sableGone) ? 's_refuse' : G.P.karma >= 60 ? 'refuse' : 'intro',
};

export const INJECT = [
  {npc: 'renn2', node: 'hub', opts: [
    {t: 'Could Saltreach spare a deputy for a while? I could use a rifle.', if: G => !G.inParty('renn2') && !G.flags.left_renn2 && G.P.karma > -25, go: 'r_join'}]},
  {npc: 'ines', node: 'hub', opts: [
    {t: 'Someone in Saltreach sold your wagon routes to the Gulch. Here.', if: G => G.has('route_list') && G.flags.oc_seen, go: 'oc_ines'}]},
  {npc: 'oskar', node: 'hub', opts: [
    {t: 'This list of wagon routes. It\'s in your handwriting.', if: G => G.has('route_list') && G.flags.oc_seen, go: 'oc_face'}]},
  {npc: 'jory', node: 'party', opts: [
    {t: 'You trust me yet?', if: G => !G.loyal('jory') && G.approval('jory') >= 30, go: 'j_loyal'}]},
  {npc: 'sable', node: 'party', opts: [
    {t: 'Still bored?', if: G => !G.loyal('sable') && G.approval('sable') >= 30, go: 's_loyal'}]},
];

export const POINTS = {
  oc_satchel: {label: pt => G.questActive('old_colours') && G.killed('oc_boss') && !G.has('route_list') ? 'Search Coyle\'s satchel' : null,
    use: pt => { G.give('route_list', 1); G.give('ammo_44', 12); G.addCaps(60); G.msg('A red scarf, sixty chits, a box of .44, and a folded sheet of wagon routes in a neat hand.'); checkQuests(); }},
};
export const WORLD_POINTS = [
  {id: 'oc_satchel', x: -334.5, z: 255, r: 2.2},
];
export const SPAWNS = [
  {id: 'oc_boss', type: 'warlord', name: 'Mags Coyle', x: -333, z: 253, onStart: 'old_colours'},
  {id: 'oc_1', type: 'raider', name: 'Gulch Rider', x: -327, z: 247, onStart: 'old_colours'},
  {id: 'oc_2', type: 'raider', name: 'Gulch Rider', x: -339, z: 248, onStart: 'old_colours'},
  {id: 'oc_3', type: 'sniper', name: 'Gulch Lookout', x: -342, z: 260, onStart: 'old_colours'},
  {id: 'oc_4', type: 'marauder', name: 'Gulch Rider', x: -325, z: 258, onStart: 'old_colours'},
];
// Coyle's camp in the wash
export const PROPS = [
  {kind: 'sandbags', x: -329, z: 249, rot: 0.4}, {kind: 'sandbags', x: -338, z: 250, rot: -0.5},
  {kind: 'crate', x: -335.5, z: 256.5, rot: 0.2}, {kind: 'crate', x: -336.6, z: 255.4, rot: 0.9}, {kind: 'barrel', x: -331, z: 257},
  {kind: 'table', x: -334.5, z: 254, rot: 0.3}, {kind: 'lamp', x: -330, z: 254},
];
export const TRIGGERS = [
  {if: G => G.questActive('old_colours') && G.qStage('old_colours') === 2 && !G.inParty('renn2') && G.has('route_list') && !G.flags.oc_seen,
    do: G => { G.setFlag('oc_seen', 1); G.msg('You\'d know that neat merchant\'s hand anywhere in Saltreach: Oskar Vane.'); }},
];
export const EPILOGUE = [
  {if: G => G.flags.oc === 'ines', t: 'Oskar Vane panned salt by hand for a year in front of the whole of Saltreach. Deputy Renn checked on him every morning, and brought him water, which Oskar said was the cruellest part.'},
  {if: G => G.flags.oc === 'oskar', t: 'Every family that lost a wagon got an envelope that winter with no name on it. Renn knew whose it was. He never told Ines, and he never told anybody why he was smiling.'},
  {if: G => G.flags.oc === 'bribe', t: 'Oskar Vane got richer. Renn handed his badge back to Ines the week after, and was seen heading west, towards the Gulch, alone.'},
  {if: G => G.flags.loyal_jory && G.flags.jory_box !== 'vex', t: 'Jory Vance kept a second bedroll in Finch\'s lead wagon for years, "in case the boss turns up." Sometimes you did.'},
  {if: G => G.flags.loyal_sable && G.flags.ledger !== 'kess', t: 'Sable never did settle anywhere. But wherever she went, she left the same mark scratched into a doorframe: two lines, crossed, which she said meant "we were here, and it was fun."'},
  {if: G => G.flags.loyal_renn2, t: 'Saltreach made Renn its first sheriff. On his desk he keeps a tin star with a dent in it, and when people ask, he says it belongs to a friend who\'s still out there walking.'},
  {if: G => G.flags.left_jory || G.flags.left_sable || G.flags.left_renn2, t: 'Not everyone who walked beside you finished the walk. They tell their own version of you now, around their own fires.'},
];
