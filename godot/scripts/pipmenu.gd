# The Pip-Boy. Five sections, each with its own pages, styled like a green phosphor screen with a status header:
#   STAT   status (condition, radiation, chems, party), S.P.E.C.I.A.L. (stats, what they do, spending points),
#          perks (yours and the ones you can take), general (the record of your travels)
#   INV    weapons, apparel, aid, ammo, misc and quest items; sortable, with a full card for the selected item
#          (compared against what you have equipped) and equip / use / drop
#   DATA   quests (log of every stage, rewards, track), map (discovered places, fast travel), notes (terminal
#          entries you've read) and the workbench
#   RADIO  and SYS (saves, graphics)
# The game pauses while it is open.
extends PanelContainer

const GREEN := Color(0.55, 1.0, 0.6)
const BRIGHT := Color(0.85, 1.0, 0.85)
const DIM := Color(0.35, 0.7, 0.42)
const AMBERC := Color(1.0, 0.9, 0.55)
const BAD := Color(1.0, 0.5, 0.4)
const SECTIONS := {"STAT": ["STATUS", "S.P.E.C.I.A.L.", "PERKS", "GENERAL"], "INV": ["WEAPONS", "APPAREL", "AID", "AMMO", "MISC", "QUEST"],
	"DATA": ["QUESTS", "MAP", "FACTIONS", "PARTY", "NOTES", "CRAFT", "GUNSMITH"], "RADIO": ["RADIO"], "SYS": ["SYSTEM"]}
const INV_CAT := {"WEAPONS": "weapon", "APPAREL": "armor", "AID": "aid", "AMMO": "ammo", "MISC": "junk", "QUEST": "quest"}
# the old single-word page names still open the right place
const ALIAS := {"STATS": "STATUS", "ITEMS": "WEAPONS", "SPECIAL": "S.P.E.C.I.A.L."}
var section_bar: HBoxContainer
var page_bar: HBoxContainer
var header: Label
var header_bars: HBoxContainer
var footer: Label
var body: Control
var section := "STAT"
var current := "STATUS"
var last_page := {}
var item_cat := "weapon"
var selected := ""
var sel_quest := ""
var sel_note := ""
var sel_perk := ""
var sort_by := "name"
var map_tex: ImageTexture
var at_bench := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 20
	offset_top = 14
	offset_right = -20
	offset_bottom = -14
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.05, 0.025, 1.0)
	sb.border_color = Color(0.3, 0.8, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)
	var th := Theme.new()
	th.set_color("font_color", "Label", GREEN)
	th.set_color("font_color", "Button", GREEN)
	th.set_color("font_hover_color", "Button", BRIGHT)
	th.set_color("font_pressed_color", "Button", Color(0.02, 0.1, 0.04))
	th.set_color("font_disabled_color", "Button", Color(0.25, 0.45, 0.3))
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.04, 0.14, 0.07)
	bn.border_color = Color(0.2, 0.5, 0.28)
	bn.set_border_width_all(1)
	bn.set_corner_radius_all(4)
	bn.set_content_margin_all(7)
	var bp := bn.duplicate()
	bp.bg_color = Color(0.45, 0.9, 0.5)
	var bd := bn.duplicate()
	bd.bg_color = Color(0.03, 0.08, 0.04)
	th.set_stylebox("normal", "Button", bn)
	th.set_stylebox("hover", "Button", bn)
	th.set_stylebox("pressed", "Button", bp)
	th.set_stylebox("disabled", "Button", bd)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_font_size("font_size", "Button", 19)
	th.set_font_size("font_size", "Label", 18)
	var pf := StyleBoxFlat.new()
	pf.bg_color = GREEN
	pf.set_corner_radius_all(2)
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(0.05, 0.16, 0.08)
	pb.set_corner_radius_all(2)
	th.set_stylebox("fill", "ProgressBar", pf)
	th.set_stylebox("background", "ProgressBar", pb)
	theme = th
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	# header: who you are and how you're doing
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 12)
	v.add_child(hrow)
	header = Label.new()
	header.add_theme_font_size_override("font_size", 17)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(header)
	header_bars = HBoxContainer.new()
	header_bars.add_theme_constant_override("separation", 10)
	hrow.add_child(header_bars)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(56, 40)
	close.pressed.connect(func(): Game.main.hud.toggle_pip())
	hrow.add_child(close)
	section_bar = HBoxContainer.new()
	section_bar.add_theme_constant_override("separation", 6)
	v.add_child(section_bar)
	for sname in SECTIONS:
		var b := Button.new()
		b.text = sname
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 21)
		b.pressed.connect(func(): _open_section(sname))
		section_bar.add_child(b)
	page_bar = HBoxContainer.new()
	page_bar.add_theme_constant_override("separation", 6)
	v.add_child(page_bar)
	var rule := ColorRect.new()
	rule.color = Color(0.3, 0.8, 0.4, 0.6)
	rule.custom_minimum_size = Vector2(0, 2)
	v.add_child(rule)
	body = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	footer = Label.new()
	footer.add_theme_font_size_override("font_size", 15)
	footer.add_theme_color_override("font_color", DIM)
	v.add_child(footer)
	# scanlines over everything
	var scan := ColorRect.new()
	scan.set_anchors_preset(Control.PRESET_FULL_RECT)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){float l=step(.5,fract(FRAGCOORD.y*.5));COLOR=vec4(0.,0.,0.,l*.10+.02*sin(TIME*2.+FRAGCOORD.y*.01));}"
	sm.shader = sh
	scan.material = sm
	add_child(scan)
	visible = false

func open() -> void:
	visible = true
	show_tab(current)

func _open_section(sname: String) -> void:
	show_tab(last_page.get(sname, SECTIONS[sname][0]))

func _section_of(page: String) -> String:
	for sname in SECTIONS:
		if page in SECTIONS[sname]:
			return sname
	return "STAT"

func show_tab(t: String) -> void:
	t = ALIAS.get(t, t)
	# re-showing the same page (picking an item, spending a point) keeps every list where you had scrolled it
	var keep: Array = []
	if t == current:
		for sc in body.find_children("*", "ScrollContainer", true, false):
			keep.append((sc as ScrollContainer).scroll_vertical)
	if not keep.is_empty():
		_restore_scroll.call_deferred(keep)
	if _section_of(t) == "STAT" and not t in SECTIONS.STAT:
		t = "STATUS"
	current = t
	section = _section_of(t)
	last_page[section] = t
	if INV_CAT.has(t):
		if item_cat != INV_CAT[t]:
			selected = ""
		item_cat = INV_CAT[t]
	for b in section_bar.get_children():
		(b as Button).modulate = Color(1, 1, 1) if (b as Button).text == section else Color(0.55, 0.55, 0.55)
	for c in page_bar.get_children():
		c.queue_free()
	var pages: Array = SECTIONS[section]
	if pages.size() > 1:
		for pg in pages:
			var b := Button.new()
			var n := ""
			if INV_CAT.has(pg):
				var k: int = Game.inv.keys().filter(func(x): return String(Game.item(x).get("t", "junk")) == INV_CAT[pg]).size()
				n = " (%d)" % k
			b.text = pg + n
			b.flat = pg != t
			b.add_theme_font_size_override("font_size", 16)
			b.custom_minimum_size = Vector2(0, 36)
			b.pressed.connect(func(): show_tab(pg))
			page_bar.add_child(b)
	_refresh_header()
	for c in body.get_children():
		c.queue_free()
	match t:
		"STATUS": _status()
		"S.P.E.C.I.A.L.": _special()
		"PERKS": _perks()
		"GENERAL": _general()
		"WEAPONS", "APPAREL", "AID", "AMMO", "MISC", "QUEST": _items()
		"QUESTS": _quests()
		"MAP": _map()
		"NOTES": _notes()
		"FACTIONS": _factions()
		"PARTY": _party()
		"CRAFT": _craft()
		"GUNSMITH": _gunsmith()
		"RADIO": _radio()
		"SYSTEM": _system()

func _refresh_header() -> void:
	header.text = "%s   LVL %d   CAPS %d   DAY %d  %s" % [Game.player_name.to_upper(), Game.level, Game.caps, Game.day, _clock()]
	for c in header_bars.get_children():
		c.queue_free()
	for b in [["HP", Game.hp, Game.hp_max, GREEN], ["AP", Game.ap, Game.ap_max, Color(0.5, 0.9, 1.0)], ["XP", Game.xp, Game.xp_need(), AMBERC]]:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		header_bars.add_child(box)
		var l := Label.new()
		l.text = "%s %d/%d" % [b[0], int(b[1]), int(b[2])]
		l.add_theme_font_size_override("font_size", 15)
		box.add_child(l)
		box.add_child(_bar(float(b[1]), float(b[2]), b[3], 70))
	var place := _where()
	footer.text = "WEIGHT %.0f / %.0f    %s    %s" % [Game.carry_now(), Game.carry_max(), place, "RADIO ON" if Game.main.radio_on else ""]

func _clock() -> String:
	var tod := float(Game.time) * 24.0
	return "%02d:%02d" % [int(tod) % 24, int(fmod(tod, 1.0) * 60.0)]

func _where() -> String:
	if Game.area == "vault":
		return "HAVEN 12"
	if Game.area == "khole":
		return "???"
	if Game.area == "cells":
		var i := Game.cell_at(Game.player.global_position.x, Game.player.global_position.z)
		return Game.cell_name(i).to_upper() if i >= 0 else "INDOORS"
	var best := ""
	var bd := 1e9
	var pp: Vector3 = Game.player.global_position
	for k in Game.DB.locs:
		var L: Dictionary = Game.DB.locs[k]
		var d := Vector2(float(L.x) - pp.x, float(L.z) - pp.z).length()
		if d < bd:
			bd = d
			best = String(L.name)
	return ("NEAR " if bd > 60.0 else "") + best.to_upper()

func _bar(v: float, mx: float, col: Color, w := 160.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.max_value = maxf(mx, 0.001)
	pb.value = v
	pb.custom_minimum_size = Vector2(w, 12)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var f := StyleBoxFlat.new()
	f.bg_color = col
	f.set_corner_radius_all(2)
	pb.add_theme_stylebox_override("fill", f)
	return pb

func _restore_scroll(keep: Array) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scs := body.find_children("*", "ScrollContainer", true, false)
	for i in mini(keep.size(), scs.size()):
		(scs[i] as ScrollContainer).scroll_vertical = int(keep[i])

# drag anywhere on a list to scroll it, buttons included (a drag never counts as a tap)
var drag_sc: ScrollContainer
var drag_total := 0.0
var drag_end := 0
func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			drag_sc = null
			drag_total = 0.0
			for sc in body.find_children("*", "ScrollContainer", true, false):
				var s := sc as ScrollContainer
				if s.is_visible_in_tree() and s.get_global_rect().has_point(e.position) and s.get_v_scroll_bar().max_value > s.size.y + 2.0:
					drag_sc = s
		else:
			if drag_total > 12.0:
				drag_end = Time.get_ticks_msec()
			drag_sc = null
	elif e is InputEventMouseMotion and drag_sc and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		drag_total += absf(e.relative.y)
		if drag_total > 12.0:
			drag_sc.scroll_vertical -= int(e.relative.y)

func _tap_ok() -> bool:
	return Time.get_ticks_msec() - drag_end > 150 and drag_total <= 12.0

func _scroll(parent: Node = null) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(parent if parent else body).add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v

# a list on the left, a detail pane on the right
func _split(ratio := 1.0) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	body.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = ratio
	h.add_child(left)
	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.8, 0.4, 0.35)
	sep.custom_minimum_size = Vector2(2, 0)
	h.add_child(sep)
	var right := _scroll(h)
	return [left, right]

func _label(parent: Node, t: String, size := 18, col := GREEN) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	# a label sitting in a row must not wrap: in a row it has no width of its own and breaks after every letter
	l.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _title(parent: Node, t: String) -> void:
	var l := _label(parent, t, 20, BRIGHT)
	l.uppercase = true

func _row(parent: Node, k: String, v: String, col := GREEN) -> HBoxContainer:
	var r := HBoxContainer.new()
	parent.add_child(r)
	var a := _label(r, k, 17, DIM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.autowrap_mode = TextServer.AUTOWRAP_OFF
	var b := _label(r, v, 17, col)
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return r

func _button(parent: Node, t: String, f: Callable, w := 0.0, disabled := false) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, 46)
	b.disabled = disabled
	b.pressed.connect(func():
		if _tap_ok():
			f.call())
	parent.add_child(b)
	return b

func _list_button(parent: Node, t: String, on: bool, f: Callable) -> Button:
	var b := Button.new()
	b.text = ("> " if on else "  ") + t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 42)
	b.clip_text = true
	if on:
		b.add_theme_color_override("font_color", AMBERC)
	b.pressed.connect(func():
		if _tap_ok():
			f.call())
	parent.add_child(b)
	return b

# ---------------------------------------------------------------- STAT: STATUS
func _status() -> void:
	var lr := _split(1.0)
	var L: VBoxContainer = _scroll(lr[0])
	var R: VBoxContainer = lr[1]
	_title(L, "Condition")
	var hb := HBoxContainer.new()
	L.add_child(hb)
	_label(hb, "HEALTH  %d / %d" % [Game.hp, Game.hp_max], 18).custom_minimum_size = Vector2(190, 0)
	hb.add_child(_bar(Game.hp, Game.hp_max, GREEN, 200))
	var ab := HBoxContainer.new()
	L.add_child(ab)
	_label(ab, "ACTION  %d / %d" % [Game.ap, Game.ap_max], 18).custom_minimum_size = Vector2(190, 0)
	ab.add_child(_bar(Game.ap, Game.ap_max, Color(0.5, 0.9, 1.0), 200))
	var rb := HBoxContainer.new()
	L.add_child(rb)
	var rlvl := "none" if Game.rad < 1 else ("minor" if Game.rad < 25 else ("advanced" if Game.rad < 60 else "critical"))
	_label(rb, "RADS  %d  (%s)" % [Game.rad, rlvl], 18, GREEN if Game.rad < 25 else (AMBERC if Game.rad < 60 else BAD)).custom_minimum_size = Vector2(190, 0)
	rb.add_child(_bar(Game.rad, 100.0, Color(0.9, 0.85, 0.2), 200))
	if Game.rad >= 1.0:
		_label(L, "Radiation is costing you %d maximum health. Rad Flush clears it; a roof keeps the storms off." % floori(Game.rad * 0.4), 16, DIM)
	_row(L, "Damage resistance", "%d" % int(Game.armor_dr() + float(Game.fx().dr)))
	_row(L, "Carrying", "%.0f / %.0f lbs" % [Game.carry_now(), Game.carry_max()], GREEN if Game.carry_now() <= Game.carry_max() else BAD)
	_title(L, "Equipped")
	var wi := Game.item(Game.weapon)
	_row(L, "Weapon", Game.iname(Game.weapon) if Game.weapon != "" else "Fists")
	if wi.has("dmg"):
		_row(L, "  Damage per hit", "%.0f" % Game.player.weapon_damage())
		if wi.has("mag"):
			_row(L, "  Rounds", "%d in the gun, %d carried" % [Game.mag, Game.reserve])
	_row(L, "Apparel", Game.iname(Game.armor) if Game.armor != "" else "Nothing")
	_title(R, "Effects")
	var any := false
	var bnames := {"dr": "Numb (damage resistance)", "rad": "Lead Tabs (radiation)", "melee": "Rotgut (melee)", "luck": "Lucky Sour (luck)", "ap": "Prickly Pop (action points)"}
	for k in Game.buffs:
		any = true
		_row(R, bnames.get(k, k), "%ds left" % int(Game.buffs[k].t), AMBERC)
	var DR: Dictionary = Game.L.get("consts", {}).get("DRUGS", {})
	for k in Game.drugs:
		any = true
		var d: Dictionary = Game.drugs[k]
		var D: Dictionary = DR.get(k, {})
		var left := (float(D.get("crash", {}).get("dur", 0)) if d.crash else float(D.get("dur", 0))) - float(d.age)
		_row(R, String(D.get("n", k)) + (" (crash)" if d.crash else ""), "%ds" % maxi(0, int(left)), BAD if d.crash else AMBERC)
		if D.has("stats") and not d.crash:
			var parts := []
			for st in D.stats:
				parts.append("%s %+d" % [String(Game.DB.statinfo.get(st, [st])[0]), int(D.stats[st])])
			_label(R, "   " + ", ".join(parts), 15, DIM)
	for k in Game.addict:
		any = true
		_row(R, "Addicted: " + String(DR.get(k, {}).get("n", k)), "slower, shakier" if not Game.drugs.has(k) else "fed", BAD)
	if not any:
		_label(R, "Nothing in your system. Clean as a whistle.", 16, DIM)
	_title(R, "Companions")
	if Game.main.party.is_empty():
		_label(R, "You travel alone.", 16, DIM)
	for pm in Game.main.party:
		var box := VBoxContainer.new()
		R.add_child(box)
		var top := HBoxContainer.new()
		box.add_child(top)
		var nl := _label(top, String(pm.comp.get("n", pm.id)) + ("  — DOWN" if pm.down > 0.0 else ("  — waiting" if pm.cstate == "wait" else "  — following")), 18, BRIGHT)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(_bar(pm.hp, float(pm.comp.get("hp", 100)), GREEN, 120))
		var cmds := HBoxContainer.new()
		box.add_child(cmds)
		var pid := String(pm.id)
		_button(cmds, "FOLLOW" if pm.cstate == "wait" else "WAIT HERE", func():
			Game.main.party_cmd(pid, "follow" if pm.cstate == "wait" else "wait")
			show_tab("STATUS"), 150)
		_button(cmds, "PART WAYS", func():
			Game.main.dismiss(pid)
			show_tab("STATUS"), 150)

# ---------------------------------------------------------------- STAT: S.P.E.C.I.A.L.
func _special() -> void:
	var lr := _split(1.15)
	var L: VBoxContainer = _scroll(lr[0])
	var R: VBoxContainer = lr[1]
	if Game.points > 0:
		_label(L, "%d point%s to spend" % [Game.points, "s" if Game.points > 1 else ""], 19, AMBERC)
	var derived := {
		"might": "Carry %.0f lbs, melee damage %+d%%" % [Game.carry_max(), (int(Game.stats.might) - 5) * 7],
		"agility": "%d action points" % int(Game.ap_max),
		"endurance": "%d maximum health" % int(Game.hp_max),
		"aim": "Firearm damage %+d%%" % ((int(Game.stats.aim) - 5) * 5),
		"luck": "%d%% chance of a critical hit" % maxi(0, 3 + int(Game.stats.luck) - 5),
		"charm": "Better prices from traders; new things to say",
		"intellect": "Experience %+d%%, healing from medicine %+d%%" % [(int(Game.stats.get("intellect", 5)) - 5) * 5, (int(Game.stats.get("intellect", 5)) - 5) * 4],
	}
	for k in Game.SPECIAL:
		var info: Array = Game.DB.statinfo.get(k, [k.to_upper(), ""])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		L.add_child(row)
		var b := Button.new()
		b.text = String(info[0])
		b.custom_minimum_size = Vector2(170, 42)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			sel_perk = k
			show_tab("S.P.E.C.I.A.L."))
		row.add_child(b)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 3)
		pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pips)
		for i in 10:
			var r := ColorRect.new()
			r.custom_minimum_size = Vector2(14, 20)
			r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.color = GREEN if i < int(Game.stats.get(k, 5)) else Color(0.08, 0.2, 0.1)
			pips.add_child(r)
		_label(row, str(int(Game.stats[k])), 20, BRIGHT).custom_minimum_size = Vector2(28, 0)
		if Game.points > 0 and int(Game.stats[k]) < 10:
			_button(row, "+", func():
				Game.points -= 1
				Game.stats[k] = int(Game.stats[k]) + 1
				Game.stats_changed.emit()
				sel_perk = k
				show_tab("S.P.E.C.I.A.L."), 50)
	var k2: String = sel_perk if sel_perk in derived else "might"
	var inf: Array = Game.DB.statinfo.get(k2, [k2.to_upper(), ""])
	_title(R, String(inf[0]))
	_label(R, String(inf[1]) + ".", 18)
	_label(R, "Right now: " + String(derived[k2]) + ".", 18, AMBERC)
	_label(R, "\nStats rise by one point each level. Chems raise them for a while (and take it back when they wear off).", 16, DIM)

# ---------------------------------------------------------------- STAT: PERKS
func _perks() -> void:
	var lr := _split(1.0)
	var L: VBoxContainer = _scroll(lr[0])
	var R: VBoxContainer = lr[1]
	var perks: Dictionary = Game.L.get("consts", {}).get("PERKS", Game.DB.get("perks", {}))
	_label(L, ("%d perk%s to choose" % [Game.perk_pts, "s" if Game.perk_pts > 1 else ""]) if Game.perk_pts > 0 else "A new perk every second level.", 17, AMBERC if Game.perk_pts > 0 else DIM)
	_title(L, "Yours")
	var mine := perks.keys().filter(func(p): return Game.perks.has(p))
	if mine.is_empty():
		_label(L, "None yet.", 16, DIM)
	for pk in mine:
		_list_button(L, String(perks[pk].get("n", pk)), pk == sel_perk, func():
			sel_perk = pk
			show_tab("PERKS"))
	_title(L, "Available")
	for pk in perks:
		if Game.perks.has(pk):
			continue
		var lv := int(perks[pk].get("lvl", 0))
		_list_button(L, String(perks[pk].get("n", pk)) + ("  (level %d)" % lv if lv > Game.level else ""), pk == sel_perk, func():
			sel_perk = pk
			show_tab("PERKS"))
	if not perks.has(sel_perk):
		_label(R, "Choose a perk to read about it.", 17, DIM)
		return
	var d: Dictionary = perks[sel_perk]
	_title(R, String(d.get("n", sel_perk)))
	_label(R, String(d.get("d", "")), 18)
	var need := int(d.get("lvl", 0))
	if Game.perks.has(sel_perk):
		_label(R, "\nYou have this perk.", 17, AMBERC)
	elif Game.level < need:
		_label(R, "\nNeeds level %d." % need, 17, DIM)
	else:
		var pid := sel_perk
		_button(R, "TAKE THIS PERK" if Game.perk_pts > 0 else "NO PERK POINTS", func():
			Game.perk_pts -= 1
			Game.perks[pid] = 1
			Sfx.play("o_levelup", -6.0)
			Game.stats_changed.emit()
			show_tab("PERKS"), 0, Game.perk_pts <= 0)

# ---------------------------------------------------------------- STAT: GENERAL
func _general() -> void:
	var lr := _split(1.0)
	var L: VBoxContainer = _scroll(lr[0])
	var R: VBoxContainer = lr[1]
	_title(L, "Record")
	_row(L, "Days in the wastes", str(Game.day))
	_row(L, "Level", "%d  (%d / %d XP)" % [Game.level, Game.xp, Game.xp_need()])
	_row(L, "Karma", "%d — %s" % [Game.karma, Game.karma_title(Game.karma)], GREEN if Game.karma >= 0 else BAD)
	var qd := 0
	var qa := 0
	for q in Game.quests:
		if Game.quests[q].done:
			qd += 1
		else:
			qa += 1
	_row(L, "Quests completed", str(qd))
	_row(L, "Quests underway", str(qa))
	_row(L, "Places discovered", "%d / %d" % [Game.discovered.size(), Game.DB.locs.size()])
	var reads := 0
	for k in Game.DB.lore:
		if Game.flags.has("read_" + k):
			reads += 1
	_row(L, "Terminal entries read", "%d / %d" % [reads, Game.DB.lore.size()])
	_row(L, "Broadcasts heard", str(Game.flags.get("heard", []).size()))
	_row(L, "Trips through the floor", str(int(Game.flags.get("kholes", 0))))
	_row(L, "Caps", str(Game.caps))
	_title(R, "Kills")
	var total := 0
	var ks: Array = Game.kills.keys()
	ks.sort_custom(func(a, b): return int(Game.kills[a]) > int(Game.kills[b]))
	for k in ks:
		total += int(Game.kills[k])
	_row(R, "Total", str(total), AMBERC)
	for k in ks:
		var nm := String(Game.region.etypes.get(k, {}).get("name", k)).capitalize()
		_row(R, nm, str(int(Game.kills[k])))
	if ks.is_empty():
		_label(R, "Nothing yet.", 16, DIM)

# ---------------------------------------------------------------- INV
func _sorted_ids() -> Array:
	var ids: Array = Game.inv.keys().filter(func(k): return String(Game.item(k).get("t", "junk")) == item_cat)
	match sort_by:
		"weight": ids.sort_custom(func(a, b): return float(Game.item(a).get("w", 0)) > float(Game.item(b).get("w", 0)))
		"value": ids.sort_custom(func(a, b): return float(Game.item(a).get("v", 0)) > float(Game.item(b).get("v", 0)))
		"damage": ids.sort_custom(func(a, b): return float(Game.item(a).get("dmg", Game.item(a).get("dr", Game.item(a).get("heal", 0)))) > float(Game.item(b).get("dmg", Game.item(b).get("dr", Game.item(b).get("heal", 0)))))
		_: ids.sort_custom(func(a, b): return Game.iname(a) < Game.iname(b))
	return ids

func _items() -> void:
	var lr := _split(1.0)
	var L: VBoxContainer = lr[0]
	var R: VBoxContainer = lr[1]
	var top := HBoxContainer.new()
	L.add_child(top)
	var w := 0.0
	for k in Game.inv:
		if String(Game.item(k).get("t", "junk")) == item_cat:
			w += float(Game.item(k).get("w", 0)) * Game.count(k)
	var wl := _label(top, "%.1f lbs here" % w, 16, DIM)
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var order := ["name", "damage", "value", "weight"]
	_button(top, "SORT: " + sort_by.to_upper(), func():
		sort_by = order[(order.find(sort_by) + 1) % order.size()]
		show_tab(current), 170)
	var list := _scroll(L)
	var ids := _sorted_ids()
	if ids.is_empty():
		_label(list, "Nothing here.", 17, DIM)
	if selected == "" and not ids.is_empty():
		selected = ids[0]
	for id in ids:
		var it := Game.item(id)
		var mark := ""
		if id == Game.weapon or id == Game.armor:
			mark = "  [E]"
		var extra := ""
		if it.has("dmg"):
			extra = "   DMG %d" % int(it.dmg)
		elif it.has("dr"):
			extra = "   DR %d" % int(it.dr)
		elif it.has("heal"):
			extra = "   +%d HP" % int(it.heal)
		var b := _list_button(list, Game.iname(id) + (" (" + str(Game.count(id)) + ")" if Game.count(id) > 1 else "") + mark + extra, id == selected, func():
			selected = id
			show_tab(current))
		if id == Game.weapon or id == Game.armor:
			b.add_theme_color_override("font_color", BRIGHT if id != selected else AMBERC)
	if selected == "" or not Game.has(selected):
		_label(R, "Carrying %.0f / %.0f lbs" % [Game.carry_now(), Game.carry_max()], 17, DIM)
		return
	_item_card(R, selected)

# compare a number with what's equipped: green if better, red if worse
func _cmp(parent: Node, k: String, v: float, eq, fmt := "%.0f", higher_better := true) -> void:
	var txt := fmt % v
	var col := GREEN
	if eq != null and absf(v - float(eq)) > 0.001:
		var better: bool = (v > float(eq)) == higher_better
		txt += "  (%s%s)" % ["+" if v > float(eq) else "-", fmt % absf(v - float(eq))]
		col = GREEN if better else BAD
	_row(parent, k, txt, col)

func _item_card(R: VBoxContainer, id: String) -> void:
	var it := Game.item(id)
	var t := String(it.get("t", ""))
	_title(R, Game.iname(id) + ("  +%d" % int(Game.upgrades[id]) if int(Game.upgrades.get(id, 0)) > 0 else ""))
	_label(R, String(it.get("desc", "")), 17)
	if t == "weapon":
		var eq := Game.item(Game.weapon) if Game.weapon != "" and Game.weapon != id else {}
		var dps := func(x: Dictionary) -> float:
			return float(x.get("dmg", 0)) * float(x.get("pellets", 1)) / maxf(0.05, float(x.get("rof", 0.5)))
		_cmp(R, "Damage", float(it.get("dmg", 0)) * float(it.get("pellets", 1)), (float(eq.get("dmg", 0)) * float(eq.get("pellets", 1))) if not eq.is_empty() else null)
		_cmp(R, "Damage per second", dps.call(it), dps.call(eq) if not eq.is_empty() else null)
		_cmp(R, "Shots per second", 1.0 / maxf(0.05, float(it.get("rof", 0.5))), (1.0 / maxf(0.05, float(eq.get("rof", 0.5)))) if not eq.is_empty() else null, "%.1f")
		if it.has("range"):
			_cmp(R, "Range", float(it.range), eq.get("range") if not eq.is_empty() else null, "%.0f m")
		if it.has("spread"):
			_cmp(R, "Accuracy", 100.0 - float(it.spread) * 600.0, (100.0 - float(eq.spread) * 600.0) if eq.has("spread") else null, "%.0f")
		if it.has("mag"):
			_cmp(R, "Magazine", float(it.mag), eq.get("mag") if not eq.is_empty() else null)
			_row(R, "Ammunition", "%s  (%d carried)" % [Game.iname(it.get("ammo")), Game.count(String(it.get("ammo", "")))])
		_row(R, "Type", String(it.get("kind", "")).capitalize())
	elif t == "armor":
		var eqa := Game.item(Game.armor) if Game.armor != "" and Game.armor != id else {}
		_cmp(R, "Damage resistance", float(it.get("dr", 0)), eqa.get("dr", 0) if Game.armor != "" and Game.armor != id else null)
	elif t == "aid":
		if it.has("heal"):
			_row(R, "Heals", "+%d HP" % int(it.heal))
		var D: Dictionary = Game.L.get("consts", {}).get("DRUGS", {}).get(id, {})
		if not D.is_empty():
			_row(R, "Lasts", "%ds" % int(D.get("dur", 0)))
			_row(R, "Addiction risk", "%d%%" % int(float(D.get("addict", 0)) * 100.0), BAD if float(D.get("addict", 0)) > 0.1 else GREEN)
			if D.has("stats"):
				for st in D.stats:
					_row(R, String(Game.DB.statinfo.get(st, [st])[0]), "%+d" % int(D.stats[st]))
	_row(R, "Weight", "%s lbs" % str(it.get("w", 0)))
	_row(R, "Value", "%s caps" % str(it.get("v", 0)))
	if Game.count(id) > 1:
		_row(R, "Carried", str(Game.count(id)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	R.add_child(row)
	var equipped: bool = id == Game.weapon or id == Game.armor
	if t in ["weapon", "armor", "aid"] and not equipped:
		var u := "EQUIP" if t != "aid" else (("READIED" if Game.nade == id else "READY") if it.get("throw", false) else "USE")
		_button(row, u, func():
			Game.use_item(id)
			show_tab(current), 130)
		if Game.can_ready(id):
			_button(row, "ON CHEM BUTTON" if Game.chem == id else "READY", func():
				Game.chem = "" if Game.chem == id else id
				Game.msg((Game.iname(id) + " is on the CHEM button.") if Game.chem == id else "CHEM button cleared.")
				Game.stats_changed.emit()
				show_tab(current), 180)
	if equipped:
		_label(row, "Equipped", 17, AMBERC)
		_button(row, "UNEQUIP", func():
			Game.unequip(id)
			show_tab(current), 140)
	if t != "quest" and not equipped:
		_button(row, "DROP", func():
			Game.take(id, 1)
			if not Game.has(id):
				selected = ""
			show_tab(current), 110)
		if Game.count(id) > 1:
			_button(row, "DROP ALL", func():
				Game.take(id, Game.count(id))
				selected = ""
				show_tab(current), 140)

# ---------------------------------------------------------------- DATA: QUESTS
func _quests() -> void:
	var lr := _split(0.9)
	var L: VBoxContainer = _scroll(lr[0])
	var R: VBoxContainer = lr[1]
	var active := []
	var done := []
	for q in Game.quests:
		(done if Game.quests[q].done else active).append(q)
	active.sort_custom(func(a, b): return int(Game.qdef(a).get("main", false)) > int(Game.qdef(b).get("main", false)))
	if sel_quest == "" or not Game.quests.has(sel_quest):
		sel_quest = String(Game.flags.get("track", active[0] if not active.is_empty() else ""))
	_title(L, "Active")
	if active.is_empty():
		_label(L, "No active quests. Talk to people.", 16, DIM)
	for q in active:
		var tracked: bool = Game.flags.get("track") == q
		var b := _list_button(L, ("◆ " if tracked else "") + String(Game.qdef(q).t) + ("  [MAIN]" if Game.qdef(q).get("main", false) else ""), q == sel_quest, func():
			sel_quest = q
			show_tab("QUESTS"))
		if tracked and q != sel_quest:
			b.add_theme_color_override("font_color", AMBERC)
	_title(L, "Completed")
	if done.is_empty():
		_label(L, "None yet.", 16, DIM)
	for q in done:
		var failed: bool = Game.quests[q].get("failed", false)
		var b := _list_button(L, String(Game.qdef(q).get("t", q)) + ("  [FAILED]" if failed else ""), q == sel_quest, func():
			sel_quest = q
			show_tab("QUESTS"))
		if q != sel_quest:
			b.add_theme_color_override("font_color", DIM)
	if sel_quest == "":
		return
	var d: Dictionary = Game.qdef(sel_quest)
	var finished: bool = Game.quests[sel_quest].done
	_title(R, String(d.get("t", sel_quest)))
	if d.get("main", false):
		_label(R, "Main quest", 15, AMBERC)
	if d.has("desc"):
		_label(R, Game.subst(Game.vm.to_str(Game.vm.val(d.desc, [Game.G]))), 17)
	_label(R, "LOG", 17, BRIGHT)
	var stages: Array = d.get("stages", [])
	var cur := Game.stage(sel_quest)
	for i in stages.size():
		if i > cur and not finished:
			break
		var txt := Game.subst(Game.vm.to_str(Game.vm.val(stages[i].get("txt", ""), [Game.G])))
		var now: bool = i == cur and not finished
		_label(R, ("► " if now else "✓ ") + txt, 17, BRIGHT if now else DIM)
	if finished and Game.quests[sel_quest].get("failed", false):
		_label(R, "✗ Failed.", 17, Color(0.9, 0.4, 0.3))
	elif finished:
		_label(R, "✓ Done.", 17, AMBERC)
	var rw: Dictionary = d.get("reward", {})
	if not rw.is_empty():
		var parts := []
		if rw.has("xp"):
			parts.append("%s XP" % str(rw.xp))
		if rw.has("caps"):
			parts.append("%s caps" % str(rw.caps))
		for k in rw:
			if not k in ["xp", "caps", "karma"] and Game.DB.items.has(k):
				parts.append(Game.iname(k))
		if not parts.is_empty():
			_label(R, "Reward: " + ", ".join(parts), 16, DIM)
	if not finished:
		var qt = null
		if Game.flags.get("track") == sel_quest:
			qt = Game.quest_target()
		if qt != null and Game.player:
			_label(R, "Objective is %.0f m away." % Vector2(qt.x - Game.player.global_position.x, qt.z - Game.player.global_position.z).length(), 16, DIM)
		if Game.flags.get("track") != sel_quest:
			var qq := sel_quest
			_button(R, "TRACK THIS QUEST", func():
				Game.flags["track"] = qq
				Game.flags["track_manual"] = true
				Game.quest_changed.emit()
				show_tab("QUESTS"))
		else:
			_label(R, "Being tracked.", 16, AMBERC)

# ---------------------------------------------------------------- DATA: FACTIONS
var sel_fac := ""
func _factions() -> void:
	var F: Dictionary = Game.STORY.get("factions", {})
	if F.is_empty():
		_label(body, "No word on the valley's powers yet.", 17, DIM)
		return
	var lr := _split(0.9)
	var L: VBoxContainer = _scroll(lr[0])
	var R: VBoxContainer = lr[1]
	if not F.has(sel_fac):
		sel_fac = F.keys()[0]
	for f in F:
		var r := Game.rep_of(f)
		var row := HBoxContainer.new()
		L.add_child(row)
		var b := _list_button(row, String(F[f].n), f == sel_fac, func():
			sel_fac = f
			show_tab("FACTIONS"))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := _label(row, Game.rep_title(r), 16, BAD if r <= -2 else (AMBERC if r >= 6 else (GREEN if r >= 2 else DIM)))
		t.custom_minimum_size = Vector2(110, 0)
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
	var d: Dictionary = F[sel_fac]
	var rr := Game.rep_of(sel_fac)
	_title(R, String(d.n))
	_row(R, "Led by", String(d.leader))
	var hb := HBoxContainer.new()
	R.add_child(hb)
	_label(hb, "Standing: %s (%+d)" % [Game.rep_title(rr), rr], 17, AMBERC).custom_minimum_size = Vector2(240, 0)
	var bar := _bar(float(rr + 10), 20.0, BAD if rr < 0 else GREEN, 200)
	hb.add_child(bar)
	_label(R, String(d.desc), 17)
	var p = Game.flags.get("pledge")
	if p != null:
		if String(p) == sel_fac:
			_label(R, "You pledged the Meridian core to them.", 17, AMBERC)
		elif String(p) == "none" and sel_fac != "spur":
			_label(R, "You told the council you'd decide at the core.", 16, DIM)
	var effects := []
	if Game.STORY.get("vendor_faction", {}).values().has(sel_fac) and sel_fac != "dustwell":
		effects.append("Their traders' prices move with your standing (up to 15%).")
	if sel_fac == "dustwell":
		effects.append("Dustwell's traders give you better prices as your standing rises.")
	if not effects.is_empty():
		_label(R, "\n".join(effects), 15, DIM)
	_label(R, "Work done for them raises your standing; so do the promises you keep.", 15, DIM)

# ---------------------------------------------------------------- DATA: PARTY (companions and what they think of you)
const COMP_INFO := {
	"jory": ["Likes decency, keeping your word, Finch. Hates cruelty and anyone hurt who wasn't shooting.", "Loyal: hits 30% harder, 25% tougher, stays whatever your karma.", "jory_wagon"],
	"sable": ["Likes trouble, taking what you want, the Spur's tables. Hates sermons and saints.", "Loyal: hits 30% harder, 25% tougher, stays whatever your karma.", "sable_ledger"],
	"renn2": ["Likes a second chance given, Saltreach, honest work. Hates bribes, raiders and the Gulch.", "Loyal: hits 30% harder, 25% tougher, stays whatever your karma.", "old_colours"],
	"biscuit": ["Likes you. Likes everything about you. Also bones.", "A good dog. Already loyal.", "good_boy"],
}
var sel_comp := ""
func _party() -> void:
	var known: Array = []
	for id in COMP_INFO:
		if Game.main and Game.main.party.any(func(p): return p.id == id):
			known.append(id)
		elif Game.flags.has("appr_" + id) or Game.flags.has("left_" + id) or (id == "biscuit" and Game.flags.has("biscuit")):
			known.append(id)
	if known.is_empty():
		_label(body, "Nobody's walking with you yet. Jory Vance hires out at the Dry Overpass; Sable is bored at Gantry Yard; and Saltreach might lend you a deputy once it trusts one.", 17, DIM)
		return
	var lr := _split(0.9)
	var L: VBoxContainer = _scroll(lr[0])
	var R: VBoxContainer = lr[1]
	if not known.has(sel_comp):
		sel_comp = known[0]
	for id in known:
		var row := HBoxContainer.new()
		L.add_child(row)
		var nm := String(Game.L.companions.get(id, {}).get("n", id))
		var b := _list_button(row, nm, id == sel_comp, func():
			sel_comp = id
			show_tab("PARTY"))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var a := Game.approval(id)
		var t := _label(row, "Loyal" if Game.is_loyal(id) or id == "biscuit" else Game.approval_title(a), 16, AMBERC if Game.is_loyal(id) or id == "biscuit" else (BAD if a <= -15 else (GREEN if a >= 15 else DIM)))
		t.custom_minimum_size = Vector2(120, 0)
	var c: Dictionary = Game.L.companions.get(sel_comp, {})
	_title(R, String(c.get("n", sel_comp)))
	var with_me: bool = Game.main != null and Game.main.party.any(func(p): return p.id == sel_comp)
	var st := "Travelling with you" if with_me else ("Left you" if Game.flags.has("left_" + sel_comp) else "Back home")
	if with_me and Game.main.party_state(sel_comp) == "wait":
		st = "Waiting where you left them"
	_row(R, "Status", st)
	if sel_comp != "biscuit":
		var a := Game.approval(sel_comp)
		var hb := HBoxContainer.new()
		R.add_child(hb)
		_label(hb, "Approval: %s (%+d)" % ["Loyal" if Game.is_loyal(sel_comp) else Game.approval_title(a), a], 17, AMBERC).custom_minimum_size = Vector2(250, 0)
		hb.add_child(_bar(float(a + 100), 200.0, BAD if a < 0 else GREEN, 200))
	var info: Array = COMP_INFO[sel_comp]
	_label(R, String(info[0]), 16)
	_label(R, String(info[1]), 16, AMBERC if Game.is_loyal(sel_comp) or sel_comp == "biscuit" else DIM)
	var q := String(info[2])
	if Game.quests.has(q):
		_row(R, "Their quest", String(Game.qdef(q).get("t", q)) + ("  (done)" if Game.quests[q].done else "  (active)"))
	elif sel_comp != "biscuit":
		_label(R, "They have something on their mind. Ask them, out on the road.", 15, DIM)
	if sel_comp != "biscuit" and not Game.is_loyal(sel_comp):
		_label(R, "At 30 approval they'll open up about themselves. Talk to them.", 15, DIM)

# ---------------------------------------------------------------- DATA: NOTES
func _notes() -> void:
	var lr := _split(0.8)
	var L: VBoxContainer = _scroll(lr[0])
	var R: VBoxContainer = lr[1]
	var read := []
	for k in Game.DB.lore:
		if Game.flags.has("read_" + k):
			read.append(k)
	_title(L, "Terminal entries")
	if read.is_empty():
		_label(L, "Read terminals to keep copies here.", 16, DIM)
	if sel_note == "" and not read.is_empty():
		sel_note = read[0]
	for k in read:
		var h := String(Game.DB.lore[k].get("h", k))
		_list_button(L, h.substr(0, 40), k == sel_note, func():
			sel_note = k
			show_tab("NOTES"))
	if sel_note != "" and Game.DB.lore.has(sel_note):
		var l: Dictionary = Game.DB.lore[sel_note]
		_title(R, String(l.get("h", sel_note)))
		_label(R, String(l.get("t", "")), 16)

# ---------------------------------------------------------------- RADIO
func _radio() -> void:
	var lr := _split(1.0)
	var L: VBoxContainer = _scroll(lr[0])
	var R: VBoxContainer = lr[1]
	_title(L, "Stations")
	for i in Game.main.STATIONS.size():
		var st: Dictionary = Game.main.STATIONS[i]
		var open: bool = Game.main.station_open(i)
		var on: bool = Game.main.radio_on and Game.main.station == i
		var idx: int = i
		var b := _list_button(L, String(st.n) + ("   ON AIR" if on else ("" if open else "   (no signal)")), on, func():
			Game.main.tune(idx)
			show_tab("RADIO"))
		b.disabled = not open
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	L.add_child(row)
	_button(row, "TURN OFF" if Game.main.radio_on else "TURN ON", func():
		Game.main.set_radio(not Game.main.radio_on)
		show_tab("RADIO"), 150)
	if Game.main.radio_on:
		_button(row, "NEXT", func():
			Game.main.radio_skip()
			show_tab("RADIO"), 110)
	if Game.main.radio_on and Game.main.now_playing != "":
		_label(L, "Now playing: " + Game.main.now_playing, 17, AMBERC)
	if not Game.main.station_open(1):
		_label(L, "Somewhere north a transmitter is waiting for someone to fix it.", 15, DIM)
	_title(R, "Broadcasts received")
	var heard: Array = Game.flags.get("heard", [])
	if heard.is_empty():
		_label(R, "Nothing yet. Broadcasts arrive as you change the valley.", 16, DIM)
	for k in heard:
		var r: Dictionary = Game.L.radio.get(k, {})
		var bb := _list_button(R, String(r.get("h", k)), false, func():
			Game.main.hud.toggle_pip()
			Game.main.broadcast(k))

# ---------------------------------------------------------------- CRAFT
# a recipe's ingredients; the two upgrade recipes cost more each level (main.js recipeNeed)
func recipe_need(r: Dictionary) -> Variant:
	var id := String(r.get("id", ""))
	if id == "up_w":
		if Game.weapon == "":
			return null
		var l := int(Game.upgrades.get(Game.weapon, 0))
		if l >= 3:
			return null
		var n := {"scrap_metal": 2 + 2 * l, "duct_tape": 1 + l}
		if l > 0:
			n["gears"] = l
		if String(Game.item(Game.weapon).get("kind", "")) == "energy":
			n["circuit"] = 1 + l
		return n
	if id == "up_a":
		if Game.armor == "":
			return null
		var l := int(Game.upgrades.get(Game.armor, 0))
		if l >= 3:
			return null
		return {"scrap_metal": 3 + 2 * l, "duct_tape": 1 + l}
	return r.get("need", {})

func _craft() -> void:
	var v := _scroll()
	_label(v, "WORKBENCH", 21, Color(1.0, 0.92, 0.6))
	_label(v, "Tools ready." if at_bench else "You need to be at a workbench to craft. There is one in Dustwell and one in Bunker Nine.", 18, DIM)
	_label(v, "Scrap %d  ·  Tape %d  ·  Circuits %d  ·  Gears %d" % [Game.count("scrap_metal"), Game.count("duct_tape"), Game.count("circuit"), Game.count("gears")], 18)
	for r in Game.L.get("recipes", []):
		if r.has("flag") and not Game.flags.get(String(r.flag)):
			continue
		var need = recipe_need(r)
		var nm := String(r.get("n", r.get("id", "")))
		if r.get("id") == "up_w":
			nm = ("Tune " + Game.iname(Game.weapon) + "  (level %d)" % int(Game.upgrades.get(Game.weapon, 0))) if Game.weapon != "" else "Tune weapon (none equipped)"
		elif r.get("id") == "up_a":
			nm = ("Reinforce " + Game.iname(Game.armor) + "  (level %d)" % int(Game.upgrades.get(Game.armor, 0))) if Game.armor != "" else "Reinforce armor (none worn)"
		var ok: bool = need != null
		var parts := []
		if need != null:
			for k in need:
				var have := Game.count(k)
				parts.append("%s %d/%d" % [Game.iname(k), have, int(need[k])])
				if have < int(need[k]):
					ok = false
		var row := HBoxContainer.new()
		v.add_child(row)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(box)
		_label(box, nm, 20, Color(0.85, 1.0, 0.85))
		_label(box, ("  ·  ".join(parts) if need != null else "Fully upgraded") + ("  —  " + String(r.d) if r.has("d") else ""), 16, DIM if ok else Color(0.75, 0.55, 0.4))
		var b := Button.new()
		b.text = "CRAFT" if r.has("out") else "UPGRADE"
		b.custom_minimum_size = Vector2(140, 50)
		b.disabled = not at_bench or not ok
		b.pressed.connect(func():
			for k in need:
				Game.take(k, int(need[k]))
			if r.has("out"):
				Game.give(String(r.out[0]), int(r.out[1]))
				Game.msg("Crafted " + String(r.n))
			else:
				var id: String = Game.weapon if r.id == "up_w" else Game.armor
				Game.upgrades[id] = int(Game.upgrades.get(id, 0)) + 1
				Game.msg(Game.iname(id) + " upgraded")
			Sfx.play("k_metal_latch", -2.0)
			Game.check_quests()
			show_tab("CRAFT"))
		row.add_child(b)

# ---------------------------------------------------------------- GUNSMITH (build 14)
# a gun you own on the left; on the right its numbers, and its six slots with the mods that fit it
var sel_gun := ""
const SLOTS := ["barrel", "receiver", "magazine", "sight", "muzzle", "stock"]
func _gunsmith() -> void:
	var lr := _split(0.8)
	var L: VBoxContainer = lr[0]
	var R: VBoxContainer = lr[1]
	var guns: Array = []
	for id in Game.inv:
		var it: Dictionary = Game.DB.items.get(id, {})
		if String(it.get("t", "")) == "weapon" and String(it.get("kind", "")) != "melee":
			guns.append(id)
	if guns.is_empty():
		_label(L, "No guns to work on.", 18, DIM)
		return
	if not sel_gun in guns:
		sel_gun = Game.weapon if Game.weapon in guns else String(guns[0])
	var sc := _scroll(L)
	for id in guns:
		var gid: String = id
		_list_button(sc, Game.iname(gid) + ("  *" if Game.mods.has(gid) else ""), gid == sel_gun, func():
			sel_gun = gid
			show_tab("GUNSMITH"))
	var base: Dictionary = Game.DB.items.get(sel_gun, {})
	var it: Dictionary = Game.item(sel_gun)
	_title(R, Game.iname(sel_gun))
	if not at_bench:
		_label(R, "Fitting parts needs a workbench (Dustwell, Bunker Nine). You can look.", 16, Color(0.85, 0.65, 0.4))
	_label(R, "Scrap %d  ·  Gears %d  ·  Circuits %d  ·  Tape %d" % [Game.count("scrap_metal"), Game.count("gears"), Game.count("circuit"), Game.count("duct_tape")], 16, DIM)
	var stat := func(nm: String, a: float, b: float, fmt: String, better_low := false) -> void:
		var col := GREEN
		if not is_equal_approx(a, b):
			col = Color(0.5, 1.0, 0.5) if ((b < a) == better_low) else Color(1.0, 0.6, 0.45)
		_row(R, nm, (fmt % b) + ("" if is_equal_approx(a, b) else ("   (was " + fmt % a + ")")), col)
	stat.call("Damage", float(base.get("dmg", 0)), float(it.get("dmg", 0)), "%.0f")
	stat.call("Shots a second", 1.0 / maxf(0.01, float(base.get("rof", 0.3))), 1.0 / maxf(0.01, float(it.get("rof", 0.3))), "%.1f")
	if base.has("mag"):
		stat.call("Magazine", float(base.get("mag", 0)), float(it.get("mag", 0)), "%.0f")
	stat.call("Spread", float(base.get("spread", 0.02)) * 1000.0, float(it.get("spread", 0.02)) * 1000.0, "%.0f", true)
	stat.call("Range", float(base.get("range", 100)), float(it.get("range", 100)), "%.0f m")
	stat.call("Reload time", 1.0, float(it.get("reload_k", 1.0)), "x%.2f", true)
	var kind := String(base.get("kind", ""))
	var M: Dictionary = Game.ARSENAL.get("mods", {})
	var fitted: Dictionary = Game.mods.get(sel_gun, {})
	for slot in SLOTS:
		var opts: Array = []
		for mid in M:
			if String(M[mid].slot) == slot and kind in M[mid].kinds:
				opts.append(mid)
		if opts.is_empty():
			continue
		_label(R, "\n" + slot.to_upper() + ":  " + (String(M[fitted[slot]].n) if fitted.has(slot) else "standard"), 18, AMBERC)
		if fitted.has(slot):
			var s2: String = slot
			_button(R, "REMOVE " + String(M[fitted[slot]].n).to_upper(), func():
				Game.strip_mod(sel_gun, s2)
				_after_mod()
				show_tab("GUNSMITH"), 0.0, not at_bench)
		for mid in opts:
			if fitted.get(slot) == mid:
				continue
			var md: Dictionary = M[mid]
			var cost: Dictionary = md.cost
			var ok := true
			var parts := []
			for k in cost:
				parts.append("%s %d/%d" % [Game.iname(k), Game.count(k), int(cost[k])])
				if Game.count(k) < int(cost[k]):
					ok = false
			_label(R, String(md.n) + "  —  " + String(md.desc), 16)
			_label(R, "  ".join(parts), 15, DIM if ok else Color(0.75, 0.55, 0.4))
			var m2: String = mid
			_button(R, "FIT " + String(md.n).to_upper(), func():
				for k in cost:
					Game.take(k, int(cost[k]))
				Game.fit_mod(sel_gun, m2)
				Sfx.play("k_metal_latch", -2.0)
				Game.msg(String(md.n) + " fitted to the " + Game.iname(sel_gun) + ".")
				_after_mod()
				show_tab("GUNSMITH"), 0.0, not (at_bench and ok))

# the gun in your hands shows its new parts straight away
func _after_mod() -> void:
	if sel_gun == Game.weapon and Game.player:
		Game.player.weapon_changed()

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
	if Game.interior():
		_label(body, "HAVEN 12 — LEVEL ONE", 22, Color(1.0, 0.9, 0.6))
		_label(body, "No signal underground. The map and fast travel work once you're on the surface.", 19, DIM)
		var o := Game.current_objective()
		if not o.is_empty():
			_label(body, "\n" + String(o.title).to_upper() + "\n" + String(o.text), 19)
		return
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
		var qt = Game.quest_target()
		if qt != null:
			var q: Vector2 = to_map.call(qt.x, qt.z)
			draw_arc(q, 9.0, 0, TAU, 24, Color(1.0, 0.82, 0.3), 2.5)
			draw_circle(q, 3.0, Color(1.0, 0.82, 0.3))
			var o := Game.current_objective()
			if not o.is_empty():
				draw_string(f, q + Vector2(12, -8), String(o.title), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.85, 0.4))
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
	g.text = "Graphics: " + Quality.label(Game.main.quality) + "  (tap to change)"
	g.custom_minimum_size = Vector2(0, 54)
	g.pressed.connect(func():
		Game.main.cycle_quality()
		show_tab("SYSTEM"))
	v.add_child(g)
	_label(v, "Ashfall: Meridian, Godot build. Autosaves every three minutes.", 16, DIM)
