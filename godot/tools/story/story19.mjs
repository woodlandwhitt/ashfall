// Build 19 story layer: the towns defend themselves.
//
// Guards now shoot what comes into town (scripts/npc.gd _defend), so the towns that had one sheriff and nobody else
// get a watch: two Dustwell deputies on the north-west and south-east roads, and a vault security officer standing
// at the sandbags in front of the Camp of the Door. They talk about the raids and about how their people see you.

const F = (body, skin, hat = null, coat = null, bulk = 1) => ({fem: true, body, skin, hat, coat, bulk});
const M = (body, skin, hat = null, coat = null, bulk = 1) => ({fem: false, body, skin, hat, coat, bulk});
const N = (id, name, x, z, rot, look, extra = {}) => Object.assign({id, name, x, z, rot, wander: null, scale: 1, look}, extra);
const T = (t, go, extra = {}) => Object.assign(go ? {t, go} : {t}, extra);

export const NPCS = [
  N('dw_guard1', 'Deputy Ames', -84.2, 114.1, 0.51, M('#4a4232', '#c89a78', 'cap', '#5a4a36', 1.1)),
  N('dw_guard2', 'Deputy Rosa Kell', -103.1, 74.5, -2.76, F('#4a4232', '#8a5a3a', 'cap', '#5a4a36', 1.05)),
  N('hd_guard', 'Officer Brandt', 0.0, 191.0, 3.1416, M('#2a4a6a', '#e0ac88', 'helmet', '#2a3a50', 1.1)),
];

export const NPC_FACTION = {dw_guard1: 'dustwell', dw_guard2: 'dustwell', hd_guard: 'haven'};
export const GUARDS = ['dw_guard1', 'dw_guard2', 'hd_guard'];

export const DIALOGUE = {
  dw_guard1: {name: 'Deputy Ames', nodes: {
    hub: {say: G => G.repOf('dustwell') >= 6 ? 'Sheriff says you\'re the reason half this town still drinks. Anything comes down this road while you\'re here, I\'ve got your back.'
        : G.repOf('dustwell') <= -2 ? 'I\'m watching you. Sheriff\'s orders and my own inclination.'
        : 'South-east road. Raiders come up it every couple of weeks, hounds every couple of days. Keep your gun down in town unless something comes in.',
      opts: [T('Raiders come into town?', 'raids'), T('How does Dustwell see me?', 'rep'), T('Carry on.')]},
    raids: {say: 'They come in off the flats, three or four at a time, see what they can grab before we put them down. You hear shooting, get behind something. Or join in. We don\'t mind help.', opts: [T('Good to know.', 'hub')]},
    rep: {say: G => G.repOf('dustwell') >= 6 ? 'Like family. Don\'t let it go to your head.' : G.repOf('dustwell') >= 2 ? 'Well enough. You\'ve done right by us.' : G.repOf('dustwell') <= -2 ? 'Badly. Work on it, or work somewhere else.' : 'You\'re a stranger with a gun. Help folk and that changes.',
      opts: [T('Fair.', 'hub')]},
  }},
  dw_guard2: {name: 'Deputy Rosa Kell', nodes: {
    hub: {say: G => G.repOf('dustwell') >= 6 ? 'There\'s our hero. North-west road\'s quiet. Mostly thanks to you.'
        : 'North-west road. Anything with teeth or a rifle stops here. You\'re neither, so in you go.',
      opts: [T('Seen much trouble?', 'trouble'), T('See you.')]},
    trouble: {say: 'Ghouls out of the old tower some nights. Raiders out of the dens. Sheriff and Ames and me, we hold the street; everybody else gets indoors. Nobody\'s died on my road yet. Nobody of ours.', opts: [T('Keep it that way.', 'hub')]},
  }},
  hd_guard: {name: 'Officer Brandt', nodes: {
    hub: {say: G => G.repOf('haven') >= 6 ? 'Overseer\'s orders: you come and go as you please. Mine: shout if anything follows you home.'
        : G.repOf('haven') <= -6 ? 'You. Keep your hands where I can see them.'
        : 'Vault security. Somebody has to stand at the sandbags while the Overseer argues with the door.',
      opts: [T('Expecting trouble?', 'trouble'), T('As you were.')]},
    trouble: {say: 'Four hundred people sleeping in tents in front of a vault door. Every raider in the valley knows it. They come, we shoot, the families get behind the tank. That\'s the drill.', opts: [T('Good drill.', 'hub')]},
  }},
};
