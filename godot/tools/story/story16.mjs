// Build 16 story layer: the north, through Northgate, the Airfield Cut and the Ashwood's ridge gap. Three places with
// people in them (Stillwater on its reservoir; the Garage market in the ruins of Old Meridian; the Children of the
// Glass on the rim of the Glass Bowl), a gang in a tower (the Highrisers and their Duchess, in the Spire), and the old
// missile silo at the bottom of the crater that is quietly poisoning the valley's best water. Three quests:
//
//  - Still Waters (Nell Okafor, harbourmaster): the reservoir's fish are dying. The poison runs from a pipe stamped
//    SILO 9 COOLANT; the one man who understood that silo is a prisoner in the Spire; the silo's console decides it.
//  - The Spire (Velma Cruz at the Garage): get Tobiah Fenn out of the Highrisers' cage: ransom, talk, a lockpick or
//    a war.
//  - Children of the Glass (Brother Amon): the Prophet wants Silo 9 opened so the Sleeper can wake. The Bowl is
//    killing his flock. Give him the key, break his hold with the truth, or end him.
// The silo's choice (shut the purge, vent it into the Bowl, or bury the silo) lands in all three.

export const FACTIONS = {
  stillwater: {n: 'Stillwater', leader: 'Nell Okafor', desc: 'Fishers and water-sellers on the valley\'s last clean reservoir. Slow to trust, quick to feed you.'},
  highrisers: {n: 'The Highrisers', leader: 'the Duchess', desc: 'A gang that holds the tallest tower left in Old Meridian and charges rent on the whole skyline.'},
  children: {n: 'Children of the Glass', leader: 'Prophet Sel', desc: 'Pilgrims camped on the rim of the bomb crater, who believe something sleeps beneath it and that its light is grace.'},
};
export const QUEST_REP = {still_waters: {stillwater: 3}, the_spire: {stillwater: 1}, children_of_glass: {children: 2}};
export const NPC_FACTION = {nell: 'stillwater', gus: 'stillwater', mara: 'stillwater', sw_guard: 'stillwater', sw_folk1: 'stillwater', sw_folk2: 'stillwater', tobiah2: 'stillwater',
  velma: 'stillwater', gr_guard: 'stillwater', duchess: 'highrisers', sel: 'children', amon: 'children', gc_folk1: 'children', gc_folk2: 'children', gc_guard: 'children'};
export const VENDOR_FACTION = {gus: 'stillwater', velma: 'stillwater'};
export const GUARDS = ['sw_guard', 'gr_guard', 'gc_guard'];

export const LOCS = {
  stillwater: {name: 'Stillwater', x: -60, z: -748, r: 46},
  reservoir: {name: 'Stillwater Reservoir', x: -220, z: -790, r: 70},
  northgate: {name: 'Northgate', x: -166, z: -520, r: 24},
  old_meridian: {name: 'Old Meridian', x: 420, z: -768, r: 120},
  the_garage: {name: 'The Garage', x: 295, z: -702, r: 22},
  the_spire: {name: 'The Spire', x: 445, z: -792, r: 22},
  airfield_cut: {name: 'Airfield Cut', x: 302, z: -520, r: 24},
  glass_bowl: {name: 'The Glass Bowl', x: 1150, z: -760, r: 110},
  glass_camp: {name: 'Children of the Glass', x: 1150, z: -612, r: 28},
  silo9: {name: 'Silo 9', x: 1152, z: -795, r: 22},
};

const F = (body, skin, hat = null, coat = null, bulk = 1) => ({fem: true, body, skin, hat, coat, bulk});
const M = (body, skin, hat = null, coat = null, bulk = 1) => ({fem: false, body, skin, hat, coat, bulk});
const N = (id, name, x, z, rot, look, extra = {}) => Object.assign({id, name, x, z, rot, wander: null, scale: 1, look}, extra);
export const NPCS = [
  N('nell', 'Nell Okafor', -40.5, -726.6, 3.1416, F('#3a4a5a', '#6a4430', 'wide', '#2a3a4a')),
  N('gus', 'Gus Pruitt', -48.0, -775.0, 0, M('#5a6a5a', '#e0ac88', 'cap', null, 1.3)),
  N('mara', 'Mara Lind', -91.0, -739.0, -1.5708, F('#6a5a3a', '#d8a884', 'cap')),
  N('sw_guard', 'Stillwater Watch', -94.0, -684.0, 0, M('#4a5a4a', '#a8724c', 'helmet', '#3a4a3a', 1.1)),
  N('sw_folk1', 'Stillwater Fisher', -56, -750, 0, F('#5a6a7a', '#d2a07a', 'wide'), {wander: {x: -58, z: -750, r: 18}}),
  N('sw_folk2', 'Stillwater Fisher', -122.0, -748.0, -1.5708, M('#4a4a3a', '#8a5a3a', 'wide')),
  N('tobiah2', 'Tobiah Fenn', -32.0, -781.5, 0, M('#6a6a62', '#c89a78', null, '#5a5a52', 0.9), {flag: 'tobiahFree'}),
  N('velma', 'Velma Cruz', 296.0, -704.0, 0, F('#5a3a3a', '#b8865a', 'cap', '#4a2a2a')),
  N('gr_guard', 'Garage Guard', 295.0, -688.0, 0, M('#4a4a40', '#e0ac88', 'helmet', '#3a3a30', 1.15)),
  N('tobiah', 'Tobiah Fenn', 438.5, -799.0, 0, M('#6a6a62', '#c89a78', null, '#5a5a52', 0.9), {unless: 'tobiahFree'}),
  N('duchess', 'The Duchess', 448.0, -794.0, 3.1416, F('#2a2a3a', '#d8a884', null, '#6a1a3a', 1.1), {unless: 'hrGone', fight: {hp: 240, dmg: 16, ranged: true}}),
  N('sel', 'Prophet Sel', 1150.0, -624.4, 0, M('#3a5a3a', '#a8724c', 'hood', '#2a4a2a', 1.05), {unless: 'gcLeft', fight: {hp: 150, dmg: 12, ranged: false}}),
  N('amon', 'Brother Amon', 1163.0, -610.0, -1.5708, M('#3a4a3a', '#d2a07a', 'hood', '#2a3a2a')),
  N('gc_folk1', 'Child of the Glass', 1144, -610, 0, F('#3a5a3a', '#e0ac88', 'hood'), {unless: 'gcLeft', wander: {x: 1150, z: -612, r: 12}}),
  N('gc_folk2', 'Child of the Glass', 1156, -616, 0, M('#3a5a3a', '#8a5a3a', 'hood'), {unless: 'gcLeft', wander: {x: 1150, z: -612, r: 12}}),
  N('gc_guard', 'Glass Warden', 1180.0, -598.0, 0.6, M('#2a4a2a', '#c89a78', 'hood', '#1a3a1a', 1.15), {unless: 'gcLeft'}),
  N('gc_folk3', 'Child of the Glass', -66, -762, 0, F('#3a5a3a', '#e0ac88', 'hood'), {flag: 'gcLeft', wander: {x: -60, z: -755, r: 14}}),
];

export const VENDORS = {
  gus: {name: 'Stillwater Co-op', caps: 500, buy: 1.3, sell: 0.55, town: true, likes: {aid: 1.25},
    stock: [['purified_water', 12], ['smoked_fish', 8], ['canned_beans', 4], ['flatbread', 5], ['coffee_tin', 3], ['rad_tea', 3], ['stimpak', 2], ['radaway', 3],
      ['jerky', 4], ['duct_tape', 3], ['fuel_can', 2], ['bobby_pin', 6], ['hunting_rifle', 1], ['ammo_rifle', 30]]},
  velma: {name: 'Velma\'s Stall', caps: 900, buy: 1.45, sell: 0.6, town: true, likes: {weapon: 1.3},
    stock: [['ammo_9', 120], ['ammo_rifle', 60], ['shells', 36], ['ammo_44', 30], ['cell', 60], ['fusion_cell', 4], ['frag', 4], ['dynamite', 3], ['molotov', 3],
      ['service_rifle', 1], ['laser_pistol', 1], ['arc_pistol', 1], ['scrap_armor', 1], ['raider_armor', 1], ['circuit', 4], ['gears', 4], ['stimpak', 3]]},
};

export const ITEMS = {
  slag_sample: {n: 'Jar of Inlet Sludge', t: 'quest', w: 0.5, v: 0, desc: 'Green-black sludge scooped from the reservoir\'s north inlet. It glows faintly in the dark and makes the jar warm. The broken pipe above it was stamped SILO 9 COOLANT.'},
  silo_key: {n: 'Silo 9 Launch Key', t: 'quest', w: 0.1, v: 0, desc: 'A steel key on a beaded chain, pulled from the chassis of the guard robot the Children call the Iron Angel. The tag reads SILO 9 - CREW B - TWO-MAN RULE.'},
  dosimeter_log: {n: 'Brother Amon\'s Dosimeter Log', t: 'quest', w: 0.2, v: 0, desc: 'Three months of readings from the Children\'s camp and the crater floor, written up in a careful hand. At the bottom: the names of eleven pilgrims, and the dates they died.'},
  duchess_token: {n: 'Highriser Rent Token', t: 'junk', w: 0, v: 25, desc: 'A brass washer stamped with a crown. In Old Meridian it means you\'ve paid, or that the Duchess wants people to think so.'},
  glass_shard: {n: 'Bowl Glass', t: 'junk', w: 0.2, v: 18, desc: 'A palm-sized shard of the green glass the bomb made of the crater floor. The Children wear them. It ticks on a counter.'},
};

export const QUESTS = {
  still_waters: {t: 'Still Waters',
    desc: 'Stillwater\'s reservoir is the cleanest water left in the valley, and its fish have started floating belly-up at the north end. Nell Okafor wants to know why before the water sellers in the south find out.',
    stages: [
      {txt: 'Find out what\'s coming into the reservoir at its north inlet.', at: 'reservoir', pos: () => ({x: -215, z: -852}), done: G => G.has('slag_sample')},
      {txt: 'The pipe is stamped SILO 9 COOLANT. The man who knew that silo, Tobiah Fenn, is a prisoner of the Highrisers in the Spire, Old Meridian. Talk to him.', at: 'the_spire',
        done: G => !!G.flags.tobiahTalked || G.has('silo_key')},
      {txt: G => G.flags.tobiahCodes || G.has('silo_key') ? 'Go down into the Glass Bowl and stop the purge at Silo 9\'s console.' : 'Silo 9 sits at the bottom of the Glass Bowl. You need a launch key (the guard robot carries one) or Tobiah\'s override codes to touch its console.',
        at: 'silo9', done: G => !!G.flags.silo_end},
      {txt: 'Tell Nell what you did at Silo 9.', at: 'stillwater'}],
    reward: G => G.flags.silo_end === 'vent' ? {xp: 300, caps: 120} : G.flags.silo_end === 'blown' ? {xp: 420, caps: 200} : {xp: 450, caps: 250}},
  the_spire: {t: 'The Spire',
    desc: 'The Highrisers took Tobiah Fenn, the Garage\'s engineer, for ransom. Velma Cruz can\'t pay it and won\'t forget it.',
    stages: [
      {txt: 'Get Tobiah Fenn out of the Highrisers\' cage in the Spire.', at: 'the_spire', done: G => !!G.flags.tobiahFree},
      {txt: 'Let Velma know Tobiah is out.', at: 'the_garage'}],
    reward: G => G.flags.spire_way === 'paid' ? {xp: 180, caps: 200} : {xp: 280, caps: 150}},
  children_of_glass: {t: 'Children of the Glass',
    desc: 'Brother Amon believes the Prophet is leading the Children of the Glass to their deaths. He wants someone from outside to listen to Sel, and then to decide.',
    stages: [
      {txt: 'Hear the Prophet out, at the shrine on the Bowl\'s rim.', at: 'glass_camp', done: G => !!G.flags.met_sel},
      {txt: 'Decide what happens to the Children: help Sel open Silo 9, or turn the Children away from it.', at: 'glass_camp', done: G => !!G.flags.gc_end},
      {txt: 'Tell Brother Amon.', at: 'glass_camp'}],
    reward: G => G.flags.gc_end === 'saved' ? {xp: 380, caps: 60} : G.flags.gc_end === 'sel' ? {xp: 200, caps: 0} : {xp: 260, caps: 40}},
};

const T = (t, go, extra = {}) => Object.assign(go ? {t, go} : {t}, extra);
export const DIALOGUE = {
  // ---------------------------------------------------------------- Stillwater
  nell: {name: 'Nell Okafor', nodes: {
    hub: {say: G => G.flags.met_nell ? (G.questActive('still_waters') ? 'Well? What\'s in my water?' : 'Harbourmaster. What can I do for you?')
        : 'Stranger. You came down from Northgate, which means you\'ve walked a long way to look at a lake. I\'m Nell Okafor. I keep the harbour, the water ledger and the peace, in roughly that order.',
      opts: [
        T('Tell me about Stillwater.', 'town', {act: G => G.setFlag('met_nell', 1)}),
        T('You look like you\'ve had bad news.', 'fish', {if: G => !G.questKnown('still_waters'), act: G => G.setFlag('met_nell', 1)}),
        T('About the water.', 'water', {if: G => G.questActive('still_waters') && G.qStage('still_waters') < 3}),
        T('It\'s done. Silo 9.', 'end', {if: G => G.questActive('still_waters') && G.qStage('still_waters') === 3}),
        {t: 'Goodbye.', act: G => G.setFlag('met_nell', 1)}]},
    town: {say: 'Before the war it was a reservoir for a city that doesn\'t exist any more. After, it was the only water for forty miles that didn\'t glow. We fish it, filter it and sell it south by the barrel. Half the canteens in the valley were filled here, whether they know it or not.',
      opts: [T('And now?', 'fish', {if: G => !G.questKnown('still_waters')}), T('Good to know.', 'hub')]},
    fish: {say: 'Now the fish at the north end are coming up dead with green in their gills, and Mara\'s nets come up slick. If the south hears Stillwater water is going bad, we\'re finished long before the water is. I need someone who isn\'t a fisher to walk up to the inlet and look.',
      opts: [T('I\'ll go and look.', 'yes', {act: G => G.start('still_waters')}), T('What\'s it worth?', 'pay'), T('Not today.', 'hub')]},
    pay: {say: 'Two hundred and fifty chits, a barrel of clean water a month for as long as there\'s a Stillwater, and my personal opinion of you, which is currently "probably fine".',
      opts: [T('Deal.', 'yes', {act: G => G.start('still_waters')}), T('I\'ll think about it.', 'hub')]},
    yes: {say: 'The inlet\'s at the north end, where the stream comes down off the hills. There\'s an old pipe up there nobody\'s ever followed. Take a jar.',
      opts: [T('On my way.', 'hub', {act: G => G.give('purified_water', 2)})]},
    water: {say: G => G.qStage('still_waters') === 0 ? 'North inlet. The stream and the old pipe. Bring me something I can show the council.'
        : G.qStage('still_waters') === 1 ? 'Silo 9? That\'s the bomb hole east of here, the one the pilgrims sit around. If anybody knows what a silo leaks, it\'s Tobiah Fenn. He used to fix our pumps. The Highrisers took him to their tower in Old Meridian last month and want a fortune for him.'
        : 'So it\'s the silo. Then go and shut it. And come back, will you? We\'re short on people who come back.',
      opts: [T('I will.', 'hub')]},
    end: {say: G => G.flags.silo_end === 'shut' ? 'The inlet\'s running clear. Mara caught a perch this morning that wasn\'t the colour of a traffic light. You did that. Stillwater won\'t forget it, and neither will I.'
        : G.flags.silo_end === 'blown' ? 'We felt it here. The whole lake shivered. The inlet\'s clearing, slow. Whatever was down there is under a lot of rock now. I hope you knew what you were doing.'
        : 'The water\'s clearing. The pilgrims say the Bowl is glowing brighter than ever. I don\'t want to know what you traded for my fish, do I.',
      opts: [T('Your water\'s safe. That\'s what matters.', null, {act: G => { G.rep('stillwater', G.flags.silo_end === 'vent' ? 1 : 2); G.complete('still_waters'); }})]},
  }},
  gus: {name: 'Gus Pruitt', nodes: {
    hub: {say: G => G.flags.met_gus ? 'Back for more fish? Everybody comes back for the fish.' : 'Gus Pruitt, Stillwater Co-op. Water by the jug or the barrel, fish smoked or the other kind, and anything a fisher needs that isn\'t a better boat. Mara does boats.',
      opts: [
        T('Let\'s trade.', null, {act: G => { G.setFlag('met_gus', 1); G.openTrade('gus'); }}),
        T('How\'s business?', 'biz', {act: G => G.setFlag('met_gus', 1)}),
        {t: 'Goodbye.', act: G => G.setFlag('met_gus', 1)}]},
    biz: {say: G => G.questDone('still_waters') ? 'Booming. Water\'s clean, fish are fat, and every caravan from the south wants three barrels. I\'ve started charging extra for jugs with handles.' : 'Quiet. Too quiet. I\'ve stopped selling north-end fish and started selling "lake-style" jerky, which is jerky I\'ve told a story about.', opts: [T('Ha.', 'hub')]},
  }},
  mara: {name: 'Mara Lind', nodes: {
    hub: {say: 'Mind the hull, she\'s drying. Mara. I build the boats and mend the nets, and lately I pull dead fish out of them. What do you need?',
      opts: [T('What have you seen out on the water?', 'seen'), T('Nice boats.', 'boats'), T('Goodbye.')]},
    seen: {say: 'Green slick at the north end, mornings, like oil on a puddle. The gulls won\'t land on it. And at night, from the middle of the lake, you can see a glow over the hills to the east where the bomb hole is. It\'s brighter than it was last year.', opts: [T('Thanks.', 'hub')]},
    boats: {say: 'Flat-bottomed skiffs. Draw nothing, carry plenty, and they don\'t sink unless you ask them nicely. Sit in one sometime. It\'s the only quiet place left in the world.', opts: [T('Maybe I will.', 'hub')]},
  }},
  sw_guard: {name: 'Stillwater Watch', nodes: {
    hub: {say: 'Stillwater. Drink what you buy, fish where you\'re told, and don\'t piss in the lake. Everybody\'s downstream of somebody.', opts: [T('Fair enough.')]},
  }},
  sw_folk1: {name: 'Stillwater Fisher', nodes: {hub: {say: G => G.questDone('still_waters') ? 'The perch are back! Little ones, but back.' : 'Nets came up empty at the north end again. Empty and green.', opts: [T('Good luck.')]}}},
  sw_folk2: {name: 'Stillwater Fisher', nodes: {hub: {say: 'Shh. They can hear you through the boards. ...No, I don\'t know if that\'s true. My grandad said it.', opts: [T('...Right.')]}}},
  tobiah2: {name: 'Tobiah Fenn', nodes: {
    hub: {say: G => G.flags.silo_end ? 'The pumps are humming and the inlet\'s running clear. I\'m an old man fixing other people\'s pumps again. It\'s a good life. Thank you for it.' : 'Nell\'s given me a room over the co-op and a pump to fix. If you\'re going down to Silo 9, the codes are in your head now. Don\'t let the Prophet near that console.',
      opts: [T('Take care, Tobiah.')]},
  }},
  // ---------------------------------------------------------------- Old Meridian
  velma: {name: 'Velma Cruz', nodes: {
    hub: {say: G => G.flags.met_velma ? 'What do you need? Guns, bullets, or a reason to live? Only got the first two.' : 'Welcome to the Garage, the only roof in Old Meridian that isn\'t charging rent to the Duchess. Velma Cruz. I sell what kills things and buy what\'s left over.',
      opts: [
        T('Let\'s trade.', null, {act: G => { G.setFlag('met_velma', 1); G.openTrade('velma'); }}),
        T('Who\'s the Duchess?', 'duchess', {act: G => G.setFlag('met_velma', 1)}),
        T('Something wrong?', 'tobiah', {if: G => !G.questKnown('the_spire'), act: G => G.setFlag('met_velma', 1)}),
        T('Tobiah\'s out.', 'out', {if: G => G.questActive('the_spire') && G.flags.tobiahFree}),
        {t: 'Goodbye.', act: G => G.setFlag('met_velma', 1)}]},
    duchess: {say: 'The Duchess runs the Highrisers out of the Spire, the tallest thing standing in the city. She thinks the skyline is hers because she can see all of it. Everybody pays her rent. We pay in bullets, which she respects more than chits.',
      opts: [T('Good to know.', 'hub')]},
    tobiah: {say: 'Tobiah Fenn. Our engineer. Built the generator that runs this place, keeps our water pump spinning, taught half the kids in here to read off old manuals. The Highrisers grabbed him on a parts run and the Duchess wants six hundred chits. I\'ve got two.',
      opts: [T('I\'ll get him out.', 'yes', {act: G => G.start('the_spire')}), T('Six hundred is a lot.', 'hub')]},
    yes: {say: 'You\'re either brave or you haven\'t met her. The Spire\'s two blocks in, the tall one with the lobby lit. They let visitors in. Leaving is the trick.', opts: [T('I\'ll manage.', 'hub')]},
    out: {say: G => `He's out? He's... ${G.flags.spire_way === 'fought' ? 'and the Duchess is dead. The whole city heard. Nobody\'s going to miss her rent.' : 'and nobody had to die for it. I owe you.'} Here, from the Garage. Every one of us chipped in.`,
      opts: [T('Glad to help.', 'hub', {act: G => { G.karma(4, 'Freed Tobiah Fenn'); G.complete('the_spire'); }})]},
  }},
  gr_guard: {name: 'Garage Guard', nodes: {
    hub: {say: 'Inside the barricade it\'s Garage rules: no shooting, no stealing, no Highrisers. Outside it\'s the city\'s rules, and the city doesn\'t have any.', opts: [T('Understood.')]},
  }},
  tobiah: {name: 'Tobiah Fenn', nodes: {
    hub: {say: G => G.flags.tobiahTalked ? 'Still here. Still in a cage. Still very much hoping you\'re working on that.' : 'Oh, a face that isn\'t a Highriser\'s. Tobiah Fenn. Engineer, prisoner, enthusiast of fresh air. Did Velma send you?',
      opts: [
        T('Stillwater\'s water is being poisoned. A pipe stamped SILO 9 COOLANT.', 'silo', {if: G => G.questActive('still_waters') && G.qStage('still_waters') >= 1}),
        T('I\'m getting you out.', 'out'),
        T('Hang on.')]},
    silo: {say: 'Silo 9. God. When the warhead was safed they rigged a coolant purge so the core couldn\'t cook off: a pump that dumps the loop into the old drain line. Seventy years later, the drain line runs under the hills into your reservoir. Someone has to shut the purge from the launch console. You need a crew key or my override codes, and I\'m not giving codes through bars.',
      opts: [T('Then I\'ll get you out of the bars.', 'hub', {act: G => G.setFlag('tobiahTalked', 1)}), T('Where do I find a crew key?', 'key', {act: G => G.setFlag('tobiahTalked', 1)})]},
    key: {say: 'The guard robot at the silo carries one. The pilgrims call it the Iron Angel and pray to it, which is a terrible idea, because it shoots people who pray too close.', opts: [T('Noted.', 'hub')]},
    out: {say: 'Lovely. The Duchess has the only chain key, and she likes it more than she likes me. Of course, the padlock\'s pre-war and I could open it with a hairpin if anybody gave me one, which they haven\'t, because they\'re not idiots.', opts: [T('I\'ll see what I can do.', 'hub')]},
  }},
  duchess: {name: 'The Duchess', nodes: {
    hub: {say: G => G.flags.tobiahFree ? 'The engineer\'s gone. I hope you enjoyed being clever. Pay your rent on the way out.' : 'A tourist! Welcome to the Spire. Everything you can see from the roof is mine, including you, as of the moment you walked in. I\'m the Duchess. What brings you to my lobby?',
      opts: [
        T('I\'m here for Tobiah Fenn.', 'fenn', {if: G => !G.flags.tobiahFree}),
        T('Why the Spire?', 'why'),
        T('Goodbye.')]},
    why: {say: 'Because it\'s the tallest. When the world ended, everybody went down into holes. I went up. You can see a raider coming for an hour from up there, and you can see every fire in the city, and every fire is somebody I can charge.', opts: [T('Charming.', 'hub')]},
    fenn: {say: 'The engineer! My best investment this year. Six hundred chits. Non-negotiable, except when it is.',
      opts: [
        T('Here. Six hundred.', 'paid', {if: G => G.P.caps >= 600, act: G => { G.addCaps(-600); G.setFlag('spire_way', 'paid'); G.setFlag('tobiahFree', 1); G.give('duchess_token', 1); }}),
        T('He\'s worth more to you grateful than ransomed. Let him fix your generator and pay him in fish.', 'talk', {check: ['charm', 7]}),
        T('Six hundred chits for one old man? I\'ll give you four, and you\'ll take it.', 'haggle', {check: ['might', 7]}),
        T('Let him go or I start renting your lobby out to the crows.', 'fight')]},
    paid: {say: 'Pleasure. Take him. Mind the stairs, they\'re mostly ornamental. And have a token; it means you\'ve paid. For now.', opts: [T('Goodbye.')]},
    talk: {say: '...Fish. You want me to pay him in fish. ...My generator has been making that noise for three weeks. Fine. He goes, he comes back once a month and fixes my lights, and Stillwater sends me a barrel. You\'re a terrible influence.',
      opts: [T('Pleasure doing business.', null, {act: G => { G.setFlag('spire_way', 'talked'); G.setFlag('tobiahFree', 1); G.addXp(80); G.give('duchess_token', 1); }})]},
    haggle: {say: 'Four. You\'ve got eyes like a landlord. ...Four, then, and you never stand in my lobby looking at me like that again.',
      opts: [T('Four hundred.', null, {if: G => G.P.caps >= 400, act: G => { G.addCaps(-400); G.setFlag('spire_way', 'paid'); G.setFlag('tobiahFree', 1); }}), T('Never mind.', 'hub')]},
    fight: {say: 'Oh, I like you. Highrisers! Evict this one.',
      opts: [T('[Draw]', null, {act: G => { G.setFlag('spire_way', 'fought'); G.setFlag('hrWar', 1); G.makeHostile('hr0'); G.fight('duchess'); }})]},
  }},
  // ---------------------------------------------------------------- the Glass Bowl
  sel: {name: 'Prophet Sel', nodes: {
    hub: {say: G => G.flags.gc_end === 'sel' ? 'The Sleeper\'s breath is in the Bowl. Can you feel it? Warm. Warm as a hand.' : G.flags.met_sel ? 'You came back to the light. They always come back.' : 'Welcome, pilgrim, to the edge of grace. Down there, under the glass, the Sleeper waits. The old world built it to end the world. It refused. It lay down instead. I am Sel, and I listen to it dream.',
      opts: [
        T('Tell me about the Sleeper.', 'sleeper', {act: G => G.setFlag('met_sel', 1)}),
        T('What do you want from me?', 'want', {if: G => !G.flags.gc_end, act: G => G.setFlag('met_sel', 1)}),
        T('Here. The silo key.', 'key', {if: G => G.has('silo_key') && !G.flags.gc_end}),
        T('Your people are dying, Sel. Amon wrote it all down.', 'truth', {if: G => G.has('dosimeter_log') && !G.flags.gc_end}),
        {t: 'Goodbye.', act: G => G.setFlag('met_sel', 1)}]},
    sleeper: {say: 'A warhead, the scoffers say. Safed and sleeping. But look at the glass, pilgrim. Look at the light in the pools. Something down there is breathing. When the silo is opened, its breath will fill the Bowl and we will be changed, the way the glass was changed. Made clean.',
      opts: [T('Made dead, more like.', 'hub'), T('I see.', 'hub')]},
    want: {say: 'The Iron Angel guards the door and keeps the key. It will not let the faithful near. You are not faithful. It may let you near enough. Bring me the key and I will open the Sleeper\'s eye myself.',
      opts: [T('I\'ll think about it.', 'hub')]},
    key: {say: 'Oh... oh, pilgrim. Give it here. Tonight we walk down into the Bowl with lanterns, all of us, and I turn the Sleeper\'s eye to the sky. ...Thank you. You will be remembered as the one who carried grace.',
      opts: [T('It\'s yours.', null, {act: G => { G.take('silo_key', 1); G.setFlag('gc_end', 'sel'); G.setFlag('silo_end', 'vent'); G.rep('children', 3); G.karma(-6, 'Gave the Prophet the silo key'); G.msg('That night a line of lanterns winds down into the Glass Bowl. In the morning the pools are brighter, and the Stillwater inlet runs clear.'); }}),
        T('On second thought, no.', 'hub')]},
    truth: {say: 'Readings. Numbers. Amon has always loved numbers more than faith. ...Eleven names. I knew all of them. I... I told them it was grace.',
      opts: [
        T('It wasn\'t. Take them out of the Bowl, Sel. Take them to Stillwater. Nell will feed them.', 'saved', {check: ['charm', 7]}),
        T('Then you killed them.', 'snap')]},
    saved: {say: '...Yes. Yes. The Sleeper never spoke. I spoke, and called it the Sleeper because no one would listen to Sel. We will go. Tomorrow, all of us. Will you tell the woman at the lake we\'re coming? We\'ll work. We know how to carry water.',
      opts: [T('I\'ll tell her.', null, {act: G => { G.take('dosimeter_log', 1); G.setFlag('gc_end', 'saved'); G.setFlag('gcLeft', 1); G.rep('children', 2); G.rep('stillwater', 1); G.karma(8, 'Led the Children out of the Bowl'); }})]},
    snap: {say: 'Liar! Heretic! The Sleeper sees you! Wardens!',
      opts: [T('[Draw]', null, {act: G => { G.setFlag('gc_war', 1); G.fight('sel'); }})]},
  }},
  amon: {name: 'Brother Amon', nodes: {
    hub: {say: G => G.flags.gc_end === 'saved' ? 'They\'re packing. All of them. Sel too. I\'ve been trying to find a word for what I feel and the only one I\'ve got is "lighter".'
        : G.flags.gc_end === 'sel' ? 'You gave him the key. ...I suppose I knew someone would. I\'ll stay. Somebody has to bury them.'
        : G.flags.npcDead_sel ? 'The Prophet is dead. The others are lost without him, but they\'re alive, and lost can be fixed.'
        : 'Keep your voice down. I am Amon. I believed, once. Then I found an old dosimeter in the silo\'s guard hut and I started counting. Will you hear me?',
      opts: [
        T('I\'m listening.', 'count', {if: G => !G.questKnown('children_of_glass')}),
        T('It\'s decided.', 'done', {if: G => G.questActive('children_of_glass') && (G.flags.gc_end || G.flags.npcDead_sel)}),
        T('Goodbye.')]},
    count: {say: 'Eleven pilgrims in three months. Hair first, then gums, then they stop eating. Sel calls it "being changed". The dosimeter calls it four hundred rads. He wants the silo opened. If he opens it, there won\'t be anyone left to change. Talk to him. Then decide. You\'re the only one here who isn\'t afraid of him.',
      opts: [T('Give me the log. I\'ll talk to him.', 'hub', {act: G => { G.give('dosimeter_log', 1); G.start('children_of_glass'); }}), T('Not my fight.', 'hub')]},
    done: {say: G => G.flags.gc_end === 'saved' ? 'Thank you. Truly. Here, it\'s not much. The Children have never had much. That was rather the point.' : 'It\'s done, then. Whatever comes, you looked at it with open eyes, which is more than most of us managed.',
      opts: [T('Goodbye, Amon.', null, {act: G => { if (!G.flags.gc_end) G.setFlag('gc_end', 'dead'); G.give('glass_shard', 1); G.complete('children_of_glass'); }})]},
  }},
  gc_guard: {name: 'Glass Warden', nodes: {hub: {say: 'Walk softly on the rim, pilgrim. The glass remembers every footstep.', opts: [T('All right.')]}}},
  gc_folk1: {name: 'Child of the Glass', nodes: {hub: {say: 'Have you looked down into the Bowl at night? The pools shine like a city. Like the city must have looked.', opts: [T('I\'ll look.')]}}},
  gc_folk2: {name: 'Child of the Glass', nodes: {hub: {say: 'My hair came out this morning. The Prophet says it means the Sleeper has noticed me.', opts: [T('...I\'m sorry.')]}}},
  gc_folk3: {name: 'Child of the Glass', nodes: {hub: {say: 'Nell says I can mend nets. I\'ve never mended anything. Everything\'s been breaking for so long.', opts: [T('You\'ll learn.')]}}},
  // ---------------------------------------------------------------- the console at the bottom of the Bowl
  silo_console: {name: 'Silo 9 Launch Console', nodes: {
    hub: {say: G => G.flags.silo_end === 'shut' ? 'SILO 9 :: STANDBY\nCOOLANT PURGE ........ SEALED\nCORE TEMPERATURE ...... NOMINAL\nWARHEAD ............... SAFED'
        : G.flags.silo_end ? 'SILO 9 :: NO CARRIER' : 'SILO 9 :: STANDBY  (DAY 26,447)\nCOOLANT PURGE ........ ACTIVE  > DRAIN LINE 4\nCORE TEMPERATURE ...... NOMINAL\nWARHEAD ............... SAFED\n\nTWO-MAN RULE IN EFFECT. ONE KEY DETECTED.',
      opts: [
        T('Seal the coolant purge.', 'shut', {if: G => !G.flags.silo_end, act: G => { G.setFlag('silo_end', 'shut'); G.karma(5, 'Sealed the Silo 9 purge'); G.addXp(60); }}),
        T('Redirect the purge into the Bowl instead of the drain line.', 'vent', {if: G => !G.flags.silo_end, act: G => { G.setFlag('silo_end', 'vent'); G.rep('children', 1); }}),
        T('Run the core past its limits and bury the silo.', 'blown', {check: ['intellect', 8], if: G => !G.flags.silo_end, act: G => { G.setFlag('silo_end', 'blown'); G.addXp(120); }}),
        T('Step away from the console.')]},
    shut: {say: 'PURGE VALVE 4 ........ CLOSED\nLOOP PRESSURE ......... RISING\nRECIRCULATION ......... ENGAGED\n\nSomewhere under your feet, a pump that has run for seventy years stops.', opts: [T('Step away from the console.')]},
    vent: {say: 'PURGE ROUTED > SURFACE VENTS 1-4\n\nOutside, the pools in the Bowl begin to bubble and glow brighter. The drain line under the hills runs dry.', opts: [T('Step away from the console.')]},
    blown: {say: 'CORE TEMPERATURE ...... 412%\nCONTAINMENT ........... FAILING\nSILO DOORS ............ SEALING\n\nYou have about four minutes to be somewhere else. The silo is going to fold itself into the earth.',
      opts: [T('Run.', null, {act: G => G.msg('The ground shudders as Silo 9 collapses into itself. A long breath of dust rolls out of the Bowl.')})]},
  }},
};

export const POINTS = {
  sw_inlet: {label: pt => G.questActive('still_waters') && !G.has('slag_sample') ? 'Scoop sludge from the inlet' : null,
    use: pt => { G.give('slag_sample', 1); G.msg('Black-green sludge oozes from a split pipe in the stream bank. The flange is stamped SILO 9 COOLANT - DRAIN LINE 4.'); checkQuests(); }},
  spire_cage: {label: pt => !G.flags.tobiahFree && G.has('bobby_pin') && G.flags.tobiahTalked ? 'Pick the cage\'s padlock' : null,
    use: pt => { G.take('bobby_pin', 1); G.setFlag('spire_way', 'picked'); G.setFlag('tobiahFree', 1); G.addXp(60); G.msg('The old padlock gives with a click. Tobiah slips out and down the stairs without a word.'); checkQuests(); }},
  silo_wreck: {label: pt => G.killed('silobot') && !G.has('silo_key') && !G.flags.silo_end && !G.flags.gc_end ? 'Search the Iron Angel\'s wreck' : null,
    use: pt => { G.give('silo_key', 1); G.msg('A steel key on a beaded chain, wired inside the robot\'s chest plate.'); checkQuests(); }},
  silo_desk: {label: pt => !G.flags.silo_end ? (G.has('silo_key') || G.flags.tobiahCodes ? 'Use the launch console' : 'The console wants a key') : 'Look at the console',
    use: pt => { if (G.has('silo_key') || G.flags.tobiahCodes || G.flags.silo_end) G.talk('silo_console'); else G.msg('The console is dark except for one line: INSERT CREW KEY.'); }},
};
export const WORLD_POINTS = [
  {id: 'sw_inlet', x: -215, z: -852, r: 3.2},
  {id: 'spire_cage', x: 438.5, z: -797.4, r: 2.2},
  {id: 'silo_wreck', x: 1157, z: -795, r: 3.5},
  {id: 'silo_desk', x: 1146, z: -804.4, r: 2.4},
];

const E = (id, type, x, z, extra = {}) => Object.assign({id, type, x, z, always: true}, extra);
export const SPAWNS = [
  E('hr0', 'raider', 441, -806, {name: 'Highriser', neutral: true, group: 'hr', unless: 'hrGone'}),
  E('hr1', 'raider', 451, -806, {name: 'Highriser', neutral: true, group: 'hr', unless: 'hrGone'}),
  E('hr2', 'marauder', 444, -820, {name: 'Highriser', neutral: true, group: 'hr', unless: 'hrGone'}),
  E('hr3', 'raider', 462, -818, {name: 'Highriser', neutral: true, group: 'hr', unless: 'hrGone'}),
  E('hr4', 'sniper', 432, -788, {name: 'Highriser Lookout', neutral: true, group: 'hr', unless: 'hrGone'}),
  E('om0', 'ghoul', 370, -726), E('om1', 'ghoul', 522, -770), E('om2', 'ghoul', 320, -816), E('om3', 'ghoul', 500, -860), E('om4', 'glowhusk', 395, -860), E('om5', 'ghoul', 545, -700),
  E('gb0', 'glowhusk', 1110, -770), E('gb1', 'ghoul', 1190, -760), E('gb2', 'ghoul', 1120, -820), E('gb3', 'glowhusk', 1185, -825), E('gb4', 'ghoul', 1095, -740),
  E('silobot', 'guardbot', 1157, -795, {name: 'Iron Angel'}),
  E('nw0', 'hound', -300, -660), E('nw1', 'hound', -306, -664), E('nw2', 'boar', 120, -900), E('nw3', 'boar', 126, -905), E('nw4', 'vulture', 700, -700),
  E('nw5', 'stalker', 860, -900), E('nw6', 'radscorp', 980, -640), E('nw7', 'jackal', 40, -620), E('nw8', 'jackal', 46, -626), E('nw9', 'tusker', -360, -900),
];

export const TRIGGERS = [
  {if: G => G.flags.tobiahFree && !G.flags.tobiahCodes, do: G => { G.setFlag('tobiahCodes', 1); G.msg('Tobiah, on his way out: "Silo 9 override: seven-four-nine-alpha. Seal the purge. Not the vents. The SEAL."'); }},
  {if: G => G.visited('glass_bowl') && !G.flags.gb_hello, do: G => { G.setFlag('gb_hello', 1); G.setFlag('radio', 'glass_sermon'); }},
  {if: G => G.flags.hrWar && G.flags.npcDead_duchess && !G.flags.tobiahFree, do: G => { G.setFlag('tobiahFree', 1); G.msg('With the Duchess dead, Tobiah works the chain loose himself.'); }},
  {if: G => G.flags.gc_war && G.flags.npcDead_sel && !G.flags.gc_end, do: G => G.setFlag('gc_end', 'dead')},
  {if: G => G.flags.gc_end === 'sel' && !G.flags.silo_end, do: G => G.setFlag('silo_end', 'vent')},
];
export const RADIO = {
  glass_sermon: {h: 'SHORTWAVE: THE GLASS BOWL', who: 'sel', t: `> PROPHET SEL — THE RIM OF GRACE

Pilgrims. Listen. Under the glass, the Sleeper dreams.

The old world built it to burn the world, and it would not. It lay down in the dark and made the ground around it into glass, so that we could see our faces in it.

Come to the rim. Bring nothing. Leave your counters and your fears in the valley. The light in the pools is not poison. It is attention.

One day soon its eye will open. Be here when it does.

> END`},
};
export const EPILOGUE = [
  {if: G => G.flags.silo_end === 'shut', t: 'Silo 9\'s purge stayed sealed. Within a year the perch were back at Stillwater\'s north inlet, and Stillwater barrels were sold from the Kettle to the Ashwood with a little fish painted on the lid.'},
  {if: G => G.flags.silo_end === 'vent', t: 'The coolant poured into the Glass Bowl instead of the reservoir. Stillwater\'s water ran clear, the pools in the crater glowed brighter every year, and nobody who went down to look at them came back the same.'},
  {if: G => G.flags.silo_end === 'blown', t: 'Silo 9 folded itself into the earth. The Glass Bowl is a lake now, a green one, and nobody drinks from it, and nobody prays to it either.'},
  {if: G => G.flags.gc_end === 'saved', t: 'The Children of the Glass came to Stillwater with their lanterns and nothing else. Sel mends nets now, badly. He never speaks of the Sleeper, but he still faces east when he eats.'},
  {if: G => G.flags.gc_end === 'sel', t: 'Prophet Sel opened the Sleeper\'s eye and nothing woke. The Children stayed on the rim, fewer every season, until only Brother Amon was left to keep the graves.'},
  {if: G => G.flags.npcDead_sel, t: 'Without their Prophet the Children of the Glass scattered across the north. Brother Amon kept his dosimeter, and kept counting, and wrote to anyone who would read it.'},
  {if: G => G.flags.spire_way === 'talked', t: 'Tobiah Fenn kept the Spire\'s lights on once a month, paid in Stillwater fish. The Duchess called it "a cultural exchange" and never once raised his rent.'},
  {if: G => G.flags.spire_way === 'fought', t: 'With the Duchess gone, the Spire stood empty, and then full of pigeons, and then full of Garage families who liked a view. The Highrisers were never seen again in Old Meridian.'},
  {if: G => G.flags.tobiahFree && G.flags.spire_way !== 'fought', t: 'The Garage\'s generator never failed again. Tobiah Fenn taught three apprentices before he died, and every one of them could open a pre-war padlock with a hairpin.'},
];
