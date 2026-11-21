# The Pip menu: STATS (levels, the six stats, spending points, perks), ITEMS (everything you carry, by category,
# with equip / use / drop), QUESTS, MAP (discovered places, fast travel) and SYSTEM (three save slots, the
# autosave, graphics). The game pauses while it is open.
extends PanelContainer

const GREEN := Color(0.55, 1.0, 0.6)
const DIM := Color(0.35, 0.7, 0.42)
var tabs: HBoxContainer
var body: Control
var current := "STATS"
var item_cat := "weapon"
var selected := ""
var map_tex: ImageTexture

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 24
	offset_top = 18
	offset_right = -24
	offset_bottom = -18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.06, 0.03, 0.96)
	sb.border_color = Color(0.3, 0.8, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	add_theme_stylebox_override("panel", sb)
	var th := Theme.new()
	th.set_color("font_color", "Label", GREEN)
	th.set_color("font_color", "Button", GREEN)
	th.set_color("font_hover_color", "Button", Color(0.85, 1.0, 0.85))
	th.set_color("font_pressed_color", "Button", Color(0.02, 0.1, 0.04))
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.05, 0.16, 0.08)
	bn.set_corner_radius_all(4)
	bn.set_content_margin_all(8)
	var bp := bn.duplicate()
	bp.bg_color = Color(0.45, 0.9, 0.5)
	th.set_stylebox("normal", "Button", bn)
	th.set_stylebox("hover", "Button", bn)
	th.set_stylebox("pressed", "Button", bp)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_font_size("font_size", "Button", 20)
	th.set_font_size("font_size", "Label", 19)
	theme = th
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for t in ["STATS", "ITEMS", "QUESTS", "MAP", "SYSTEM"]:
		var b := Button.new()
		b.text = t
		b.custom_minimum_size = Vector2(0, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): show_tab(t))
		tabs.add_child(b)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(60, 50)
	close.pressed.connect(func(): Game.main.hud.toggle_pip())
	tabs.add_child(close)
	body = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	visible = false

func open() -> void:
	visible = true
	show_tab(current)

func show_tab(t: String) -> void:
	current = t
	for b in tabs.get_children():
		(b as Button).modulate = Color(1, 1, 1) if (b as Button).text == t else Color(0.6, 0.6, 0.6)
	for c in body.get_children():
		c.queue_free()
	match t:
		"STATS": _stats()
		"ITEMS": _items()
		"QUESTS": _quests()
		"MAP": _map()
		"SYSTEM": _system()

func _scroll() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v

func _label(parent: Node, t: String, size := 19, col := GREEN) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(l)
	return l

# ---------------------------------------------------------------- STATS
func _stats() -> void:
	var v := _scroll()
	_label(v, "LEVEL %d     XP %d / %d     HP %d / %d     CAPS %d     KARMA %d" % [Game.level, Game.xp, Game.xp_need(), Game.hp, Game.hp_max, Game.caps, Game.karma], 21)
	_label(v, "Carrying %.0f / %.0f lbs" % [Game.carry_now(), Game.carry_max()], 18, DIM)
	if Game.points > 0:
		_label(v, "You have %d stat point%s to spend." % [Game.points, "s" if Game.points > 1 else ""], 20, Color(1, 0.9, 0.5))
	for k in ["might", "agility", "endurance", "aim", "luck", "charm"]:
		var row := HBoxContainer.new()
		v.add_child(row)
		var info: Array = Game.DB.statinfo.get(k, [k.to_upper(), ""])
		var l := _label(row, "%-10s %2d   %s" % [info[0], int(Game.stats[k]), info[1]], 19)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if Game.points > 0 and int(Game.stats[k]) < 10:
			var b := Button.new()
			b.text = " + "
			b.pressed.connect(func():
				Game.points -= 1
				Game.stats[k] = int(Game.stats[k]) + 1
				Game.stats_changed.emit()
				show_tab("STATS"))
			row.add_child(b)
	_label(v, "PERKS", 21)
	if Game.perks.is_empty():
		_label(v, "None yet. (Perks arrive with levelling in a later build.)", 18, DIM)
	for p in Game.perks:
		var d: Dictionary = Game.DB.perks.get(p, {})
		_label(v, String(d.get("n", p)) + ": " + String(d.get("d", "")), 18)

# ---------------------------------------------------------------- ITEMS
const CATS := [["weapon", "WEAPONS"], ["armor", "APPAREL"], ["aid", "AID"], ["ammo", "AMMO"], ["junk", "JUNK"], ["quest", "QUEST"]]
func _items() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	body.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	h.add_child(left)
	var cats := HBoxContainer.new()
	left.add_child(cats)
	for c in CATS:
		var b := Button.new()
		b.text = c[1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.modulate = Color(1, 1, 1) if c[0] == item_cat else Color(0.6, 0.6, 0.6)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(func():
			item_cat = c[0]
			selected = ""
			show_tab("ITEMS"))
		cats.add_child(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var ids: Array = Game.inv.keys().filter(func(k): return String(Game.item(k).get("t", "junk")) == item_cat)
	ids.sort_custom(func(a, b): return Game.iname(a) < Game.iname(b))
	if ids.is_empty():
		_label(list, "Nothing here.", 18, DIM)
	for id in ids:
		var b := Button.new()
		var mark := ""
		if id == Game.weapon or id == Game.armor:
			mark = "  [equipped]"
		b.text = Game.iname(id) + (" (" + str(Game.count(id)) + ")" if Game.count(id) > 1 else "") + mark
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 46)
		b.pressed.connect(func():
			selected = id
			show_tab("ITEMS"))
		list.add_child(b)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	if selected == "" or not Game.has(selected):
		_label(right, "Carrying %.0f / %.0f lbs" % [Game.carry_now(), Game.carry_max()], 18, DIM)
		return
	var it := Game.item(selected)
	_label(right, Game.iname(selected), 23, Color(0.85, 1.0, 0.85))
	_label(right, String(it.get("desc", "")), 18)
	var facts := []
	if it.has("dmg"):
		facts.append("Damage " + str(it.dmg) + (" x" + str(it.pellets) if it.has("pellets") else ""))
	if it.has("mag"):
		facts.append("Magazine " + str(it.mag) + ", " + Game.iname(it.get("ammo")))
	if it.has("heal"):
		facts.append("Heals " + str(it.heal))
	if it.has("dr"):
		facts.append("Damage resistance " + str(it.dr))
	facts.append("Weight " + str(it.get("w", 0)) + "   Value " + str(it.get("v", 0)))
	_label(right, "\n".join(facts), 18, DIM)
	var row := HBoxContainer.new()
	right.add_child(row)
	var t := String(it.get("t", ""))
	if t in ["weapon", "armor", "aid"] and not (selected == Game.weapon or selected == Game.armor):
		var u := Button.new()
		u.text = "EQUIP" if t != "aid" else ("READIED" if Game.nade == selected else "READY") if it.get("throw", false) else "USE"
		u.custom_minimum_size = Vector2(140, 52)
		u.pressed.connect(func():
			Game.use_item(selected)
			show_tab("ITEMS"))
		row.add_child(u)
	if t != "quest" and selected != Game.weapon and selected != Game.armor:
		var dr := Button.new()
		dr.text = "DROP"
		dr.custom_minimum_size = Vector2(120, 52)
		dr.pressed.connect(func():
			Game.take(selected, 1)
			if not Game.has(selected):
				selected = ""
			show_tab("ITEMS"))
		row.add_child(dr)

# ---------------------------------------------------------------- QUESTS
func _quests() -> void:
	var v := _scroll()
	var active := []
	var done := []
	for q in Game.quests:
		(done if Game.quests[q].done else active).append(q)
	_label(v, "ACTIVE", 21)
	if active.is_empty():
		_label(v, "No active quests. Talk to people.", 18, DIM)
	for q in active:
		var d: Dictionary = Game.QUESTS[q]
		_label(v, String(d.t), 20, Color(0.85, 1.0, 0.85))
		_label(v, "  " + String(d.stages[Game.stage(q)]), 18)
	_label(v, "COMPLETED", 21)
	for q in done:
		_label(v, String(Game.QUESTS[q].t), 18, DIM)

# ---------------------------------------------------------------- MAP
func _map_image() -> ImageTexture:
	if map_tex:
		return map_tex
	var N := 384
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	var mask: Image = (load("res://data/mask.png") as Texture2D).get_image()
	if mask.is_compressed():
		mask.decompress()
	var w := float(Game.hw - 1)
	var dd := float(Game.hd - 1)
	for y in N:
		for x in N:
			var wx := Game.x0 + x / float(N) * w
			var wz := Game.z0 + y / float(N) * dd
			var h := Game.height(wx, wz)
			var sl := Game.height(wx + 2.0, wz + 2.0) - h
			var c := Color(0.08, 0.22, 0.1).lerp(Color(0.25, 0.6, 0.3), clampf(h / 40.0 + 0.4, 0.0, 1.0))
			c = c.lightened(clampf(-sl * 0.25, -0.3, 0.3)) if sl < 0 else c.darkened(clampf(sl * 0.25, 0.0, 0.4))
			var mk := mask.get_pixel(int(x / float(N) * (mask.get_width() - 1)), int(y / float(N) * (mask.get_height() - 1)))
			if mk.r > 0.4:
				c = Color(0.55, 0.95, 0.6)
			img.set_pixel(x, y, c)
	map_tex = ImageTexture.create_from_image(img)
	return map_tex

func _map() -> void:
	var h := HBoxContainer.new()
	body.add_child(h)
	var map := MapView.new()
	map.tex = _map_image()
	map.custom_minimum_size = Vector2(430, 430)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(map)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(300, 0)
	h.add_child(v)
	_label(v, "PLACES", 21)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var list := VBoxContainer.new()
	sc.add_child(list)
	var any := false
	for k in Game.DB.locs:
		if not Game.discovered.has(k):
			continue
		any = true
		var L: Dictionary = Game.DB.locs[k]
		var inside: bool = Game.main.in_region(float(L.x), float(L.z))
		var b := Button.new()
		b.text = String(L.name) + ("" if inside else "  (not in this build)")
		b.disabled = not inside
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			Game.main.hud.toggle_pip()
			Game.main.fast_travel(k))
		list.add_child(b)
	if not any:
		_label(list, "Explore to discover places. Tap a discovered place to travel there.", 18, DIM)

class MapView extends Control:
	var tex: Texture2D
	func _draw() -> void:
		var s := minf(size.x, size.y)
		var r := Rect2(Vector2((size.x - s) * 0.5, 0), Vector2(s, s))
		draw_texture_rect(tex, r, false)
		var w := float(Game.hw - 1)
		var dd := float(Game.hd - 1)
		var f := ThemeDB.fallback_font
		var to_map := func(x: float, z: float) -> Vector2:
			return r.position + Vector2((x - Game.x0) / w, (z - Game.z0) / dd) * s
		for k in Game.DB.locs:
			var L: Dictionary = Game.DB.locs[k]
			if not Game.main.in_region(float(L.x), float(L.z)):
				continue
			var p: Vector2 = to_map.call(float(L.x), float(L.z))
			var known := Game.discovered.has(k)
			draw_circle(p, 5.0, Color(0.85, 1.0, 0.85) if known else Color(0.3, 0.55, 0.35))
			if known:
				draw_string(f, p + Vector2(8, 5), String(L.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 1.0, 0.85))
		var pp: Vector3 = Game.player.global_position
		var c: Vector2 = to_map.call(pp.x, pp.z)
		var yaw: float = Game.player.yaw
		var fw := Vector2(-sin(yaw), -cos(yaw))
		var rt := Vector2(-fw.y, fw.x)
		draw_colored_polygon(PackedVector2Array([c + fw * 11.0, c - fw * 7.0 + rt * 6.0, c - fw * 7.0 - rt * 6.0]), Color(1.0, 0.85, 0.3))

# ---------------------------------------------------------------- SYSTEM
func _system() -> void:
	var v := _scroll()
	for slot in ["1", "2", "3"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var info := Game.save_info(slot)
		var l := _label(row, "Slot " + slot + ":  " + (info if info != "" else "empty"), 19)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sv := Button.new()
		sv.text = "SAVE"
		sv.custom_minimum_size = Vector2(110, 50)
		sv.pressed.connect(func():
			if Game.save_game(slot):
				Game.msg("Saved to slot " + slot + ".")
			show_tab("SYSTEM"))
		row.add_child(sv)
		var ld := Button.new()
		ld.text = "LOAD"
		ld.custom_minimum_size = Vector2(110, 50)
		ld.disabled = info == ""
		ld.pressed.connect(func(): Game.load_game(slot))
		row.add_child(ld)
	var ai := Game.save_info("auto")
	var arow := HBoxContainer.new()
	v.add_child(arow)
	var al := _label(arow, "Autosave:  " + (ai if ai != "" else "none yet"), 19)
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ab := Button.new()
	ab.text = "LOAD"
	ab.custom_minimum_size = Vector2(110, 50)
	ab.disabled = ai == ""
	ab.pressed.connect(func(): Game.load_game("auto"))
	arow.add_child(ab)
	var g := Button.new()
	g.text = "Graphics: " + Quality.NAMES[Game.main.quality] + "  (tap to change)"
	g.custom_minimum_size = Vector2(0, 54)
	g.pressed.connect(func():
		Game.main.cycle_quality()
		show_tab("SYSTEM"))
	v.add_child(g)
	_label(v, "Ashfall: Meridian, Godot build. Autosaves every three minutes.", 16, DIM)
