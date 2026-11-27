# The main menu (build 21). Drawn over the live valley: a camera drifts slowly round wherever you are while the
# menu sits down the left, Fallout-style, over a dark gradient: CONTINUE, NEW GAME, LOAD GAME, OPTIONS, CREDITS, QUIT
# (RESUME first when you came from the pause menu). Load, options, credits and the are-you-sure questions open in a
# panel on the right. Indoors, or before the world is up, the loading screen's dusk sky stands in for the valley.
# Not an autoload (an in-game update can't add one): made on first use and kept on the root, like LoadScreen.
class_name MainMenu
extends CanvasLayer

static var _it: MainMenu
static func it() -> MainMenu:
	if _it == null or not is_instance_valid(_it):
		_it = MainMenu.new()
		_it.name = "MainMenu"
		(Engine.get_main_loop() as SceneTree).root.add_child(_it)
	return _it

const AMBER := Color(1.0, 0.74, 0.34)
const CREAM := Color(0.93, 0.88, 0.78)
const DIM := Color(0.66, 0.6, 0.5)
const FONT_BIG := 30

var root: Control
var sky: ColorRect
var shade: ColorRect
var ash: CPUParticles2D
var list: VBoxContainer
var side: PanelContainer
var side_title: Label
var side_body: VBoxContainer
var caption: Label
var build_l: Label
var update_box: VBoxContainer
var cam: Camera3D
var open_now := false
var from_game := false
var t := 0.0
var vista := 0
var vista_t := 0.0
var fade := 0.0
var center := Vector3.ZERO
var hid_player := false
var updater: Updater

func _init() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	# the dusk sky, for when there's no valley to show
	sky = ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lsm := ShaderMaterial.new()
	lsm.shader = (LoadScreen.it().bg.material as ShaderMaterial).shader
	sky.material = lsm
	root.add_child(sky)
	# darkness down the left for the menu, a vignette, grain and faint scanlines over the whole picture
	shade = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float t = 0.0;
uniform float black = 0.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment(){
	vec2 uv = UV;
	float left = smoothstep(0.62, 0.0, uv.x) * 0.86;
	float vig = smoothstep(0.45, 1.15, length((uv - vec2(0.5)) * vec2(1.2, 1.0)));
	float a = clamp(left + vig * 0.75, 0.0, 0.94);
	vec3 col = vec3(0.025, 0.017, 0.01);
	float g = (h(uv * 900.0 + vec2(t * 37.0, t * 91.0)) - 0.5) * 0.06;
	float scan = 0.5 + 0.5 * sin(FRAGCOORD.y * 2.2);
	a = clamp(a + g + scan * 0.025, 0.0, 1.0);
	COLOR = vec4(col, mix(a, 1.0, black));
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	shade.material = sm
	root.add_child(shade)
	ash = CPUParticles2D.new()
	ash.amount = 70
	ash.lifetime = 10.0
	ash.preprocess = 10.0
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.direction = Vector2(0.35, -1)
	ash.spread = 30.0
	ash.gravity = Vector2(5, -8)
	ash.initial_velocity_min = 6.0
	ash.initial_velocity_max = 24.0
	ash.scale_amount_min = 1.0
	ash.scale_amount_max = 2.6
	var gr := Gradient.new()
	gr.set_color(0, Color(1.0, 0.55, 0.2, 0.0))
	gr.add_point(0.25, Color(1.0, 0.62, 0.28, 0.7))
	gr.set_color(1, Color(0.5, 0.45, 0.4, 0.0))
	ash.color_ramp = gr
	root.add_child(ash)
	# the title
	var tbox := VBoxContainer.new()
	tbox.position = Vector2(64, 40)
	tbox.add_theme_constant_override("separation", 4)
	root.add_child(tbox)
	var tl := _label(tbox, "ASHFALL", 82, AMBER)
	tl.add_theme_constant_override("outline_size", 10)
	tl.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02))
	var sl := _label(tbox, "M  E  R  I  D  I  A  N", 25, CREAM)
	sl.add_theme_constant_override("outline_size", 4)
	sl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	var rule := ColorRect.new()
	rule.color = Color(AMBER, 0.6)
	rule.custom_minimum_size = Vector2(330, 2)
	tbox.add_child(rule)
	var tag := _label(tbox, "Haven 12 is running dry. Someone has to go up.", 16, DIM)
	tag.add_theme_constant_override("outline_size", 3)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	# the menu
	list = VBoxContainer.new()
	list.position = Vector2(58, 236)
	list.custom_minimum_size = Vector2(430, 0)
	list.add_theme_constant_override("separation", 0)
	root.add_child(list)
	update_box = VBoxContainer.new()
	update_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	update_box.offset_left = -470
	update_box.offset_top = -124
	update_box.offset_right = -28
	update_box.offset_bottom = -46
	root.add_child(update_box)
	build_l = _label(root, "", 14, DIM)
	build_l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	build_l.offset_left = 64
	build_l.offset_top = -38
	build_l.offset_right = 600
	build_l.offset_bottom = -14
	caption = _label(root, "", 15, Color(CREAM, 0.75))
	caption.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	caption.offset_left = -520
	caption.offset_top = -40
	caption.offset_right = -28
	caption.offset_bottom = -14
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.add_theme_constant_override("outline_size", 4)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	# the side panel
	side = PanelContainer.new()
	side.set_anchors_preset(Control.PRESET_FULL_RECT)
	side.anchor_left = 0.43
	side.anchor_right = 0.96
	side.anchor_top = 0.1
	side.anchor_bottom = 0.88
	side.offset_left = 0
	side.offset_right = 0
	side.offset_top = 0
	side.offset_bottom = 0
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.035, 0.025, 0.015, 0.9)
	ps.border_color = Color(AMBER, 0.55)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(4)
	ps.content_margin_left = 26
	ps.content_margin_right = 26
	ps.content_margin_top = 18
	ps.content_margin_bottom = 18
	ps.shadow_color = Color(0, 0, 0, 0.5)
	ps.shadow_size = 14
	side.add_theme_stylebox_override("panel", ps)
	side.visible = false
	root.add_child(side)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	side.add_child(sv)
	side_title = _label(sv, "", 30, AMBER)
	var r2 := ColorRect.new()
	r2.color = Color(AMBER, 0.35)
	r2.custom_minimum_size = Vector2(0, 2)
	sv.add_child(r2)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(sc)
	side_body = VBoxContainer.new()
	side_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_body.add_theme_constant_override("separation", 8)
	sc.add_child(side_body)

func _label(parent: Node, s: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

# a menu line: big cream capitals, amber with a bar and a marker when touched or focused
func _item(parent: Node, s: String, cb: Callable, sub := "", size := FONT_BIG) -> Button:
	var b := Button.new()
	b.text = "   " + s
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 54 if size >= FONT_BIG else 46)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", AMBER)
	b.add_theme_color_override("font_focus_color", AMBER)
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.6))
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.5))
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	var n := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("disabled", n)
	var hv := StyleBoxFlat.new()
	hv.bg_color = Color(AMBER, 0.12)
	hv.border_color = AMBER
	hv.border_width_left = 5
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("focus", hv)
	var pr := hv.duplicate() as StyleBoxFlat
	pr.bg_color = Color(AMBER, 0.26)
	b.add_theme_stylebox_override("pressed", pr)
	b.pressed.connect(func():
		Sfx.play("k_click", -6.0, 1.1)
		cb.call())
	b.mouse_entered.connect(func(): b.grab_focus())
	parent.add_child(b)
	if sub != "":
		var sl := _label(parent, "        " + sub, 15, DIM)
		sl.add_theme_constant_override("outline_size", 3)
		sl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return b

# ---------------------------------------------------------------- opening and closing
func open() -> void:
	from_game = Game.booted
	open_now = true
	visible = true
	t = 0.0
	vista_t = 0.0
	fade = 1.0
	Game.paused = true
	(Engine.get_main_loop() as SceneTree).paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.main and Game.main.hud:
		Game.main.hud.visible = false
		Game.main.hud.set_prompt("")
	_world_camera()
	# the valley keeps streaming in behind the menu while everything else waits
	if Game.main and is_instance_valid(Game.main) and Game.main.chunks:
		Game.main.chunks.process_mode = Node.PROCESS_MODE_ALWAYS
	_fill()
	side.visible = false
	var P = get_node_or_null("/root/Patcher")
	var bn := int(P.build) if P else 0
	build_l.text = ("Build %d" % bn if bn > 0 else "Development build") + ("  ·  updated in game" if P and P.patched else "")
	_update_row()

func close() -> void:
	if not open_now:
		return
	open_now = false
	visible = false
	side.visible = false
	Game.paused = false
	(Engine.get_main_loop() as SceneTree).paused = false
	if Game.main and is_instance_valid(Game.main):
		if Game.main.chunks:
			Game.main.chunks.process_mode = Node.PROCESS_MODE_INHERIT
		if Game.main.hud:
			Game.main.hud.visible = true
		if Game.player and is_instance_valid(Game.player):
			if hid_player:
				Game.player.visible = true
			if Game.player.cam:
				Game.player.cam.make_current()
	hid_player = false
	if cam and is_instance_valid(cam):
		cam.queue_free()
	cam = null

func is_open() -> bool:
	return open_now

# ---------------------------------------------------------------- the menu itself
func _fill() -> void:
	for c in list.get_children():
		c.queue_free()
	var last: String = Game.main.hud.screens.latest_save() if Game.main and Game.main.hud else ""
	if from_game:
		_item(list, "RESUME", close)
	if last != "":
		_item(list, "CONTINUE", func(): _load(last, "Picking up where you left off"), (_where(last) + "  ·  " if _where(last) != "" else "") + Game.save_info(last))
	_item(list, "NEW GAME", func():
		if last != "" or from_game:
			_confirm("NEW GAME", "Start again as a new resident of Haven 12?\nYour saved games are kept.", "START", _new_game)
		else:
			_new_game())
	_item(list, "LOAD GAME", _page_load)
	_item(list, "OPTIONS", _page_options)
	_item(list, "CREDITS", _page_credits)
	if not from_game:
		_item(list, "EXPLORE THE VALLEY", func():
			Game.booted = true
			close(), "", 22)
	_item(list, "QUIT", func(): _confirm("QUIT", "Leave the wasteland for now?" + ("\nAnything since your last save will be lost." if from_game else ""), "QUIT", func(): get_tree().quit()), "", 22)
	await get_tree().process_frame
	if list.get_child_count() > 0 and is_instance_valid(list.get_child(0)):
		(list.get_child(0) as Control).grab_focus()

func _new_game() -> void:
	close()
	Game.booted = true
	var sc = Game.main.hud.screens
	sc._open("intro")
	sc._intro(0)

func _load(slot: String, text: String) -> void:
	close()
	Game.booted = true
	if Game.main and Game.main.hud:
		Game.main.hud.pause_panel.visible = false
	LoadScreen.it().begin(text)
	Game.load_game(slot)

func _side(title: String) -> void:
	side.visible = true
	side_title.text = title
	for c in side_body.get_children():
		c.queue_free()
	Sfx.play("k_page", -8.0)

func _confirm(title: String, q: String, yes: String, cb: Callable) -> void:
	_side(title)
	var l := _label(side_body, q, 21, CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	side_body.add_child(row)
	_item(row, yes, cb, "", 26).custom_minimum_size = Vector2(200, 56)
	_item(row, "BACK", func(): side.visible = false, "", 26).custom_minimum_size = Vector2(200, 56)

func _page_load() -> void:
	_side("LOAD GAME")
	var any := false
	for slot in ["auto", "1", "2", "3"]:
		var info := Game.save_info(slot)
		var nm: String = "Autosave" if slot == "auto" else "Slot " + slot
		if info == "":
			var e := _label(side_body, "   %s  -  empty" % nm, 20, Color(DIM, 0.6))
			e.custom_minimum_size = Vector2(0, 44)
			continue
		any = true
		var sl: String = slot
		_item(side_body, "%s   %s" % [nm.to_upper(), _where(slot)], func(): _load(sl, "Loading " + nm.to_lower()), info, 22)
	if not any:
		_label(side_body, "No saved games yet. The game saves itself whenever you go through a door to another area, and you can save to a slot from the pause menu.", 17, DIM).autowrap_mode = TextServer.AUTOWRAP_WORD

func _where(slot: String) -> String:
	var f := FileAccess.open("user://save_" + slot + ".json", FileAccess.READ)
	if f == null:
		return ""
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return ""
	var who := String(d.get("name", ""))
	if String(d.get("area", "world")) == "vault":
		return who + ", Haven 12"
	if d.get("pos") is Array:
		return who + ", near " + _near(float(d.pos[0]), float(d.pos[2]))
	return who

func _near(x: float, z: float) -> String:
	var best := 1e9
	var nm := "the valley"
	for k in Game.DB.get("locs", {}):
		var L: Dictionary = Game.DB.locs[k]
		var dd := Vector2(float(L.get("x", 0)) - x, float(L.get("z", 0)) - z).length()
		if dd < best:
			best = dd
			nm = String(L.get("name", k))
	return nm

# ---------------------------------------------------------------- options
func _page_options() -> void:
	_side("OPTIONS")
	var q: int = Game.main.quality if Game.main else 1
	_choice("Graphics", Quality.label(q), func(dir: int):
		Quality.custom = {}
		Game.main.set_quality(posmod(Game.main.quality + dir, Quality.NAMES.size()))
		return Quality.label(Game.main.quality))
	_slider("Field of view", 60.0, 100.0, Quality.fov, "%d°", func(v: float):
		Quality.fov = v
		Game.main.set_quality(Game.main.quality))
	_slider("Look sensitivity", 0.4, 2.2, Settings.num("sens"), "%.1fx", func(v: float): Settings.set_num("sens", v))
	_slider("Volume", 0.0, 1.0, Settings.num("vol"), "%d%%", func(v: float): Settings.set_num("vol", v), 100.0)
	_slider("Radio volume", 0.0, 1.0, Settings.num("radio"), "%d%%", func(v: float): Settings.set_num("radio", v), 100.0)
	_choice("Camera", "Third person" if Game.player and Game.player.tp and Game.player.tp.on else "First person", func(_d: int):
		Game.player.toggle_view()
		return "Third person" if Game.player.tp and Game.player.tp.on else "First person")
	_choice("DEV button on screen", "On" if Settings.flag("dev") else "Off", func(_d: int):
		Settings.set_flag("dev", not Settings.flag("dev"))
		return "On" if Settings.flag("dev") else "Off")
	_choice("FORGE button on screen", "On" if Settings.flag("forge") else "Off", func(_d: int):
		Settings.set_flag("forge", not Settings.flag("forge"))
		return "On" if Settings.flag("forge") else "Off")

func _opt_row(name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 52)
	row.add_theme_constant_override("separation", 12)
	side_body.add_child(row)
	var l := _label(row, name, 21, CREAM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return row

func _choice(name: String, now: String, step: Callable) -> void:
	var row := _opt_row(name)
	var val := Label.new()
	var lb := _item(row, "<", func(): pass, "", 26)
	lb.text = "‹"
	lb.custom_minimum_size = Vector2(52, 50)
	lb.alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.text = now
	val.custom_minimum_size = Vector2(170, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 20)
	val.add_theme_color_override("font_color", AMBER)
	row.add_child(val)
	var rb := _item(row, ">", func(): pass, "", 26)
	rb.text = "›"
	rb.custom_minimum_size = Vector2(52, 50)
	rb.alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.pressed.connect(func(): val.text = String(step.call(-1)))
	rb.pressed.connect(func(): val.text = String(step.call(1)))

func _slider(name: String, lo: float, hi: float, now: float, fmt: String, set_to: Callable, show_k := 1.0) -> void:
	var row := _opt_row(name)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 36.0
	s.value = now
	s.custom_minimum_size = Vector2(230, 44)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(AMBER, 0.18)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(AMBER, 0.85)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", _knob())
	s.add_theme_icon_override("grabber_highlight", _knob())
	row.add_child(s)
	var val := _label(row, fmt % (now * show_k), 19, AMBER)
	val.custom_minimum_size = Vector2(70, 0)
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	s.value_changed.connect(func(v: float):
		val.text = fmt % (v * show_k)
		set_to.call(v))

static var _knob_tex: Texture2D
func _knob() -> Texture2D:
	if _knob_tex == null:
		var im := Image.create(26, 26, false, Image.FORMAT_RGBA8)
		for y in 26:
			for x in 26:
				var d := Vector2(x - 12.5, y - 12.5).length()
				var a := clampf(12.0 - d, 0.0, 1.0)
				var c := Color(1.0, 0.8, 0.45, a) if d < 8.5 else Color(0.12, 0.06, 0.02, a)
				im.set_pixel(x, y, c)
		_knob_tex = ImageTexture.create_from_image(im)
	return _knob_tex

# ---------------------------------------------------------------- credits
const CREDITS := [
	["ASHFALL: MERIDIAN", "A wasteland role-playing game for Android, made in Godot Engine 4.5 (MIT licence)."],
	["People and animations", "Quaternius: Universal Base Characters, Modular Character Outfits, Universal Animation Library (CC0)."],
	["Guns and gear", "Quaternius Ultimate Guns and Ultimate Low Poly Guns (via zees-games), Kenney Blaster Kit, Survival Kit and Weapon Pack (CC0)."],
	["Furniture and props", "Poly Haven photoscans (CC0); the wasteland kit from Quaternius and Kenney (CC0)."],
	["Textures and world", "Poly Haven, ambientCG and Kenney (CC0)."],
	["Voices", "Piper text-to-speech (MIT), en-us-libritts-high voice trained on LibriTTS (CC BY 4.0)."],
	["Radio music", "Alexander Nakarada and Kevin MacLeod, filmmusic.io / incompetech.com (CC BY 4.0): Apocalypse Blues, Sunset Fields, The Northern Path, Horsemen Approach, Tavern Brawl, Teller of the Tales, Devonshire Waltz, Grand Dark Waltz, Adeste Fideles Waltz, Suonatore di Liuto, Waltz Primordial."],
	["The Silver Spur", "Kenney Casino Audio and Music Loops (CC0); the crowd from the Oculus Audio Pack."],
	["Biscuit", "Fox model from the Khronos glTF Sample Assets: PixelMannen (CC0), rigged and animated by tomkranis (CC BY 4.0)."],
	["Full list", "CREDITS.md in the game's repository has every source and licence."],
]

func _page_credits() -> void:
	_side("CREDITS")
	for c in CREDITS:
		var h := _label(side_body, String(c[0]).to_upper(), 18, AMBER)
		h.custom_minimum_size = Vector2(0, 26)
		var b := _label(side_body, String(c[1]), 16, CREAM)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD

# ---------------------------------------------------------------- a newer build to download
func _update_row() -> void:
	for c in update_box.get_children():
		c.queue_free()
	if LoadScreen.quiet() and not OS.get_cmdline_user_args().has("--updatetest"):
		return
	if updater == null:
		updater = Updater.new()
		add_child(updater)
	var show_offer := func(b: int, mb: float):
		if not is_instance_valid(update_box):
			return
		for c in update_box.get_children():
			c.queue_free()
		var st := _label(update_box, "", 15, DIM)
		var btn := _item(update_box, "UPDATE TO BUILD %d  (%.0f MB)" % [b, mb], func(): pass, "", 20)
		btn.pressed.connect(func():
			btn.disabled = true
			st.text = "Downloading..."
			updater.download())
		updater.progress.connect(func(f: float):
			if is_instance_valid(st):
				st.text = "Downloading build %d: %d%%" % [b, int(f * 100.0)])
		updater.finished.connect(func(ok: bool, m: String):
			if is_instance_valid(st):
				st.text = m
				st.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6) if ok else Color(0.95, 0.55, 0.45))
			if is_instance_valid(btn):
				btn.disabled = ok)
	if not updater.newest.is_empty():
		show_offer.call(int(updater.newest.build), float(updater.newest.size) / 1048576.0)
	elif not updater.found.is_connected(show_offer):
		updater.found.connect(show_offer, CONNECT_ONE_SHOT)
		updater.check()

# ---------------------------------------------------------------- the valley behind it
const VISTAS := [[0.0, 26.0, 11.0, 0.05], [2.1, 34.0, 15.0, -0.04], [4.2, 22.0, 7.0, 0.06]]

func _world_camera() -> void:
	var outdoors: bool = Game.main != null and is_instance_valid(Game.main) and Game.area == "world" and not Game.interior() and Game.player != null
	sky.visible = not outdoors
	if not outdoors:
		return
	center = Game.player.global_position
	if Game.player.visible:
		Game.player.visible = false
		hid_player = true
	if cam == null or not is_instance_valid(cam):
		cam = Camera3D.new()
		cam.fov = 58.0
		cam.far = 900.0
		Game.main.add_child(cam)
	cam.make_current()
	caption.text = _near(center.x, center.z).to_upper()
	_place_cam(0.0)

func _place_cam(d: float) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	var v: Array = VISTAS[vista % VISTAS.size()]
	var a := float(v[0]) + vista_t * float(v[3])
	var r := float(v[1])
	var p := center + Vector3(sin(a) * r, 0, cos(a) * r)
	var gh := Game.height(p.x, p.z)
	p.y = maxf(gh + 3.5, center.y + float(v[2]))
	var look := center + Vector3(0, 2.0, 0)
	if d <= 0.0:
		cam.global_position = p
	else:
		cam.global_position = cam.global_position.lerp(p, 1.0 - exp(-3.0 * d))
	if cam.global_position.distance_to(look) > 0.5:
		cam.look_at(look, Vector3.UP)

func _process(d: float) -> void:
	if not open_now:
		return
	t += d
	vista_t += d
	var s := root.size if root.size.x > 10 else Vector2(1280, 720)
	ash.position = Vector2(s.x * 0.5, s.y + 20)
	ash.emission_rect_extents = Vector2(s.x * 0.6, 10)
	(shade.material as ShaderMaterial).set_shader_parameter("t", t)
	(sky.material as ShaderMaterial).set_shader_parameter("t", t)
	# a slow cut between three views every twenty seconds, through black
	if vista_t > 20.0:
		fade = minf(1.0, fade + d * 1.6)
		if fade >= 1.0:
			vista += 1
			vista_t = 0.0
			_place_cam(0.0)
	else:
		fade = maxf(0.0, fade - d * 0.9)
		_place_cam(d)
	(shade.material as ShaderMaterial).set_shader_parameter("black", fade if cam else 0.0)

func _unhandled_key_input(e: InputEvent) -> void:
	if not open_now or not e.pressed:
		return
	if e.keycode == KEY_ESCAPE:
		if side.visible:
			side.visible = false
		elif from_game:
			close()
		get_viewport().set_input_as_handled()
