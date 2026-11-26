// Build 18 story layer: Silo 9 made real (scripts/silo.gd does the world's part).
//
// The console now follows the two-man rule: the crew key from the Iron Angel AND Tobiah Fenn's override codes are
// both needed to launch. Launch, and the missile really leaves: a forty-five second count, the climb out of the
// Bowl, and an airburst over the old test range forty kilometres north-east. The purge loop closes for launch, so
// Stillwater's water clears either way, but the burst's ash blows back over the north: The Ash Wind (warn Nell,
// shut the reservoir's sluice, get the Children of the Glass under a roof, wait it out). Scuttle the core instead and
// you have ninety seconds to be out of the Bowl's floor.

export const ITEMS = {};

export const QUESTS = {
  ash_wind: {t: 'The Ash Wind',
    desc: 'Silo 9\'s missile burst over the old test range, forty kilometres north-east, and the wind is bringing the ash back over the north.',
    stages: [
      {txt: 'Warn Nell Okafor in Stillwater before the ash comes down on the reservoir.', at: 'stillwater', done: G => !!G.flags.ash_warned},
      {txt: 'Shut the old sluice gate at the reservoir\'s north inlet, so the ash-laden stream doesn\'t run into the lake.', at: 'reservoir', done: G => !!G.flags.sluice_shut},
      {txt: 'Get the Children of the Glass under a roof: tell Brother Amon to bring them to Stillwater.', at: 'glass_camp', done: G => !!G.flags.children_sheltered || !!G.flags.gcLeft || !!G.flags.npcDead_amon},
      {txt: 'Wait out the ash (it falls for a day) and then see Nell.', at: 'stillwater', done: G => !!G.flags.ash_over},
      {txt: 'Talk to Nell.', at: 'stillwater'}],
    reward: {xp: 420, caps: 150}},
};

const T = (t, go, extra = {}) => Object.assign(go ? {t, go} : {t}, extra);
export const DIALOGUE = {
  silo_console: {name: 'Silo 9 Launch Console', nodes: {
    hub: {say: G => G.flags.silo_end === 'shut' ? 'SILO 9 :: STANDBY\nCOOLANT PURGE ........ SEALED\nCORE TEMPERATURE ...... NOMINAL\nWARHEAD ............... SAFED'
        : G.flags.silo_end === 'launched' ? 'SILO 9 :: TUBE EMPTY\nLAUNCH ................ COMPLETE\nCOOLANT LOOP .......... CLOSED\n\nThe screens show a long green line climbing off the top of a plot and not coming back.'
        : G.flags.silo_end ? 'SILO 9 :: NO CARRIER'
        : 'SILO 9 :: STANDBY  (DAY 26,447)\nCOOLANT PURGE ........ ACTIVE  > DRAIN LINE 4\nCORE TEMPERATURE ...... NOMINAL\nWARHEAD ............... SAFED\n\nTWO-MAN RULE IN EFFECT.\nCREW KEY .............. ' + (G.has('silo_key') ? 'DETECTED' : 'ABSENT') + '\nOVERRIDE .............. ' + (G.flags.tobiahCodes ? 'ON FILE (749-ALPHA)' : 'NONE'),
      opts: [
        T('Seal the coolant purge.', 'shut', {if: G => !G.flags.silo_end, act: G => { G.setFlag('silo_end', 'shut'); G.karma(5, 'Sealed the Silo 9 purge'); G.addXp(60); }}),
        T('Redirect the purge into the Bowl instead of the drain line.', 'vent', {if: G => !G.flags.silo_end, act: G => { G.setFlag('silo_end', 'vent'); G.rep('children', 1); }}),
        T('Bring up the launch sequence.', 'launch', {if: G => !G.flags.silo_end}),
        T('Run the core past its limits and bury the silo.', 'blown', {check: ['intellect', 8], if: G => !G.flags.silo_end,
          act: G => { G.setFlag('silo_end', 'blown'); G.setFlag('silo_seq', 'scuttle'); G.setFlag('silo_buried', 1); G.addXp(120); }}),
        T('Step away from the console.')]},
    shut: {say: 'PURGE VALVE 4 ........ CLOSED\nLOOP PRESSURE ......... RISING\nRECIRCULATION ......... ENGAGED\n\nSomewhere under your feet, a pump that has run for seventy years stops.', opts: [T('Step away from the console.')]},
    vent: {say: 'PURGE ROUTED > SURFACE VENTS 1-4\n\nOutside, the pools in the Bowl begin to bubble and glow brighter. The drain line under the hills runs dry.', opts: [T('Step away from the console.')]},
    launch: {say: G => (G.has('silo_key') && G.flags.tobiahCodes)
        ? 'LAUNCH AUTHORISATION\nCREW KEY .............. TURNED\nOVERRIDE 749-ALPHA .... ACCEPTED\n\nTARGET PACKAGE ........ CORRUPT\nFALLBACK .............. TEST RANGE 7\n                        40 KM NNE, UNINHABITED (1987 SURVEY)\nWARHEAD ............... ARMED FOR AIRBURST\nCOOLANT LOOP .......... WILL CLOSE FOR LAUNCH\n\nCONFIRM?'
        : 'LAUNCH AUTHORISATION\n\nTWO-MAN RULE: ONE KEY AND ONE AUTHENTICATED OVERRIDE ARE REQUIRED.\n' + (G.has('silo_key') ? 'KEY: TURNED.  OVERRIDE: NONE ON FILE.' : G.flags.tobiahCodes ? 'OVERRIDE: ON FILE.  KEY: ABSENT.' : 'KEY: ABSENT.  OVERRIDE: NONE ON FILE.'),
      opts: [
        T('[Confirm] Launch the missile.', null, {if: G => G.has('silo_key') && !!G.flags.tobiahCodes,
          act: G => { G.take('silo_key', 1); G.setFlag('silo_end', 'launched'); G.setFlag('silo_seq', 'launch'); G.setFlag('silo_launched', 1); G.karma(-4, 'Launched Silo 9\'s missile'); G.addXp(150);
            G.msg('A klaxon starts somewhere above you. Forty-five seconds. Get clear of the hatch.'); }}),
        T('Back away from the console.', 'hub')]},
    blown: {say: 'CORE TEMPERATURE ...... 412%\nCONTAINMENT ........... FAILING\nSILO DOORS ............ SEALING\n\nNinety seconds. Get out of the Bowl\'s floor. Now.', opts: [T('Run.')]},
  }},
  nell: {name: 'Nell Okafor', nodes: {
    hub: {say: G => G.questActive('ash_wind') && !G.flags.ash_warned ? 'You\'re white as a sheet. What did you see out east?'
        : G.flags.met_nell ? (G.questActive('still_waters') ? 'Well? What\'s in my water?' : 'Harbourmaster. What can I do for you?')
        : 'Stranger. You came down from Northgate, which means you\'ve walked a long way to look at a lake. I\'m Nell Okafor. I keep the harbour, the water ledger and the peace, in roughly that order.',
      opts: [
        T('Tell me about Stillwater.', 'town', {act: G => G.setFlag('met_nell', 1)}),
        T('You look like you\'ve had bad news.', 'fish', {if: G => !G.questKnown('still_waters'), act: G => G.setFlag('met_nell', 1)}),
        T('About the water.', 'water', {if: G => G.questActive('still_waters') && G.qStage('still_waters') < 3}),
        T('It\'s done. Silo 9.', 'end', {if: G => G.questActive('still_waters') && G.qStage('still_waters') === 3}),
        T('The flash in the north-east. It was the silo. Ash is coming.', 'ash', {if: G => G.questActive('ash_wind') && !G.flags.ash_warned}),
        T('The ash has stopped.', 'ash_done', {if: G => G.questActive('ash_wind') && !!G.flags.ash_over}),
        {t: 'Goodbye.', act: G => G.setFlag('met_nell', 1)}]},
    end: {say: G => G.flags.silo_end === 'shut' ? 'The inlet\'s running clear. Mara caught a perch this morning that wasn\'t the colour of a traffic light. You did that. Stillwater won\'t forget it, and neither will I.'
        : G.flags.silo_end === 'blown' ? 'We felt it here. The whole lake shivered. The inlet\'s clearing, slow. Whatever was down there is under a lot of rock now. I hope you knew what you were doing.'
        : G.flags.silo_end === 'launched' ? 'The inlet\'s clearing. And the whole north saw that light. Children were screaming in the street. You fired it, didn\'t you. ...I won\'t ask why. My water\'s clean. I\'ll be a long while deciding how I feel about the rest.'
        : 'The water\'s clearing. The pilgrims say the Bowl is glowing brighter than ever. I don\'t want to know what you traded for my fish, do I.',
      opts: [T('Your water\'s safe. That\'s what matters.', null, {act: G => { G.rep('stillwater', G.flags.silo_end === 'vent' || G.flags.silo_end === 'launched' ? 1 : 2); G.complete('still_waters'); }})]},
    ash: {say: 'Ash. On the lake. God. ...All right. Mara, get the boats in. Gus, every jug and barrel under canvas. And you: the old sluice at the north inlet. If the stream brings ash down off the hills straight into the lake, we lose a year. Can you shut it? It hasn\'t moved since my mother\'s time.',
      opts: [T('I\'ll shut it.', 'hub', {act: G => G.setFlag('ash_warned', 1)})]},
    ash_done: {say: 'It came down grey for a day and a night, like dirty snow. The lake kept clean behind the sluice. The pilgrims slept in the boathouse and nobody died. ...That\'s more than I expected when I saw that light. Thank you.',
      opts: [T('Glad Stillwater\'s safe.', 'hub', {act: G => { G.rep('stillwater', 2); G.karma(4, 'Sheltered the north from the ash'); G.complete('ash_wind'); }})]},
  }},
  amon: {name: 'Brother Amon', nodes: {
    hub: {say: G => G.questActive('ash_wind') && !G.flags.children_sheltered && !G.flags.gcLeft ? 'The Prophet says the Sleeper woke and rose to heaven. They\'re dancing on the rim. And the counter in my hand won\'t stop clicking.'
        : G.flags.gc_end === 'saved' ? 'They\'re packing. All of them. Sel too. I\'ve been trying to find a word for what I feel and the only one I\'ve got is "lighter".'
        : G.flags.gc_end === 'sel' ? 'You gave him the key. ...I suppose I knew someone would. I\'ll stay. Somebody has to bury them.'
        : G.flags.npcDead_sel ? 'The Prophet is dead. The others are lost without him, but they\'re alive, and lost can be fixed.'
        : 'Keep your voice down. I am Amon. I believed, once. Then I found an old dosimeter in the silo\'s guard hut and I started counting. Will you hear me?',
      opts: [
        T('I\'m listening.', 'count', {if: G => !G.questKnown('children_of_glass')}),
        T('It\'s decided.', 'done', {if: G => G.questActive('children_of_glass') && (G.flags.gc_end || G.flags.npcDead_sel)}),
        T('The ash is coming down tonight. Get everyone to Stillwater. Nell will take them.', 'ash', {if: G => G.questActive('ash_wind') && !G.flags.children_sheltered && !G.flags.gcLeft}),
        T('Goodbye.')]},
    ash: {say: 'Tonight. ...Yes. Yes. If I tell them the Sleeper wants them under a roof, they\'ll go. It\'s a lie, but it\'s the kind that keeps people alive. God forgive me, I\'m learning from Sel.',
      opts: [T('Go. Quickly.', null, {act: G => { G.setFlag('children_sheltered', 1); G.setFlag('gcLeft', 1); G.msg('A line of lanterns sets out west along the rim road toward Stillwater.'); }})]},
  }},
};

export const POINTS = {
  sw_sluice: {label: pt => G.questActive('ash_wind') && !!G.flags.ash_warned && !G.flags.sluice_shut ? 'Wind the old sluice gate shut' : null,
    use: pt => { G.setFlag('sluice_shut', 1); G.addXp(50); G.msg('The wheel won\'t move, then moves all at once. The gate grinds down into the stream bed and the water backs up behind it, brown and slow.'); checkQuests(); }},
};
export const WORLD_POINTS = [
  {id: 'sw_sluice', x: -209.0, z: -846.0, r: 3.0},
];

export const TRIGGERS = [
  // the burst (silo.gd sets silo_burst): the north hears it on the radio, and the ash wind begins
  {if: G => !!G.flags.silo_burst && !G.questKnown('ash_wind'), do: G => { G.start('ash_wind'); G.setFlag('ash_day', G.day); G.setFlag('radio', 'ash_alert'); }},
  {if: G => G.questActive('ash_wind') && !!G.flags.sluice_shut && G.day > (G.flags.ash_day || 0) && !G.flags.ash_over, do: G => G.setFlag('ash_over', 1)},
  // launched while the Children were still on the rim: they think the Sleeper flew
  {if: G => G.flags.silo_end === 'launched' && !G.flags.gc_end && G.questActive('children_of_glass'), do: G => G.setFlag('gc_end', 'flown')},
];
export const RADIO = {
  ash_alert: {h: 'MERIDIAN FREE RADIO — EMERGENCY', who: 'radio', t: `> MERIDIAN FREE RADIO — EMERGENCY NOTICE

Folks, if you saw the flash to the north-east: you're not dreaming, and you're not dead. Something went up out of the Glass Bowl and came down a long, long way off.

What goes up that high comes down as ash. If you're north of Northgate, get under a roof for a day. Cover your water. Don't eat anything that's been sitting out.

Everybody else: stay south of the Northgate road until this station says otherwise.

> END`},
};
export const EPILOGUE = [
  {if: G => G.flags.silo_end === 'launched', t: 'Silo 9\'s missile burst over a test range nobody had seen in two hundred years. The north had a grey day and a frightened night, and then the wind turned. The crater it left forty kilometres out is the valley\'s new horizon, and children there still point at it and ask.'},
  {if: G => G.questDone('ash_wind'), t: 'Stillwater\'s sluice gate was never opened again. The lake behind it kept clean through the ash, and Nell Okafor had the wheel painted red so nobody would forget why.'},
  {if: G => G.flags.gc_end === 'flown', t: 'The Children of the Glass believed to the last that the Sleeper had woken and flown home. Brother Amon let them believe it, and led them to Stillwater, and kept counting.'},
];
