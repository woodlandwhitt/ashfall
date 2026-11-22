# Everything on screen: crosshair, FPS, health and ammo, quest tracker, compass, messages, the interaction prompt,
# dialogue, death and pause screens, and the touch controls (stick, look, fire, use, jump, reload, run).
extends CanvasLayer

var root: Control
var fps_l: Label
var quest_l: Label
var hp_bar: ProgressBar
var ammo_l: Label
var stat_l: Label
var prompt_l: Label
var msgs: VBoxContainer
var compass: Control
var dlg: PanelContainer
var dlg_name: Label
var dlg_text: Label
var dlg_opts: VBoxContainer
var hurt_rect: ColorRect
var dead_panel: PanelContainer
var pause_panel: PanelContainer
var touch: Control
var touch_on := false
var pip
var dev: DevMenu
var screens: Screens
var casino: Casino
var focus: Focus
var ap_bar: ProgressBar
var clock_t := 0.0
var weapon_l: Label
var font: Font
var fps_acc := 0.0
var fps_n := 0
var fps_min := 999.0
var hitmark: HitMark
var dmgdir: DmgDir
var tgt_box: VBoxContainer
var tgt_name: Label
var tgt_bar: ProgressBar
var tgt = null
var tgt_t := 0.0
var bot_l: Panel
var bot_r: Panel
var sneak_l: Label
var sneak_t := 0.0

const AMBER := Color(0.95, 0.78, 0.45)
const PANEL := Color(0.07, 0.055, 0.04, 0.82)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var th := Theme.new()
	th.default_font_size = 20
	th.set_color("font_color", "Label", AMBER)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	th.set_constant("outline_size", "Label", 4)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = Color(0.55, 0.42, 0.25, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	th.set_stylebox("panel", "PanelContainer", sb)
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.16, 0.12, 0.08, 0.95)
	bn.set_corner_radius_all(5)
	bn.set_content_margin_all(10)
	var bh := bn.duplicate()
	bh.bg_color = Color(0.32, 0.22, 0.12, 0.98)
	th.set_stylebox("normal", "Button", bn)
	th.set_stylebox("hover", "Button", bh)
	th.set_stylebox("pressed", "Button", bh)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", AMBER)
	th.set_color("font_hover_color", "Button", Color(1, 0.92, 0.7))
	th.set_font_size("font_size", "Button", 21)
	root.theme = th

	hurt_rect = ColorRect.new()
	hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_rect.color = Color(0.6, 0.0, 0.0, 0.0)
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hurt_rect)

	var cross := Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 26)
	_place(cross, Control.PRESET_CENTER, -7, -18, 200, 30)
	root.add_child(cross)

	fps_l = _label(Vector2(0, 8), 18)
	_place(fps_l, Control.PRESET_TOP_RIGHT, -330, 14, 180, 24)
	fps_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	quest_l = _label(Vector2(18, 14), 18)
	quest_l.size = Vector2(520, 60)
	quest_l.autowrap_mode = TextServer.AUTOWRAP_WORD

	msgs = VBoxContainer.new()
	msgs.position = Vector2(18, 84)
	msgs.size = Vector2(560, 200)
	msgs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msgs)

	compass = Compass.new()
	_place(compass, Control.PRESET_CENTER_TOP, -220, 10, 440, 34)
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(compass)

	# dark backing behind the corner readouts, so text stays legible over bright ground
	for side in [0, 1]:
		var bp := Panel.new()
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0, 0, 0, 0.38)
		bs.set_corner_radius_all(8)
		bp.add_theme_stylebox_override("panel", bs)
		bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if side == 0:
			_place(bp, Control.PRESET_BOTTOM_LEFT, 10, -100, 300, 92)
			bot_l = bp
		else:
			_place(bp, Control.PRESET_BOTTOM_RIGHT, -250, -94, 240, 86)
			bot_r = bp
		root.add_child(bp)
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	_place(hp_bar, Control.PRESET_BOTTOM_LEFT, 20, -42, 260, 18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.78, 0.3, 0.18)
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("fill", fill)
	hp_bar.add_theme_stylebox_override("background", bg)
	root.add_child(hp_bar)
	ap_bar = ProgressBar.new()
	ap_bar.show_percentage = false
	_place(ap_bar, Control.PRESET_BOTTOM_LEFT, 20, -20, 260, 8)
	var afill := StyleBoxFlat.new()
	afill.bg_color = Color(0.45, 0.9, 0.55)
	afill.set_corner_radius_all(3)
	ap_bar.add_theme_stylebox_override("fill", afill)
	ap_bar.add_theme_stylebox_override("background", bg)
	root.add_child(ap_bar)
	stat_l = _label(Vector2(20, -94), 16)
	_place(stat_l, Control.PRESET_BOTTOM_LEFT, 20, -94, 280, 48)
	stat_l.autowrap_mode = TextServer.AUTOWRAP_WORD

	ammo_l = _label(Vector2(0, 0), 26)
	_place(ammo_l, Control.PRESET_BOTTOM_RIGHT, -190, -52, 170, 36)
	ammo_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	weapon_l = _label(Vector2.ZERO, 17)
	_place(weapon_l, Control.PRESET_BOTTOM_RIGHT, -244, -86, 226, 26)
	weapon_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hitmark = HitMark.new()
	_place(hitmark, Control.PRESET_CENTER, -40, -40, 80, 80)
	hitmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hitmark)
	dmgdir = DmgDir.new()
	dmgdir.set_anchors_preset(Control.PRESET_FULL_RECT)
	dmgdir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dmgdir)
	tgt_box = VBoxContainer.new()
	_place(tgt_box, Control.PRESET_CENTER_TOP, -150, 52, 300, 40)
	tgt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tgt_box.add_theme_constant_override("separation", 2)
	root.add_child(tgt_box)
	tgt_name = Label.new()
	tgt_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tgt_name.add_theme_font_size_override("font_size", 16)
	tgt_box.add_child(tgt_name)
	tgt_bar = ProgressBar.new()
	tgt_bar.show_percentage = false
	tgt_bar.custom_minimum_size = Vector2(300, 9)
	var tf := StyleBoxFlat.new()
	tf.bg_color = Color(0.85, 0.25, 0.15)
	tf.set_corner_radius_all(2)
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color(0, 0, 0, 0.6)
	tb.set_corner_radius_all(2)
	tgt_bar.add_theme_stylebox_override("fill", tf)
	tgt_bar.add_theme_stylebox_override("background", tb)
	tgt_box.add_child(tgt_bar)
	tgt_box.visible = false
	sneak_l = Label.new()
	sneak_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sneak_l.add_theme_font_size_override("font_size", 18)
	_place(sneak_l, Control.PRESET_CENTER, -150, -70, 300, 28)
	sneak_l.visible = false
	root.add_child(sneak_l)
	prompt_l = _label(Vector2.ZERO, 22)
	_place(prompt_l, Control.PRESET_CENTER, -300, 40, 600, 34)
	prompt_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	touch_on = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--touch")
	touch = TouchPad.new()
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch.visible = touch_on
	root.add_child(touch)

	var pb := Button.new()
	pb.text = "II"
	_place(pb, Control.PRESET_TOP_RIGHT, -66, 8, 52, 44)
	pb.pressed.connect(toggle_pause)
	root.add_child(pb)

	var pip_b := Button.new()
	pip_b.text = "PIP"
	_place(pip_b, Control.PRESET_TOP_RIGHT, -136, 8, 62, 44)
	pip_b.pressed.connect(toggle_pip)
	root.add_child(pip_b)
	pip = preload("res://scripts/pipmenu.gd").new()
	root.add_child(pip)
	dev = DevMenu.new()
	root.add_child(dev)
	focus = Focus.new()
	root.add_child(focus)
	screens = Screens.new()
	root.add_child(screens)
	casino = Casino.new()
	root.add_child(casino)
	_build_dialogue()
	dead_panel = _center_panel("You died", [["Get up", func(): Game.main.respawn()]])
	pause_panel = _center_panel("Paused\n\nAshfall: Meridian", [["Resume", toggle_pause], ["Graphics", _cycle_gfx],
		["Developer", func(): toggle_pause(); toggle_dev()], ["Forge mode", func(): toggle_pause(); Game.main.forge.toggle()],
		["Main menu", func(): toggle_pause(); screens.open_title()]])
	_gfx_label()

	Game.message.connect(add_msg)
	Game.stats_changed.connect(refresh)
	Game.quest_changed.connect(refresh)
	refresh()

# anchors plus explicit offsets, so placement doesn't depend on the screen size at the moment it is built
func _place(c: Control, preset: int, x: float, y: float, w: float, h: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + h

func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l

func _center_panel(title: String, buttons: Array) -> PanelContainer:
	var p := PanelContainer.new()
	_place(p, Control.PRESET_CENTER, -240, -230, 480, 460)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var l := Label.new()
	l.text = title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	v.add_child(l)
	for b in buttons:
		var bt := Button.new()
		bt.text = b[0]
		bt.custom_minimum_size = Vector2(0, 54)
		bt.pressed.connect(b[1])
		v.add_child(bt)
	p.visible = false
	root.add_child(p)
	return p

func _build_dialogue() -> void:
	dlg = PanelContainer.new()
	dlg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dlg.offset_top = -330
	dlg.offset_left = 60
	dlg.offset_right = -60
	dlg.offset_bottom = -16
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	dlg.add_child(v)
	dlg_name = Label.new()
	dlg_name.add_theme_font_size_override("font_size", 22)
	dlg_name.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	v.add_child(dlg_name)
	dlg_text = Label.new()
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	dlg_text.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8))
	dlg_text.custom_minimum_size = Vector2(0, 80)
	v.add_child(dlg_text)
	dlg_opts = VBoxContainer.new()
	dlg_opts.add_theme_constant_override("separation", 6)
	v.add_child(dlg_opts)
	dlg.visible = false
	root.add_child(dlg)

func show_dialogue(who: String, text: String, opts: Array, cb: Callable) -> void:
	dlg.visible = true
	dlg_name.text = who
	dlg_text.text = text
	for c in dlg_opts.get_children():
		c.queue_free()
	for i in opts.size():
		var b := Button.new()
		b.text = "> " + String(opts[i].t)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 46)
		b.disabled = opts[i].get("off", false)
		b.pressed.connect(cb.bind(i))
		dlg_opts.add_child(b)
	# grow upward to fit long lines and many options
	var vh := get_viewport().get_visible_rect().size.y
	var lines := ceilf(text.length() / 95.0)
	dlg.offset_top = -clampf(150.0 + lines * 30.0 + opts.size() * 56.0, 330.0, vh - 24.0)
	touch.visible = false
	prompt_l.text = ""

func hide_dialogue() -> void:
	dlg.visible = false
	touch.visible = touch_on

func add_msg(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(540, 0)
	msgs.add_child(l)
	while msgs.get_child_count() > 4:
		msgs.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)

func refresh() -> void:
	hp_bar.max_value = Game.hp_max
	hp_bar.value = Game.hp
	ap_bar.max_value = Game.ap_max
	ap_bar.value = Game.ap
	var it := Game.item(Game.weapon)
	ammo_l.text = (str(Game.mag) + " / " + str(Game.reserve)) if it.has("mag") else ""
	# bare hands and blades need no ammo box: just the name, small, in the corner
	bot_r.visible = it.has("mag")
	weapon_l.offset_top = -86.0 if it.has("mag") else -40.0
	weapon_l.offset_bottom = weapon_l.offset_top + 26.0
	weapon_l.text = Game.iname(Game.weapon)
	var stims := int(Game.inv.get("stimpak", 0))
	stat_l.text = "LVL %d   XP %d/%d   CAPS %d" % [Game.level, Game.xp, Game.xp_need(), Game.caps] + ("\nSTIMS " + str(stims) if stims > 0 else "\n") + ("   RAD " + str(int(Game.rad)) if Game.rad >= 1.0 else "")
	var o := Game.current_objective()
	quest_l.text = (String(o.title).to_upper() + "\n" + String(o.text)) if not o.is_empty() else ""

func set_prompt(t: String) -> void:
	if not dlg.visible:
		prompt_l.text = t
		touch.use_label = t

# combat feedback: a cross at the crosshair for every hit (white), critical or head hit (yellow), kill (red)
func hit_marker(kind: String) -> void:
	hitmark.kind = kind
	hitmark.t = 0.32 if kind != "kill" else 0.5
	hitmark.queue_redraw()

# a red wedge at the edge of the screen pointing at whatever just hurt you
func hurt_from(src: Vector3) -> void:
	dmgdir.add(src)

# the name and health of what you're shooting at (the last thing hit, or what's under the crosshair)
func track_target(e, hold := 3.5) -> void:
	tgt = e
	tgt_t = hold

# while sneaking: [ HIDDEN ], [ CAUTION ] (something hostile is close but hasn't seen you) or [ DANGER ]
func _sneak_tick(d: float) -> void:
	var p = Game.player
	sneak_l.visible = p != null and p.crouch and not (pip and pip.visible)
	if not sneak_l.visible:
		return
	sneak_t -= d
	if sneak_t > 0.0:
		return
	sneak_t = 0.25
	var st := "HIDDEN"
	for e in Game.main.enemies:
		if not is_instance_valid(e) or e.dead or not e.hostile:
			continue
		var dd: float = e.global_position.distance_to(p.global_position)
		if e.state == "chase" and dd < 60.0 and e.foe == null:
			st = "DANGER"
			break
		if dd < 30.0:
			st = "CAUTION"
	sneak_l.text = "[ %s ]" % st
	sneak_l.add_theme_color_override("font_color", {"HIDDEN": Color(0.6, 1.0, 0.6), "CAUTION": Color(1.0, 0.85, 0.3), "DANGER": Color(1.0, 0.35, 0.25)}[st])

func _target_tick(d: float) -> void:
	tgt_t -= d
	var show: bool = tgt != null and is_instance_valid(tgt) and tgt_t > 0.0 and not tgt.get("dead") and not (pip and pip.visible)
	tgt_box.visible = show
	if show:
		var nm := String(tgt.def.get("name", tgt.type))
		if nm == nm.to_lower():
			nm = nm.capitalize()
		tgt_name.text = nm + ("  (crippled)" if not tgt.crip.is_empty() else "")
		tgt_bar.max_value = tgt.hp_max
		tgt_bar.value = tgt.hp

func flash_hurt(a: float) -> void:
	hurt_rect.color.a = clampf(hurt_rect.color.a + a, 0.0, 0.55)

func show_dead(on: bool) -> void:
	dead_panel.visible = on
	touch.visible = touch_on and not on

func _gfx_button() -> Button:
	for b in pause_panel.get_child(0).get_children():
		if b is Button and String(b.text).begins_with("Graphics"):
			return b
	return null

func _gfx_label() -> void:
	var b := _gfx_button()
	if b and Game.main:
		b.text = "Graphics: " + Quality.NAMES[Game.main.quality] + "  (tap to change)"

func _cycle_gfx() -> void:
	Game.main.cycle_quality()
	_gfx_label()

func toggle_pip() -> void:
	if Game.main.in_dialog() or Game.hp <= 0 or screens.is_open() or casino.is_open():
		return
	pip.at_bench = false
	if pip.visible:
		pip.visible = false
		Game.paused = false
		get_tree().paused = false
		touch.visible = touch_on
	else:
		Game.paused = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		touch.visible = false
		pip.open()

# the workbench opens the Pip menu on its CRAFT tab with the tools to hand
func open_craft(bench: bool) -> void:
	if pip.visible:
		return
	toggle_pip()
	pip.at_bench = bench
	pip.show_tab("CRAFT")

# the developer menu pauses the game like the Pip-Boy does
func toggle_dev() -> void:
	if screens.is_open() or pip.visible or casino.is_open():
		return
	if dev.visible:
		dev.visible = false
		Game.paused = false
		get_tree().paused = false
		touch.visible = touch_on
	else:
		Game.paused = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		touch.visible = false
		dev.open()

func _unhandled_key_input(e: InputEvent) -> void:
	if Game.main.forge and Game.main.forge.active:
		return
	if e.pressed and not e.echo and (e.keycode == KEY_TAB or e.keycode == KEY_I):
		toggle_pip()
	elif e.pressed and not e.echo and e.keycode == KEY_Q and not Game.paused:
		swap_weapon()

# cycle through the weapons you carry
func swap_weapon() -> void:
	var list: Array = Game.inv.keys().filter(func(k): return String(Game.item(k).get("t", "")) == "weapon")
	list.sort()
	if list.size() < 2:
		return
	var i := list.find(Game.weapon)
	Game.equip(list[(i + 1) % list.size()])

func toggle_pause() -> void:
	Game.paused = not Game.paused
	get_tree().paused = Game.paused
	pause_panel.visible = Game.paused
	if Game.paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_gfx_label()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if casino.is_open():
			casino.close()
		elif screens.is_open():
			screens.close()
		elif pip.visible:
			toggle_pip()
		elif Game.main.in_dialog():
			Game.main.end_dialog()
		elif not Game.paused:
			toggle_pause()

func _process(d: float) -> void:
	_target_tick(d)
	_sneak_tick(d)
	hurt_rect.color.a = maxf(0.0, hurt_rect.color.a - d * 0.8)
	ap_bar.max_value = Game.ap_max
	ap_bar.value = Game.ap
	clock_t -= d
	if clock_t <= 0.0:
		clock_t = 1.0
		refresh()
	fps_acc += d
	fps_n += 1
	fps_min = minf(fps_min, 1.0 / maxf(d, 0.0001))
	if fps_acc >= 0.5:
		fps_l.text = ("%s   " % Game.main.atmos.clock() if Game.main.atmos else "") + "%d FPS  (low %d)" % [roundi(fps_n / fps_acc), roundi(fps_min)]
		fps_acc = 0.0
		fps_n = 0
		fps_min = 999.0
	compass.queue_redraw()

# ---------------------------------------------------------------- compass strip
class HitMark extends Control:
	var t := 0.0
	var kind := "hit"
	func _process(d: float) -> void:
		if t > 0.0:
			t -= d
			queue_redraw()
	func _draw() -> void:
		if t <= 0.0:
			return
		var c := Vector2(40, 40)
		var col := Color(1, 1, 1) if kind == "hit" else (Color(1.0, 0.85, 0.2) if kind == "crit" else Color(1.0, 0.2, 0.15))
		col.a = clampf(t * 4.0, 0.0, 1.0)
		var r0 := 9.0
		var r1 := 18.0 if kind != "kill" else 23.0
		for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
			var v := Vector2(cos(a), sin(a))
			draw_line(c + v * r0, c + v * r1, Color(0, 0, 0, col.a * 0.7), 5.0)
			draw_line(c + v * r0, c + v * r1, col, 2.5)

class DmgDir extends Control:
	var hits: Array = []   # [world position, time left]
	func add(src: Vector3) -> void:
		hits.append([src, 1.3])
		if hits.size() > 6:
			hits.pop_front()
	func _process(d: float) -> void:
		if hits.is_empty():
			return
		for h in hits:
			h[1] -= d
		hits = hits.filter(func(h): return h[1] > 0.0)
		queue_redraw()
	func _draw() -> void:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.36
		for h in hits:
			var lp: Vector3 = cam.global_transform.affine_inverse() * (h[0] as Vector3)
			var ang := atan2(lp.x, -lp.z)   # 0 ahead, + to the right
			var a := ang - PI / 2.0
			var col := Color(0.95, 0.1, 0.05, clampf(float(h[1]), 0.0, 1.0) * 0.8)
			var pts := PackedVector2Array()
			for k in 9:
				var aa := a - 0.28 + 0.56 * k / 8.0
				pts.append(c + Vector2(cos(aa), sin(aa)) * r)
			for k in range(8, -1, -1):
				var aa := a - 0.2 + 0.4 * k / 8.0
				pts.append(c + Vector2(cos(aa), sin(aa)) * (r - 16.0))
			draw_colored_polygon(pts, col)

class Compass extends Control:
	func _draw() -> void:
		if Game.player == null:
			return
		var w := size.x
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		var yaw: float = Game.player.yaw
		var heading := fposmod(-yaw, TAU)  # 0 = north (-z), clockwise
		var f := ThemeDB.fallback_font
		var marks := {0.0: "N", PI * 0.5: "E", PI: "S", PI * 1.5: "W"}
		for a in marks:
			var dx := wrapf(a - heading, -PI, PI)
			if absf(dx) < 1.2:
				var x := w * 0.5 + dx / 1.2 * w * 0.5
				draw_string(f, Vector2(x - 6, 24), marks[a], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.8, 0.5))
		for i in 24:
			var a := i * TAU / 24.0
			var dx := wrapf(a - heading, -PI, PI)
			if absf(dx) < 1.2:
				var x := w * 0.5 + dx / 1.2 * w * 0.5
				draw_line(Vector2(x, 28), Vector2(x, 33), Color(0.9, 0.75, 0.5, 0.6), 1.0)
		var tp: Variant = Game.main.quest_target()
		if tp != null:
			var to: Vector3 = tp - Game.player.global_position
			var a := fposmod(atan2(to.x, -to.z), TAU)
			var dx := wrapf(a - heading, -PI, PI)
			var x := w * 0.5 + clampf(dx / 1.2, -1.0, 1.0) * w * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(x, 4), Vector2(x - 6, -4), Vector2(x + 6, -4)]), Color(1.0, 0.55, 0.2))
			draw_string(f, Vector2(x - 20, 50), str(roundi(Vector2(to.x, to.z).length())) + "m", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.7, 0.4))

# ---------------------------------------------------------------- touch controls: stick on the left, look anywhere else
class TouchPad extends Control:
	var stick_id := -1
	var stick_c := Vector2.ZERO
	var stick_p := Vector2.ZERO
	var look_id := -1
	var look_last := Vector2.ZERO
	var held := {}   # touch index -> button name
	var use_label := ""
	var running := false

	func buttons() -> Dictionary:
		var s := get_viewport_rect().size
		return {
			"fire": [Vector2(s.x - 120, s.y - 170), 70.0, "FIRE"],
			"use": [Vector2(s.x - 255, s.y - 120), 48.0, "USE"],
			"jump": [Vector2(s.x - 110, s.y - 320), 44.0, "JUMP"],
			"reload": [Vector2(s.x - 240, s.y - 250), 40.0, "RLD"],
			"run": [Vector2(370, s.y - 60), 38.0, "RUN"],
			"swap": [Vector2(s.x - 360, s.y - 70), 36.0, "SWAP"],
			"nade": [Vector2(s.x - 255, s.y - 360), 34.0, "NADE"],
			"focus": [Vector2(s.x - 370, s.y - 200), 38.0, "FOCUS"],
			"sneak": [Vector2(470, s.y - 60), 36.0, "SNEAK"],
		}

	func _input(e: InputEvent) -> void:
		if not visible or Game.paused:
			return
		var s := get_viewport_rect().size
		if e is InputEventScreenTouch:
			if e.pressed:
				for k in buttons():
					var b: Array = buttons()[k]
					if e.position.distance_to(b[0]) < b[1] + 10.0:
						held[e.index] = k
						_press(k, true)
						queue_redraw()
						return
				if e.position.y < 70:
					return
				if e.position.x < s.x * 0.4 and stick_id < 0:
					stick_id = e.index
					stick_c = e.position
					stick_p = e.position
				elif look_id < 0:
					look_id = e.index
					look_last = e.position
			else:
				if held.has(e.index):
					_press(held[e.index], false)
					held.erase(e.index)
				if e.index == stick_id:
					stick_id = -1
					Game.touch_move = Vector2.ZERO
				if e.index == look_id:
					look_id = -1
			queue_redraw()
		elif e is InputEventScreenDrag:
			if e.index == stick_id:
				var v: Vector2 = e.position - stick_c
				if v.length() > 70.0:
					v = v.normalized() * 70.0
				stick_p = stick_c + v
				Game.touch_move = v / 70.0
				queue_redraw()
			elif e.index == look_id:
				var dd: Vector2 = e.position - look_last
				look_last = e.position
				if Game.player:
					Game.player.look(dd.x * 0.0058, dd.y * 0.0058)
			elif held.get(e.index, "") == "fire" and Game.player:
				Game.player.look(e.relative.x * 0.0058, e.relative.y * 0.0058)

	func _press(k: String, on: bool) -> void:
		var p = Game.player
		if p == null:
			return
		var forging: bool = Game.main.forge != null and Game.main.forge.active
		if forging or Game.dev.noclip:
			if k == "jump":
				Game.touch_fly = 1.0 if on else 0.0
				return
			if k == "run":
				Game.touch_fly = -1.0 if on else 0.0
				return
		if forging:
			Game.main.forge.touch(k, on)
			return
		match k:
			"fire": p.trigger = on
			"use": if on: Game.main.interact()
			"jump": if on: p.jump()
			"reload": if on: p.reload()
			"swap": if on: Game.main.hud.swap_weapon()
			"nade": if on: p.throw_nade()
			"focus": if on: Game.main.hud.focus.enter()
			"sneak":
				if on:
					p.toggle_crouch()
					running = false
			"run":
				if on:
					running = not running
					p.running = running
					if running:
						p.crouch = false

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		for k in buttons():
			var b: Array = buttons()[k]
			var on: bool = k in held.values() or (k == "run" and running) or (k == "sneak" and Game.player != null and Game.player.crouch)
			draw_circle(b[0], b[1], Color(0.95, 0.78, 0.45, 0.32 if on else 0.16))
			draw_arc(b[0], b[1], 0, TAU, 40, Color(0.95, 0.78, 0.45, 0.55), 2.0)
			var txt: String = b[2]
			if k == "use" and use_label != "":
				txt = "USE"
			if Game.main and Game.main.forge and Game.main.forge.active:
				txt = Game.main.forge.button_label(k, txt)
			elif Game.dev.noclip and k in ["jump", "run"]:
				txt = "UP" if k == "jump" else "DOWN"
			draw_string(f, b[0] + Vector2(-b[1], 7), txt, HORIZONTAL_ALIGNMENT_CENTER, b[1] * 2.0, 20, Color(1, 0.9, 0.7, 0.9))
		if stick_id >= 0:
			draw_circle(stick_c, 70.0, Color(0, 0, 0, 0.25))
			draw_arc(stick_c, 70.0, 0, TAU, 40, Color(0.95, 0.78, 0.45, 0.5), 2.0)
			draw_circle(stick_p, 30.0, Color(0.95, 0.78, 0.45, 0.45))
		else:
			var c := Vector2(150, get_viewport_rect().size.y - 190)
			draw_arc(c, 70.0, 0, TAU, 40, Color(0.95, 0.78, 0.45, 0.25), 2.0)
