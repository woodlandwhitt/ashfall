// Build 12 story layer: the seventh S.P.E.C.I.A.L. letter (Intelligence) gets things to say.
export const DIALOGUE = {
  pell: {nodes: {
    i_loop: {say: 'A coolant bypass loop? ...You know, that would buy the old regulator a week, maybe ten days, if nobody breathes on it. It won\'t save us. It\'ll give you more time to find the part. Hand me that spanner. And go, before I start liking you.',
      opts: [{t: 'Every day counts.', act: G => { G.setFlag('pellLoop', 1); G.addXp(60); }}]},
  }},
  halloran: {nodes: {
    i_metal: {say: 'Heavy metals? From the pipes? ...Grey gums, tremor, the ringing ears. You\'re right, and I\'ve been treating half of Dustwell for the wrong thing. Here. Take these for your trouble, and I\'ll start boiling the town\'s water through charcoal.',
      opts: [{t: 'Glad to help.', go: 'hub', act: G => { G.setFlag('halloranMetal', 1); G.give('radaway', 1); G.give('stimpak', 2); G.addXp(50); G.karma(2, 'Spotted the lead in the water'); }}]},
  }},
  wick: {nodes: {
    i_ant: {say: 'Impedance mismatch. Of course it is. I\'ve been shouting into a pillow for a month. ...Look at that: half the noise gone. You want a job? No? Then take these, I\'ve got spares, and I owe you a song.',
      opts: [{t: 'Happy listening.', go: 'hub', act: G => { G.setFlag('wickAntenna', 1); G.give('circuit', 2); G.addCaps(60); G.addXp(50); }}]},
  }},
};
export const INJECT = [
  {npc: 'pell', node: 'hub', opts: [
    {t: 'What if we looped the coolant around the cracked housing?', check: ['intellect', 7], if: G => !G.flags.pellLoop && !G.flags.leftVault, go: 'i_loop'}]},
  {npc: 'halloran', node: 'hub', opts: [
    {t: 'Those symptoms aren\'t radiation. Grey gums, tremors: that\'s lead from the old pipes.', check: ['intellect', 6], if: G => !G.flags.halloranMetal, go: 'i_metal'}]},
  {npc: 'wick', node: 'hub', opts: [
    {t: 'Your antenna\'s impedance is wrong for that cable. Swap the matching coil.', check: ['intellect', 7], if: G => !G.flags.wickAntenna, go: 'i_ant'}]},
];
