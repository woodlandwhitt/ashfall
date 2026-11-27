// Build 20 story layer: three places on the empty stretches (scripts/frontier.gd _ruins20 builds them).
//
// Wayside 9, a fuel stop on the old north-east highway that raiders have made a toll post of; Holloway Farm, burnt
// out west of Northgate, with the dead still walking its fields; Relay Station K, a signals post in the Ashwood's
// south whose sentry robots never got the order to stand down.

const E = (id, type, x, z, extra = {}) => Object.assign({id, type, x, z, always: true}, extra);

export const LOCS = {
  wayside: {name: 'Wayside 9', x: 900, z: -600, r: 30},
  holloway: {name: 'Holloway Farm', x: -300, z: -600, r: 30},
  relay_k: {name: 'Relay Station K', x: 1000, z: 100, r: 24},
};

export const SPAWNS = [
  E('ws0', 'raider', 896, -596, {name: 'Wayside Tollman'}),
  E('ws1', 'raider', 905, -599, {name: 'Wayside Tollman'}),
  E('ws2', 'marauder', 900, -614, {name: 'Toll Boss'}),
  E('ws3', 'sniper', 911, -590, {name: 'Wayside Lookout'}),
  E('hf0', 'ghoul', -302, -594), E('hf1', 'ghoul', -294, -603), E('hf2', 'ghoul', -308, -610), E('hf3', 'hound', -290, -588),
  E('rk0', 'sentry', 996, 108), E('rk1', 'sentry', 1005, 108),
];
