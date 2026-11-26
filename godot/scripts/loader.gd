# The Ashfall: Meridian intro and loading screen (build 17). An autoload drawn over everything: ash drifting up
# through a dark sky, a slow trefoil turning over a dying sun, the title, a tip, and an amber segmented progress bar.
# The first launch plays it as the intro (scripts/boot.gd loads the game behind it); every load after that, a save,
# a trip through a door to another area, a fast travel, brings it up again until the ground near you has streamed in.
# It stays out of the way of the test hooks (any command-line arguments): screenshots never see it.
extends CanvasLayer

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
	"HOLS puts your gun away (H on a keyboard); pull the trigger to draw it again.",
	"Hostiles show on the compass as red ticks once you've spotted them.",
	"Anything you take with red text over it belongs to someone. They notice.",
	"Haven 12's service pistol takes 10mm. Don't let anyone sell you 9mm for it.",
	"The radio changes with the valley: what you do gets talked about.",
	"Sneak attacks on something that hasn't seen you do double damage, triple with a blade.",
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

func _ready() -> void:
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
	COLOR = vec4(sky * scan * vig, 1.0);
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
	skip_l = _label("tap to skip", 15, Color(0.7, 0.62, 0.5))
	bar = Bar.new()
	root.add_child(bar)
	root.gui_input.connect(_tap)
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
	bar.position = Vector2((s.x - bw) * 0.5, s.y * 0.78)
	bar.size = Vector2(bw, 22)
	status.position = Vector2(0, s.y * 0.78 - 34)
	status.size = Vector2(s.x, 26)
	tip.position = Vector2(s.x * 0.15, s.y * 0.78 + 36)
	tip.size = Vector2(s.x * 0.7, 60)
	skip_l.position = Vector2(0, s.y - 34)
	skip_l.size = Vector2(s.x, 24)

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
	Sfx.play("geiger", -12.0, 0.8)

# a load: a save, a door to another area, a long trip. Returns false (and shows nothing) under the test hooks.
func begin(text: String) -> bool:
	if quiet():
		return false
	intro = false
	skip_l.visible = false
	_show(text)
	title.modulate.a = 1.0
	sub.modulate.a = 1.0
	emblem.modulate.a = 1.0
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
	tip.text = "TIP: " + TIPS[randi() % TIPS.size()]
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

func _tap(ev: InputEvent) -> void:
	var down: bool = (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)
	if down and intro and on_skip.is_valid():
		on_skip.call()

func _process(d: float) -> void:
	if not visible:
		return
	t += d
	shown_t += d
	(bg.material as ShaderMaterial).set_shader_parameter("t", t)
	emblem.turn = t
	if intro:
		emblem.modulate.a = clampf(t / 1.2, 0.0, 1.0)
		title.modulate.a = clampf((t - 0.8) / 1.0, 0.0, 1.0)
		sub.modulate.a = clampf((t - 1.6) / 1.0, 0.0, 1.0)
		var w := 18.0 * maxf(0.0, 1.0 - (t - 1.6) / 1.4)
		sub.add_theme_constant_override("outline_size", 0)
		sub.text = "M  E  R  I  D  I  A  N" if w <= 0.0 else " ".repeat(int(w * 0.2)) + "M  E  R  I  D  I  A  N"
	# the game scene is up: follow the nearby chunks streaming in
	if waiting and Game.main and is_instance_valid(Game.main) and Game.main.is_node_ready() and not intro:
		var ch = Game.main.get("chunks")
		var left := 0
		if ch:
			left = (ch.queue as Array).size() + (ch.pending as Dictionary).size()
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

# an amber bar in segments, the leading one flickering, with its percentage
class Bar extends Control:
	var value := 0.0
	var t := 0.0
	func _draw() -> void:
		var s := size
		var amber := Color(1.0, 0.72, 0.3)
		draw_rect(Rect2(Vector2(-6, -6), s + Vector2(12, 12)), Color(0.05, 0.03, 0.02, 0.8))
		draw_rect(Rect2(Vector2(-6, -6), s + Vector2(12, 12)), Color(amber, 0.55), false, 2.0)
		for c in [Vector2(-6, -6), Vector2(s.x + 6, -6), Vector2(-6, s.y + 6), Vector2(s.x + 6, s.y + 6)]:
			draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), amber)
		var n := 32
		var gap := 3.0
		var w := (s.x - gap * (n - 1)) / n
		var lit := value * n
		for i in n:
			var x := i * (w + gap)
			var a := 0.12
			if i < int(lit):
				a = 0.95
			elif i == int(lit):
				a = 0.3 + 0.5 * (0.5 + 0.5 * sin(t * 14.0))
			draw_rect(Rect2(Vector2(x, 0), Vector2(w, s.y)), Color(amber, a))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(s.x + 14, s.y - 4), "%d%%" % int(value * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, amber)
