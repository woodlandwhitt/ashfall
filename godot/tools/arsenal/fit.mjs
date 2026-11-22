// how each new gun model sits in the hand: scale (k), turn (ry), first-person size (s), eye relief (rear),
// sight height (sight), one-handed (pistol), the fallback pose (fb); and GRIPS as in Humanoid: [grip along from the
// back, down from the top, support hand along, down], read off tools/gunside.tscn renders
const P = (s, g, o = {}) => ({fit: {s, rear: .07, sight: .07, pistol: 1, fb: 'pistol', ...o}, grip: g});
const L = (s, rear, g, o = {}) => ({fit: {s, rear, sight: .075, fb: 'rifle', ...o}, grip: g});
const M = {
  'lp_pistol': P(1.25, [0.13, 0.5]),
  'lp_derringer': P(1.3, [0.12, 0.55], {sight: .06}),
  'lp_revolver': P(1.2, [0.12, 0.55], {fb: 'pistol2'}),
  'lp_machine_pistol': P(1.2, [0.11, 0.55]),
  'lp_smg': L(1.1, .22, [0.38, 0.62, 0.68, 0.65], {fb: 'smg'}),
  'lp_carbine': L(1.08, .28, [0.39, 0.6, 0.71, 0.3], {fb: 'carbine'}),
  'lp_rifle': L(1.05, .3, [0.31, 0.62, 0.69, 0.4]),
  'lp_burst_rifle': L(1.05, .3, [0.29, 0.62, 0.63, 0.35], {fb: 'carbine'}),
  'lp_battle_rifle': L(1.02, .3, [0.40, 0.62, 0.66, 0.4]),
  'lp_bullpup': L(1.08, .26, [0.44, 0.62, 0.76, 0.42], {fb: 'carbine', sight: .08}),
  'lp_marksman': L(1.0, .3, [0.24, 0.62, 0.6, 0.35], {sight: .085}),
  'lp_sniper': L(0.95, .32, [0.21, 0.55, 0.57, 0.5], {sight: .09}),
  'lp_shotgun': L(1.05, .3, [0.10, 0.6, 0.53, 0.45], {fb: 'shotgun', sight: .065}),
  'lp_drum_shotgun': L(1.05, .3, [0.33, 0.65, 0.72, 0.35], {fb: 'shotgun'}),
  'lp_minigun': L(1.0, .3, [0.10, 0.75, 0.28, 0.05], {fb: 'shotgun', sight: .06}),
  'lp_launcher': L(1.0, .3, [0.49, 0.72, 0.68, 0.72], {sight: .09}),
  'lp_charge_rifle': L(1.0, .3, [0.33, 0.6, 0.52, 0.35], {sight: .08}),
  'lp_beamer': L(1.05, .26, [0.21, 0.62, 0.55, 0.4], {fb: 'carbine'}),
};
const B = (x, k, g, pistol, o = {}) => {
  // the kit's blasters are toy-chunky: slimmed across and in height, kept long
  M['bl/blaster_' + x] = pistol ? {fit: {k, kv: [k * 0.68, k * 0.68, k * 0.85], ry: 0, s: 1.15, rear: .07, sight: .07, pistol: 1, fb: 'pistol', ...o}, grip: g}
    : {fit: {k, kv: [k * 0.62, k * 0.62, k * 0.95], ry: 0, s: 1.0, rear: .1, sight: .05, fb: 'carbine', ...o}, grip: g};
};
B('a', 0.9, [0.3, 0.55, 0.7, 0.6]);
B('b', 0.8, [0.18, 0.6], true);
B('c', 0.8, [0.13, 0.6], true);
B('d', 0.9, [0.34, 0.6, 0.77, 0.7]);
B('e', 0.85, [0.29, 0.62, 0.64, 0.5], false, {fb: 'rifle'});
B('f', 0.85, [0.22, 0.65, 0.52, 0.55], false, {fb: 'rifle'});
B('g', 0.9, [0.19, 0.62, 0.7, 0.55]);
B('h', 0.9, [0.10, 0.6, 0.6, 0.45], false, {fb: 'smg'});
B('i', 0.8, [0.44, 0.6], true);
B('j', 0.8, [0.12, 0.6], true);
B('k', 0.8, [0.13, 0.6], true);
B('l', 0.9, [0.13, 0.6, 0.71, 0.75]);
B('m', 0.9, [0.18, 0.6, 0.65, 0.55], false, {fb: 'smg'});
B('n', 0.9, [0.31, 0.62, 0.7, 0.4], false, {fb: 'rifle'});
B('o', 0.9, [0.2, 0.6, 0.68, 0.75], false, {fb: 'shotgun'});
B('p', 0.9, [0.17, 0.62, 0.6, 0.5]);
B('q', 0.9, [0.13, 0.62, 0.6, 0.55]);
B('r', 0.9, [0.08, 0.6, 0.6, 0.75]);
export const FIT = {}, GRIPS = {};
for (const k in M) { FIT[k] = M[k].fit; GRIPS[k] = M[k].grip; }
