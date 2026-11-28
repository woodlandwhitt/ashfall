# The Ashfall: Meridian intro and loading screen (build 17). An autoload drawn over everything: ash drifting up
# through a dark sky, a slow trefoil turning over a dying sun, the title, a tip, and an amber segmented progress bar.
# The first launch plays it as the intro (scripts/boot.gd loads the game behind it); every load after that, a save,
# a trip through a door to another area, a fast travel, brings it up again until the ground near you has streamed in.
# It stays out of the way of the test hooks (any command-line arguments): screenshots never see it.
class_name LoadScreen
extends CanvasLayer

# not an autoload (an in-game patch can't add one to an installed build): made on first use and kept on the root,
# so it outlives scene reloads
static var _it: LoadScreen
static func it() -> LoadScreen:
	if _it == null or not is_instance_valid(_it):
		_it = LoadScreen.new()
		_it.name = "LoadScreen"
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_it)
	return _it

func _init() -> void:
	_build()

const TIPS := [
	"Crouch behind someone to pick their pocket. Get caught three times and they stop asking nicely.",
	"Red barrels burn when shot, then go up. Stand back, or stand them next to the raiders.",
	"Tap the ammo count to switch between standard, FMJ and explosive rounds.",
	"FMJ rounds punch through machines: robots and turrets take far more from them.",
	"A locked-out terminal resets the next day. Sleep on it.",
	"Containers and the dead will hold what you put in them. Use them as stashes.",
	"Explosive rounds are made at a workbench from standard rounds and blasting powder.",
	"Break a pipe bomb down at a workbench and you have blasting powder.",
	"Tap a place on the map to travel there, once you've found it.",
	"Hold SWAP to holster your gun (H on a keyboard); pull the trigger to draw it again.",
	"Hostiles show on the compass as red ticks once you've spotted them.",
	"Anything you take with red text over it belongs to someone. They notice.",
	"Haven 12's service pistol takes 10mm. Don't let anyone sell you 9mm for it.",
	"The radio changes with the valley: what you do gets talked about.",
	"Sneak attacks on something that hasn't seen you do double damage, triple with a blade.",
	"A fall of more than four metres hurts. Twelve can nearly kill you. Take the stairs.",
	"Hold your breath with FOCUS to steady a scoped shot.",
	"Raiders in scrap-plate vests shrug off light rounds. Bring armour-piercing, or aim for the head.",
	"Stimpaks heal over a few seconds, not at once. Use one before the fight goes bad, not after.",
	"Radiation builds up slowly and leaves slowly. RadAway clears it; rad tea only slows it down.",
	"Companions carry what you give them. Ask them to hand it back when you need it.",
	"Shops buy back at a loss. Haggle by being liked: a good word in town lowers their prices.",
	"Workbenches strip guns for parts. One broken rifle can keep three others running.",
	"A gun's condition matters: worn guns jam and miss. Repair kits fix them on the road.",
	"Fire spreads to dry grass. A campfire in the wrong place is a weapon.",
	"Explosive barrels have a short fuse once lit. Count to three and be somewhere else.",
	"Night is darker out here than you're used to. Carry a lamp, or travel by day.",
	"Ghouls are slow until they see you. Then they aren't.",
	"Doors marked with red text are someone's property. Picking them is still a crime if you're seen.",
	"The compass marks your quest in orange. Distances are shown under it as you get close.",
	"You can sit on chairs and benches: walk up and USE them. It passes the time.",
	"Sleeping in a bed you own restores you fully and saves the game.",
	"Three houses are for sale in the valley. A town that likes you sells for less, and does the work on it for less too.",
	"A companion who lives in your house brings home what they find while you're away. Check the stash.",
	"One stash serves every house you own. Wall lockers make it bigger in all of them.",
	"Water from a dirty puddle quenches thirst and gives you rads. Boil it at a campfire first.",
	"Hostiles hear gunfire from a long way off. A knife in the dark keeps a camp asleep.",
	"Tyres, cones and crates can be knocked about. Some hide things underneath.",
	"Settlers remember who helped them. So do raiders.",
	"The DEV menu (top right) can teleport you, spawn things and run story beats for testing.",
	"If you get lost, open the PIP map: it shows every place you've found and where you are.",
]

var root: Control
var bg: ColorRect
var ash: CPUParticles2D
var emblem: Emblem
var title: Label
var sub: Label
var tip: Label
var status: Label
var bar: Bar
var skip_l: Label
var card: Label          # build 21: the cards before the title (engine, headphones); build 24: unused
var studio: Studio       # build 24: the WhitCo Productions card that opens the intro
var card_sub: Label
var stages: Label
var tip_i := 0
var tip_t := 0.0
const CARD_T := 4.6      # how long the cards run before the emblem rises
var shown := false
var intro := false
var t := 0.0
var shown_t := 0.0
var target := 0.0
var shown_p := 0.0
var fading := false
var waiting := false       # for the game scene to be up and its nearby ground streamed in
var chunk_total := 0
var on_skip: Callable

func _build() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float t = 0.0;
uniform float dim = 0.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment(){
	vec2 uv = UV;
	vec2 c = uv - vec2(0.5, 0.62);
	c.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float sun = smoothstep(0.42, 0.0, length(c));
	float clouds = n(uv * vec2(3.0, 6.0) + vec2(t * 0.02, 0.0)) * 0.6 + n(uv * vec2(7.0, 14.0) - vec2(t * 0.035, 0.0)) * 0.4;
	vec3 sky = mix(vec3(0.03, 0.02, 0.015), vec3(0.16, 0.08, 0.035), smoothstep(1.0, 0.25, uv.y));
	sky += vec3(0.55, 0.28, 0.08) * sun * sun * 0.9;
	sky = mix(sky, sky * 0.55, smoothstep(0.35, 0.8, clouds) * 0.7);
	// the ridge line of the valley
	float ridge = 0.78 + 0.035 * n(vec2(uv.x * 6.0, 1.0)) + 0.02 * n(vec2(uv.x * 23.0, 4.0));
	sky = mix(sky, vec3(0.02, 0.015, 0.01), smoothstep(ridge, ridge + 0.004, uv.y));
	float scan = 0.94 + 0.06 * sin(FRAGCOORD.y * 1.4);
	float vig = smoothstep(1.05, 0.35, length(uv - 0.5) * 1.3);
	COLOR = vec4(sky * scan * vig * (1.0 - dim), 1.0);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	bg.material = m
	root.add_child(bg)
	ash = CPUParticles2D.new()
	ash.amount = 90
	ash.lifetime = 9.0
	ash.preprocess = 9.0
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.direction = Vector2(0.3, -1)
	ash.spread = 25.0
	ash.gravity = Vector2(6, -10)
	ash.initial_velocity_min = 8.0
	ash.initial_velocity_max = 30.0
	ash.scale_amount_min = 1.0
	ash.scale_amount_max = 3.2
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.55, 0.2, 0.0))
	g.add_point(0.2, Color(1.0, 0.6, 0.25, 0.85))
	g.set_color(1, Color(0.5, 0.45, 0.4, 0.0))
	ash.color_ramp = g
	root.add_child(ash)
	emblem = Emblem.new()
	root.add_child(emblem)
	title = _label("ASHFALL", 92, Color(1.0, 0.76, 0.36))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02))
	sub = _label("M  E  R  I  D  I  A  N", 30, Color(0.92, 0.85, 0.7))
	tip = _label("", 19, Color(0.8, 0.74, 0.62))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	status = _label("", 17, Color(1.0, 0.76, 0.36))
	skip_l = _label("best with headphones on", 15, Color(0.7, 0.62, 0.5))
	card = _label("", 46, Color(0.95, 0.9, 0.8))
	card.add_theme_constant_override("outline_size", 6)
	card.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01))
	card_sub = _label("", 18, Color(1.0, 0.76, 0.36))
	stages = _label("", 14, Color(0.75, 0.68, 0.55))
	bar = Bar.new()
	root.add_child(bar)
	studio = Studio.new()
	studio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	studio.set_anchors_preset(Control.PRESET_FULL_RECT)
	studio.visible = false
	root.add_child(studio)
	root.resized.connect(_layout)
	visible = false
	_layout()

func _label(s: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l

func _layout() -> void:
	var s := root.size if root.size.x > 10 else Vector2(1280, 720)
	ash.position = Vector2(s.x * 0.5, s.y + 20)
	ash.emission_rect_extents = Vector2(s.x * 0.6, 10)
	emblem.position = Vector2(s.x * 0.5, s.y * 0.27)
	emblem.r = minf(s.y * 0.13, 90.0)
	title.position = Vector2(0, s.y * 0.40)
	title.size = Vector2(s.x, 110)
	sub.position = Vector2(0, s.y * 0.40 + 104)
	sub.size = Vector2(s.x, 40)
	var bw := minf(s.x * 0.62, 760.0)
	bar.position = Vector2((s.x - bw - 88.0) * 0.5, s.y * 0.78)
	bar.size = Vector2(bw, 22)
	status.position = Vector2(0, s.y * 0.78 - 34)
	status.size = Vector2(s.x, 26)
	tip.position = Vector2(s.x * 0.15, s.y * 0.78 + 36)
	tip.size = Vector2(s.x * 0.7, 60)
	skip_l.position = Vector2(0, s.y - 34)
	skip_l.size = Vector2(s.x, 24)
	card_sub.position = Vector2(0, s.y * 0.42 - 34)
	card_sub.size = Vector2(s.x, 26)
	card.position = Vector2(0, s.y * 0.42)
	card.size = Vector2(s.x, 60)
	stages.position = Vector2(0, s.y * 0.78 + 30)
	stages.size = Vector2(s.x, 20)
	tip.position.y = s.y * 0.78 + 58

static func quiet() -> bool:
	return OS.get_cmdline_user_args().size() > 0

# the first launch: the intro plays while the game loads behind it; on_done runs when it's loaded and either the
# intro has played through or it was tapped away
func play_intro(skip: Callable) -> void:
	intro = true
	on_skip = skip
	_show("Waking the valley")
	t = 0.0
	title.modulate.a = 0.0
	sub.modulate.a = 0.0
	emblem.modulate.a = 0.0
	skip_l.visible = true
	skip_l.modulate.a = 0.0
	card.visible = false
	card_sub.visible = false
	studio.visible = true
	studio.t = 0.0
	bar.modulate.a = 0.0
	status.modulate.a = 0.0
	tip.modulate.a = 0.0
	stages.modulate.a = 0.0
	(bg.material as ShaderMaterial).set_shader_parameter("dim", 1.0)
	Sfx.play("geiger", -14.0, 0.8)

# a load: a save, a door to another area, a long trip. Returns false (and shows nothing) under the test hooks.
func begin(text: String) -> bool:
	if quiet():
		return false
	intro = false
	skip_l.visible = false
	studio.visible = false
	ash.modulate.a = 1.0
	bar.modulate.a = 1.0
	status.modulate.a = 1.0
	stages.modulate.a = 1.0
	(bg.material as ShaderMaterial).set_shader_parameter("dim", 0.0)
	_show(text)
	title.modulate.a = 1.0
	sub.modulate.a = 1.0
	emblem.modulate.a = 1.0
	card.visible = false
	card_sub.visible = false
	target = 0.12
	shown_p = 0.0
	waiting = true
	chunk_total = 0
	return true

func _show(text: String) -> void:
	shown = true
	fading = false
	visible = true
	root.modulate.a = 1.0
	status.text = text.to_upper()
	tip_i = randi() % TIPS.size()
	tip_t = 0.0
	tip.text = "TIP  ·  " + TIPS[tip_i]
	shown_t = 0.0
	_layout()

func progress(f: float, text := "") -> void:
	target = maxf(target, clampf(f, 0.0, 1.0))
	if text != "":
		status.text = text.to_upper()

# the game scene is about to be built (a frozen frame or two): say so on the screen that will hang there
func building() -> void:
	waiting = true
	chunk_total = 0
	progress(0.6, "Raising the wasteland")
	skip_l.visible = false
	shown_p = maxf(shown_p, 0.6)
	bar.value = shown_p
	bar.queue_redraw()

func _process(d: float) -> void:
	if not visible:
		return
	t += d
	shown_t += d
	(bg.material as ShaderMaterial).set_shader_parameter("t", t)
	emblem.turn = t
	# a new tip every seven seconds, faded through
	tip_t += d
	if tip_t > 7.0:
		tip.modulate.a = maxf(0.0, 1.0 - (tip_t - 7.0) * 3.0)
		if tip_t > 7.35:
			tip_t = 0.0
			tip_i = (tip_i + 1) % TIPS.size()
			tip.text = "TIP  ·  " + TIPS[tip_i]
	else:
		tip.modulate.a = minf(1.0, tip_t * 3.0)
	# the stages, lit as the bar passes them
	var names := ["LOADING", "BUILDING", "STREAMING", "READY"]
	var at := [0.0, 0.55, 0.7, 0.995]
	var line := ""
	for i in names.size():
		line += ("●  " if shown_p >= float(at[i]) else "○  ") + String(names[i]) + ("        " if i < names.size() - 1 else "")
	stages.text = line
	if intro:
		# build 24: WhitCo Productions first (its name kindles letter by letter, an ember line runs out under it,
		# and it burns away upward into the ash), the sky coming up out of the dark behind it as it goes; then the
		# emblem and the title rise over the valley, and the bar and the tips last
		studio.t = t
		studio.queue_redraw()
		(bg.material as ShaderMaterial).set_shader_parameter("dim", clampf(1.0 - (t - CARD_T + 1.0) / 1.6, 0.0, 1.0))
		ash.modulate.a = clampf(0.35 + (t - 3.2) * 0.6, 0.35, 1.0)
		var ui := clampf((t - CARD_T - 2.2) / 1.0, 0.0, 1.0)
		bar.modulate.a = ui
		status.modulate.a = ui
		stages.modulate.a = ui
		skip_l.modulate.a = clampf((t - CARD_T - 1.0) / 1.0, 0.0, 0.8)
		if tip_t <= 7.0:
			tip.modulate.a = minf(tip.modulate.a, ui)
		var ti := t - CARD_T
		emblem.modulate.a = clampf(ti / 1.2, 0.0, 1.0)
		title.modulate.a = clampf((ti - 0.8) / 1.0, 0.0, 1.0)
		sub.modulate.a = clampf((ti - 1.6) / 1.0, 0.0, 1.0)
		var w := 18.0 * maxf(0.0, 1.0 - (ti - 1.6) / 1.4)
		sub.add_theme_constant_override("outline_size", 0)
		sub.text = "M  E  R  I  D  I  A  N" if w <= 0.0 else " ".repeat(int(w * 0.2)) + "M  E  R  I  D  I  A  N"
	# the game scene is up: follow the nearby chunks streaming in
	if waiting and Game.main and is_instance_valid(Game.main) and Game.main.is_node_ready() and not intro:
		var ch = Game.main.get("chunks")
		var left := 0
		if ch:
			left = (ch.queue as Array).size() + (ch.pending as Dictionary).size() + int((ch.coarse_todo as Array).size() / 12)
		chunk_total = maxi(chunk_total, left)
		var f := 1.0 if chunk_total == 0 else 1.0 - float(left) / float(chunk_total)
		progress(0.7 + 0.3 * f, "Streaming the valley in" if left > 0 else "Ready")
		if (left == 0 and shown_t > 0.6) or shown_t > 12.0:
			progress(1.0)
			finish()
	shown_p = move_toward(shown_p, target, d * 0.9)
	bar.value = shown_p
	bar.t = t
	bar.queue_redraw()
	emblem.queue_redraw()
	if fading:
		root.modulate.a -= d * 2.5
		if root.modulate.a <= 0.0:
			visible = false
			shown = false
			fading = false

func finish() -> void:
	waiting = false
	intro = false
	fading = true
	card.visible = false
	card_sub.visible = false
	studio.visible = false

# WhitCo Productions (build 24): the studio's name in wide-set capitals, each letter catching like an ember (white
# hot, then cooling to bone), an ember line drawn out from the middle beneath it, PRODUCTIONS fading up, and then
# the whole card burning away from the bottom up, its letters lifting and reddening into the ash
class Studio extends Control:
	var t := 0.0
	const WORD := "WHITCO"
	func _draw() -> void:
		var s := size if size.x > 10 else Vector2(1280, 720)
		var font := ThemeDB.fallback_font
		var fs := int(clampf(s.y * 0.15, 48.0, 130.0))
		var gap := float(fs) * 0.32
		var widths: Array = []
		var total := 0.0
		for ch in WORD:
			var wch := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			widths.append(wch)
			total += wch
		total += gap * (WORD.length() - 1)
		var cy := s.y * 0.47
		var x := (s.x - total) * 0.5
		var burn := clampf((t - 3.4) / 1.1, 0.0, 1.0)
		for i in WORD.length():
			var t0 := 0.35 + i * 0.13
			var k := clampf((t - t0) / 0.55, 0.0, 1.0)
			if k <= 0.0:
				x += float(widths[i]) + gap
				continue
			# hot when it catches, cooling as it settles
			var heat := 1.0 - smoothstep(0.0, 1.0, (t - t0) / 1.4)
			var col := Color(0.93, 0.87, 0.77).lerp(Color(1.0, 0.62, 0.22), heat)
			# burning away: each letter goes in its own moment, lifting and reddening
			var bi := clampf(burn * 1.6 - (WORD.length() - 1 - i) * 0.1, 0.0, 1.0)
			col = col.lerp(Color(0.85, 0.25, 0.08), bi)
			var a := k * (1.0 - bi)
			var lift := (1.0 - k) * 14.0 + bi * bi * 40.0
			var pos := Vector2(x, cy - lift)
			# a soft glow under each letter (drawn a few times round itself)
			for g in 6:
				var o := Vector2.from_angle(g * TAU / 6.0) * (3.0 + heat * 4.0)
				draw_string(font, pos + o, WORD[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.5, 0.15, a * (0.07 + heat * 0.12)))
			draw_string(font, pos, WORD[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
			x += float(widths[i]) + gap
		# the ember line, drawn out from the middle, its two heads bright
		var lk := clampf((t - 1.25) / 0.8, 0.0, 1.0)
		if lk > 0.0:
			var half := total * 0.5 * smoothstep(0.0, 1.0, lk)
			var ly := cy + float(fs) * 0.28
			var la := 1.0 - burn
			draw_line(Vector2(s.x * 0.5 - half, ly), Vector2(s.x * 0.5 + half, ly), Color(1.0, 0.62, 0.24, 0.85 * la), 2.0)
			draw_line(Vector2(s.x * 0.5 - half, ly), Vector2(s.x * 0.5 + half, ly), Color(1.0, 0.55, 0.18, 0.2 * la), 7.0)
			for sx in [-1.0, 1.0]:
				var hp := Vector2(s.x * 0.5 + sx * half, ly)
				draw_circle(hp, 3.5 + 2.0 * sin(t * 30.0), Color(1.0, 0.85, 0.55, la * (1.0 - lk * 0.6)))
		# PRODUCTIONS beneath
		var pk := clampf((t - 1.8) / 0.8, 0.0, 1.0) * (1.0 - burn)
		if pk > 0.0:
			var sub := "P  R  O  D  U  C  T  I  O  N  S"
			var sfs := int(fs * 0.22)
			var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
			draw_string(font, Vector2((s.x - sw) * 0.5, cy + float(fs) * 0.28 + sfs * 2.2), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(1.0, 0.76, 0.36, pk))
		# "presents", last and quietest
		var qk := clampf((t - 2.5) / 0.7, 0.0, 1.0) * (1.0 - burn)
		if qk > 0.0:
			var pr := "p r e s e n t s"
			var pfs := int(fs * 0.17)
			var pw := font.get_string_size(pr, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
			draw_string(font, Vector2((s.x - pw) * 0.5, s.y * 0.8), pr, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(0.85, 0.8, 0.7, qk * 0.8))

# a slow-turning trefoil over the sun
class Emblem extends Control:
	var r := 80.0
	var turn := 0.0
	func _draw() -> void:
		var amber := Color(1.0, 0.72, 0.3, 0.9)
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, amber, 3.0, true)
		draw_arc(Vector2.ZERO, r * 1.12, 0, TAU, 64, Color(amber, 0.35), 1.5, true)
		for i in 3:
			var a0 := turn * 0.35 + i * TAU / 3.0
			var pts := PackedVector2Array()
			pts.append(Vector2.from_angle(a0) * r * 0.24)
			for k in 9:
				pts.append(Vector2.from_angle(a0 + (k / 8.0 - 0.5) * PI / 3.0) * r * 0.86)
			pts.append(Vector2.from_angle(a0 + PI / 6.0) * r * 0.24)
			draw_colored_polygon(pts, Color(1.0, 0.68, 0.24, 0.85))
		draw_circle(Vector2.ZERO, r * 0.16, Color(1.0, 0.72, 0.3, 0.95))
		draw_circle(Vector2.ZERO, r * 0.09, Color(0.1, 0.04, 0.02, 1.0))
		# ticks round the rim like a dial
		for k in 36:
			var a := k * TAU / 36.0 - turn * 0.05
			var l := 0.06 if k % 3 == 0 else 0.03
			draw_line(Vector2.from_angle(a) * r * 1.16, Vector2.from_angle(a) * r * (1.16 + l), Color(amber, 0.6), 1.5)

# the bar (build 21): a framed amber gauge with a gradient fill, a light sweeping along it, a glowing leading edge,
# tick marks every tenth and the percentage in its own box at the end
class Bar extends Control:
	var value := 0.0
	var t := 0.0
	func _draw() -> void:
		var s := size
		var amber := Color(1.0, 0.72, 0.3)
		var deep := Color(0.62, 0.28, 0.07)
		# the frame
		draw_rect(Rect2(Vector2(-8, -8), s + Vector2(16, 16)), Color(0.04, 0.025, 0.015, 0.85))
		draw_rect(Rect2(Vector2(-8, -8), s + Vector2(16, 16)), Color(amber, 0.5), false, 2.0)
		draw_rect(Rect2(Vector2(-3, -3), s + Vector2(6, 6)), Color(amber, 0.18), false, 1.0)
		for c in [Vector2(-8, -8), Vector2(s.x + 8, -8), Vector2(-8, s.y + 8), Vector2(s.x + 8, s.y + 8)]:
			draw_rect(Rect2(c - Vector2(4, 4), Vector2(8, 8)), amber)
		# the fill: dark amber to bright, in a few vertical bands for a lit-glass look
		var w := s.x * clampf(value, 0.0, 1.0)
		if w > 1.0:
			var bands := 6
			for i in bands:
				var f := float(i) / bands
				var col := deep.lerp(amber, 0.35 + 0.65 * (1.0 - absf(f - 0.35) * 1.4))
				draw_rect(Rect2(Vector2(0, s.y * f), Vector2(w, s.y / bands + 0.5)), col)
			# a light running along the filled part
			var sw := fposmod(t * 0.55, 1.4) - 0.2
			var sx := sw * s.x
			if sx > 0 and sx < w:
				for k in 10:
					var a := 0.28 * (1.0 - k / 10.0)
					draw_rect(Rect2(Vector2(clampf(sx - k * 4.0, 0, w), 0), Vector2(4, s.y)), Color(1, 0.95, 0.8, a))
			# the leading edge glows
			for k in 4:
				draw_rect(Rect2(Vector2(w - 2 - k * 2, -2 - k), Vector2(3, s.y + 4 + k * 2)), Color(1.0, 0.9, 0.6, 0.35 - k * 0.07))
		# ticks every tenth
		for i in range(1, 10):
			var x := s.x * i / 10.0
			draw_line(Vector2(x, s.y + 3), Vector2(x, s.y + 7), Color(amber, 0.5), 1.0)
		# the readout
		var font := ThemeDB.fallback_font
		var box := Rect2(Vector2(s.x + 18, -8), Vector2(70, s.y + 16))
		draw_rect(box, Color(0.04, 0.025, 0.015, 0.85))
		draw_rect(box, Color(amber, 0.5), false, 2.0)
		draw_string(font, Vector2(s.x + 18, s.y - 1), "%d%%" % int(value * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 70, 18, amber)
