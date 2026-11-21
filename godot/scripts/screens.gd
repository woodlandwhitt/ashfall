# The full-screen panels that pause the game: BARTER (buy, sell, buy back; each vendor has a purse, a mark-up, tastes,
# stock that resets at sunrise and one deal of the day), LOOT (a container or a body: take one or take all),
# LOCKPICK (the original's bobby-pin minigame: drag to angle the pin, hold TURN; near the sweet spot the cylinder
# turns further, forcing it bends and snaps the pin), TERMINAL (green-screen text typed out) and the BANNER
# (quest complete, karma title, level up).
class_name Screens
extends Control

const GREEN := Color(0.55, 1.0, 0.6)
const DIM := Color(0.35, 0.7, 0.42)
const RED := Color(1.0, 0.45, 0.35)
const LOCKS := [{"n": "Easy", "need": 3, "w": 0.34}, {"n": "Average", "need": 5, "w": 0.22}, {"n": "Hard", "need": 7, "w": 0.13}, {"n": "Very Hard", "need": 9, "w": 0.075}]

var panel: PanelContainer
var body: VBoxContainer
var mode := ""
var on_close: Callable
var banner_l: Label
var banner_s: Label
var banner_box: VBoxContainer
# barter
var shop_id := ""
var shop_tab := "buy"
var shop_qty := 1
var shop_info := ""
# loot
var loot_name := ""
var loot_items: Array = []
var loot_done: Callable
# lockpick
var lp: Dictionary = {}
var lp_dial: Control
var lp_hold := false
var lp_pins: Label
# terminal
var term_text := ""
var term_i := 0
var term_l: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 18
	panel.offset_right = -24
	panel.offset_bottom = -18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.06, 0.03, 0.96)
	sb.border_color = Color(0.3, 0.8, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.theme = pip_theme()
	add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	panel.visible = false
	# banner across the top third, over everything, never blocks input
	banner_box = VBoxContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner_box.offset_top = 120
	banner_box.offset_bottom = 230
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(banner_box)
	banner_l = Label.new()
	banner_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_l.add_theme_font_size_override("font_size", 40)
	banner_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	banner_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	banner_l.add_theme_constant_override("outline_size", 8)
	banner_box.add_child(banner_l)
	banner_s = Label.new()
	banner_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_s.add_theme_font_size_override("font_size", 22)
	banner_s.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	banner_s.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	banner_s.add_theme_constant_override("outline_size", 6)
	banner_box.add_child(banner_s)
	banner_box.modulate.a = 0.0

static func pip_theme() -> Theme:
	var th := Theme.new()
	th.set_color("font_color", "Label", GREEN)
	th.set_color("font_color", "Button", GREEN)
	th.set_color("font_hover_color", "Button", Color(0.85, 1.0, 0.85))
	th.set_color("font_pressed_color", "Button", Color(0.02, 0.1, 0.04))
	th.set_color("font_disabled_color", "Button", Color(0.25, 0.45, 0.3))
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.05, 0.16, 0.08)
	bn.set_corner_radius_all(4)
	bn.set_content_margin_all(8)
	var bp := bn.duplicate()
	bp.bg_color = Color(0.45, 0.9, 0.5)
	th.set_stylebox("normal", "Button", bn)
	th.set_stylebox("hover", "Button", bn)
	th.set_stylebox("pressed", "Button", bp)
	th.set_stylebox("disabled", "Button", bn)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_font_size("font_size", "Button", 20)
	th.set_font_size("font_size", "Label", 19)
	return th

func is_open() -> bool:
	return panel.visible

func _open(m: String) -> void:
	mode = m
	panel.visible = true
	Game.paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.main and Game.main.hud:
		Game.main.hud.touch.visible = false
		Game.main.hud.set_prompt("")

func close() -> void:
	if not panel.visible:
		return
	var m := mode
	panel.visible = false
	mode = ""
	lp = {}
	Game.paused = false
	get_tree().paused = false
	if Game.main and Game.main.hud:
		Game.main.hud.touch.visible = Game.main.hud.touch_on
	if m == "loot" and loot_done.is_valid():
		loot_done.call(loot_items.is_empty())
	if on_close.is_valid():
		var c := on_close
		on_close = Callable()
		c.call()

func _clear() -> void:
	for c in body.get_children():
		c.queue_free()

func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	body.add_child(h)
	return h

func _label(parent: Node, t: String, size := 19, col := GREEN) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(l)
	return l

func _button(parent: Node, t: String, cb: Callable, w := 0.0, on := true) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, 50)
	b.disabled = not on
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _scroll() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	sc.add_child(v)
	return v

func _unhandled_key_input(e: InputEvent) -> void:
	if not panel.visible or not e.pressed:
		return
	if e.keycode == KEY_ESCAPE or (e.keycode == KEY_TAB and mode != "lockpick"):
		close()
		get_viewport().set_input_as_handled()
	elif mode == "lockpick":
		if e.keycode == KEY_A or e.keycode == KEY_LEFT:
			_lp_angle(-0.06)
		elif e.keycode == KEY_D or e.keycode == KEY_RIGHT:
			_lp_angle(0.06)
	elif mode == "loot" and e.keycode == KEY_E:
		_take_all()

func _input(e: InputEvent) -> void:
	if mode == "lockpick" and e is InputEventKey and (e.keycode == KEY_SPACE or e.keycode == KEY_E) and not e.echo:
		lp_hold = e.pressed
		get_viewport().set_input_as_handled()

# ================================================================ BANNER
func banner(title: String, sub: String) -> void:
	banner_l.text = title
	banner_s.text = sub
	var tw := banner_box.create_tween()
	tw.tween_property(banner_box, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.6)
	tw.tween_property(banner_box, "modulate:a", 0.0, 0.8)

# ================================================================ BARTER
func open_trade(id: String) -> void:
	var v: Dictionary = Game.vendor(id)
	if v.is_empty():
		Game.msg("They have nothing to trade.")
		return
	shop_id = id
	shop_tab = "buy"
	shop_qty = 1
	shop_info = ""
	_open("trade")
	Sfx.play("k_click", -8.0)
	_render_trade()

func _price_mod() -> float:
	var v: Dictionary = Game.vendor(shop_id)
	var m := (int(Game.stats.charm) - 5) * 0.03 + (0.1 if Game.perks.has("haggler") else 0.0)
	if v.get("town", false):
		m += minf(0.16, float(Game.flags.get("rep", 0)) * 0.02) + clampf(Game.karma / 100.0, -1.0, 1.0) * 0.08
	if shop_id == "kess":
		m += clampf(-Game.karma / 100.0, -1.0, 1.0) * 0.1
	if shop_id == "finch" and Game.flags.get("finchFriend"):
		m += 0.15
	if shop_id == "cass" and Game.flags.get("tomas") == "truth":
		m += 0.2
	return clampf(m, -0.2, 0.45)

func buy_price(id: String) -> int:
	var v: Dictionary = Game.vendor(shop_id)
	var st: Dictionary = Game.shop_state(shop_id)
	var deal := 0.7 if st.get("deal") == id and shop_tab != "sell" else 1.0
	return maxi(1, ceili(float(Game.item(id).get("v", 1)) * float(v.get("buy", 1.3)) * (1.0 - _price_mod()) * deal))

func sell_price(id: String) -> int:
	var v: Dictionary = Game.vendor(shop_id)
	var it := Game.item(id)
	var like := float(v.get("likes", {}).get(String(it.get("t", "")), 1.0))
	var iv := float(it.get("v", 1))
	return maxi(1, mini(buy_price(id) - (1 if iv > 2 else 0), floori(iv * float(v.get("sell", 0.5)) * like * (1.0 + _price_mod() * 0.8))))

func _sellable(id: String) -> int:
	return Game.count(id) - (1 if Game.weapon == id or Game.armor == id else 0)

func _trade(id: String) -> void:
	var st: Dictionary = Game.shop_state(shop_id)
	var nm := Game.iname(id)
	match shop_tab:
		"buy":
			var p := buy_price(id)
			var n := mini(shop_qty, mini(int(st.stock.get(id, 0)), Game.caps / p))
			if n < 1:
				Sfx.play("k_metal_click", -6.0)
				shop_info = "Not enough chits."
			else:
				Game.caps -= p * n
				st.caps += p * n
				st.stock[id] = int(st.stock[id]) - n
				if int(st.stock[id]) <= 0:
					st.stock.erase(id)
				Game.give(id, n)
				Sfx.play("k_coins", -4.0)
				shop_info = "Bought %d %s for %d." % [n, nm, p * n]
		"sell":
			var p := sell_price(id)
			var n := mini(shop_qty, mini(_sellable(id), int(st.caps) / p))
			if n < 1:
				Sfx.play("k_metal_click", -6.0)
				shop_info = "You are using that." if _sellable(id) < 1 else String(Game.vendor(shop_id).name) + " cannot afford it."
			else:
				Game.take(id, n)
				Game.caps += p * n
				st.caps -= p * n
				var found := false
				for b in st.back:
					if b[0] == id and int(b[2]) == p:
						b[1] = int(b[1]) + n
						found = true
				if not found:
					st.back.append([id, n, p])
				Sfx.play("k_coins", -4.0)
				shop_info = "Sold %d %s for %d." % [n, nm, p * n]
		"back":
			for b in st.back:
				if b[0] != id:
					continue
				var n := mini(shop_qty, mini(int(b[1]), Game.caps / int(b[2])))
				if n < 1:
					Sfx.play("k_metal_click", -6.0)
					shop_info = "Not enough chits."
				else:
					Game.caps -= int(b[2]) * n
					st.caps += int(b[2]) * n
					b[1] = int(b[1]) - n
					if int(b[1]) <= 0:
						st.back.erase(b)
					Game.give(id, n)
					Sfx.play("k_coins", -4.0)
					shop_info = "Bought back %d %s." % [n, nm]
				break
	Game.stats_changed.emit()
	_render_trade()

func _render_trade() -> void:
	_clear()
	var v: Dictionary = Game.vendor(shop_id)
	var st: Dictionary = Game.shop_state(shop_id)
	var top := _row()
	var t := _label(top, String(v.name).to_upper(), 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(top, "THEM %d  ·  YOU %d CHITS" % [int(st.caps), Game.caps], 19)
	_button(top, "X", close, 60)
	var chips := _row()
	for k in [["buy", "BUY"], ["sell", "SELL"], ["back", "BUY BACK"]]:
		var b := _button(chips, k[1], func(): shop_tab = k[0]; shop_info = ""; _render_trade(), 130)
		b.modulate = Color(1, 1, 1) if shop_tab == k[0] else Color(0.6, 0.6, 0.6)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_child(sp)
	for q in [1, 5, 25]:
		var b := _button(chips, "x" + str(q), func(): shop_qty = q; _render_trade(), 70)
		b.modulate = Color(1, 1, 1) if shop_qty == q else Color(0.6, 0.6, 0.6)
	var list := _scroll()
	var rows := []
	match shop_tab:
		"buy":
			for id in st.stock:
				rows.append([id, int(st.stock[id]), buy_price(id)])
		"sell":
			for id in Game.inv:
				if _sellable(id) > 0 and String(Game.item(id).get("t", "")) != "quest" and float(Game.item(id).get("v", 0)) > 0:
					rows.append([id, _sellable(id), sell_price(id)])
		"back":
			for b in st.back:
				rows.append([b[0], int(b[1]), int(b[2])])
	var order := ["weapon", "armor", "aid", "ammo", "junk"]
	rows.sort_custom(func(a, b):
		var ta := order.find(String(Game.item(a[0]).get("t", "junk")))
		var tb := order.find(String(Game.item(b[0]).get("t", "junk")))
		return ta < tb if ta != tb else Game.iname(a[0]) < Game.iname(b[0]))
	if rows.is_empty():
		_label(list, {"buy": "Sold out until sunrise.", "sell": "Nothing they'd want.", "back": "Nothing to buy back."}[shop_tab], 18, DIM)
	for r in rows:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		list.add_child(h)
		var deal: bool = shop_tab == "buy" and st.get("deal") == r[0]
		var nl := _label(h, Game.iname(r[0]) + ("  x" + str(r[1]) if r[1] > 1 else "") + ("   DEAL OF THE DAY" if deal else ""), 19, Color(1.0, 0.9, 0.5) if deal else GREEN)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(h, str(r[2]) + " ch", 19, DIM)
		_button(h, "SELL" if shop_tab == "sell" else "BUY", _trade.bind(r[0]), 100)
	_label(body, shop_info if shop_info != "" else "Carrying %.0f / %.0f" % [Game.carry_now(), Game.carry_max()], 18, DIM)

# ================================================================ LOOT
func open_loot(name: String, items: Array, done: Callable) -> void:
	loot_name = name
	loot_items = items
	loot_done = done
	_open("loot")
	Sfx.play("k_cloth1", -6.0)
	_render_loot()

func _take(i: int) -> void:
	var it: Array = loot_items[i]
	if String(it[0]) == "caps":
		Game.caps += int(it[1])
	else:
		Game.give(String(it[0]), int(it[1]))
	loot_items.remove_at(i)
	Sfx.play("k_cloth1", -4.0)
	Game.stats_changed.emit()
	Game.check_quests()
	if loot_items.is_empty():
		close()
	else:
		_render_loot()

func _take_all() -> void:
	while not loot_items.is_empty():
		var it: Array = loot_items.pop_back()
		if String(it[0]) == "caps":
			Game.caps += int(it[1])
		else:
			Game.give(String(it[0]), int(it[1]))
	Sfx.play("k_cloth1", -4.0)
	Game.stats_changed.emit()
	Game.check_quests()
	close()

func _render_loot() -> void:
	_clear()
	var top := _row()
	var t := _label(top, loot_name.to_upper(), 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(top, "TAKE ALL", _take_all, 160)
	_button(top, "X", close, 60)
	var list := _scroll()
	if loot_items.is_empty():
		_label(list, "Empty.", 19, DIM)
	for i in loot_items.size():
		var it: Array = loot_items[i]
		var h := HBoxContainer.new()
		list.add_child(h)
		var nm := (str(it[1]) + " chits") if String(it[0]) == "caps" else Game.iname(it[0]) + ("  x" + str(it[1]) if int(it[1]) > 1 else "")
		var l := _label(h, nm, 20)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(h, "TAKE", _take.bind(i), 110)
	_label(body, "Carrying %.0f / %.0f" % [Game.carry_now(), Game.carry_max()], 18, DIM)

# ================================================================ LOCKPICK
# returns false (with a message) when you can't even try
func open_lock(level: int, label: String, done: Callable) -> bool:
	level = clampi(level, 0, 3)
	var L: Dictionary = LOCKS[level]
	var ag := int(Game.stats.agility)
	var smith := Game.perks.has("locksmith")
	if ag < int(L.need) and not smith:
		Game.msg("%s lock. Requires Agility %d (you have %d)." % [L.n, L.need, ag])
		Sfx.play("k_metal_click", -6.0)
		return false
	if Game.count("bobby_pin") < 1:
		Game.msg("You need a bobby pin to pick this lock.")
		Sfx.play("k_metal_click", -6.0)
		return false
	lp = {"level": level, "L": L, "done": done, "spot": (randf() - 0.5) * PI * 0.9,
		"width": float(L.w) * (1.35 if smith else 1.0) * (1.0 + (ag - int(L.need)) * 0.06), "pin": 0.0, "turn": 0.0, "stress": 0.0, "finished": false}
	lp_hold = false
	_open("lockpick")
	_clear()
	var top := _row()
	var t := _label(top, label.to_upper() + "  ·  " + String(L.n).to_upper(), 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(top, "QUIT", func(): _lp_close(false), 110)
	_label(body, "Drag across the lock to angle the pin. Hold TURN. If the pin strains, ease off and try another angle.", 18, DIM)
	lp_dial = Dial.new()
	lp_dial.scr = self
	lp_dial.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lp_dial.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_child(lp_dial)
	var bot := _row()
	lp_pins = _label(bot, "", 19)
	lp_pins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var turn := Button.new()
	turn.text = "TURN"
	turn.custom_minimum_size = Vector2(220, 80)
	turn.button_down.connect(func(): lp_hold = true)
	turn.button_up.connect(func(): lp_hold = false)
	bot.add_child(turn)
	_lp_pins()
	return true

func _lp_pins() -> void:
	if lp_pins:
		lp_pins.text = "Bobby pins: " + str(Game.count("bobby_pin"))

func _lp_angle(d: float) -> void:
	if lp.is_empty() or lp_hold:
		return
	lp.pin = clampf(float(lp.pin) + d, -PI / 2, PI / 2)

func _lp_close(ok: bool) -> void:
	var cb: Callable = lp.get("done", Callable())
	close()
	if cb.is_valid():
		cb.call(ok)

func _process(d: float) -> void:
	if mode == "lockpick" and not lp.is_empty() and not lp.finished:
		_lp_step(minf(d, 0.05))
		lp_dial.queue_redraw()
	elif mode == "term" and term_i < term_text.length():
		term_i = mini(term_text.length(), term_i + 5)
		term_l.text = term_text.substr(0, term_i) + ("█" if term_i < term_text.length() else "")
		if term_i % 20 < 5:
			Sfx.play("x_computer" + str(randi() % 3), -20.0)

func _lp_step(dt: float) -> void:
	var off := absf(float(lp.pin) - float(lp.spot))
	var mx := 1.0 if off < float(lp.width) else maxf(0.0, 1.0 - (off - float(lp.width)) / (PI * 0.5))
	if lp_hold:
		lp.turn = minf(mx, float(lp.turn) + dt * 1.4)
		if lp.turn >= 0.999 and mx >= 1.0:
			lp.finished = true
			lp_hold = false
			Sfx.play("o_unlock", -2.0)
			Game.msg(String(lp.L.n) + " lock picked.")
			get_tree().create_timer(0.35, true, false, true).timeout.connect(func(): _lp_close(true))
			return
		if lp.turn >= mx - 0.001:
			lp.stress = float(lp.stress) + dt * (1.1 + int(lp.level) * 0.25)
			if randf() < dt * 10.0:
				Sfx.play("k_metal_click", -16.0, 1.6 + randf() * 0.4)
			if lp.stress > 1.0:
				lp.stress = 0.0
				lp.turn = 0.0
				lp_hold = false
				Game.take("bobby_pin", 1)
				Sfx.play("k_metal_latch", -2.0, 1.5)
				Game.msg("The bobby pin snaps.")
				_lp_pins()
				if Game.count("bobby_pin") < 1:
					lp.finished = true
					get_tree().create_timer(0.5, true, false, true).timeout.connect(func(): _lp_close(false))
	else:
		lp.turn = maxf(0.0, float(lp.turn) - dt * 2.2)

# test hook: put the pin on the sweet spot
func lp_solve() -> void:
	if not lp.is_empty():
		lp.pin = lp.spot

class Dial extends Control:
	var scr
	var drag := false
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton or e is InputEventScreenTouch:
			drag = e.pressed
		elif (e is InputEventMouseMotion and drag) or e is InputEventScreenDrag:
			scr._lp_angle(e.relative.x * 0.008)
	func _draw() -> void:
		var st: Dictionary = scr.lp
		if st.is_empty():
			return
		var c := size * Vector2(0.5, 0.52)
		var R := minf(size.x, size.y) * 0.36
		draw_circle(c, R * 1.12, Color(0.42, 0.34, 0.16))
		draw_circle(c, R * 1.04, Color(0.68, 0.58, 0.32))
		draw_arc(c, R * 1.12, 0, TAU, 64, Color(0.16, 0.12, 0.06), 6.0)
		var rot := float(st.turn) * PI / 2
		draw_set_transform(c, rot)
		draw_circle(Vector2.ZERO, R * 0.62, Color(0.54, 0.48, 0.31))
		draw_arc(Vector2.ZERO, R * 0.62, 0, TAU, 48, Color(0.23, 0.19, 0.09), 4.0)
		draw_circle(Vector2(0, -R * 0.12), R * 0.11, Color(0.1, 0.08, 0.04))
		draw_rect(Rect2(-R * 0.05, -R * 0.12, R * 0.1, R * 0.38), Color(0.1, 0.08, 0.04))
		draw_rect(Rect2(-R * 0.03, R * 0.15, R * 0.06, R * 0.9), Color(0.6, 0.6, 0.6))
		draw_rect(Rect2(-R * 0.08, R * 1.0, R * 0.16, R * 0.5), Color(0.69, 0.19, 0.12))
		var wob := (randf() - 0.5) * 0.05 * float(st.stress) if scr.lp_hold and float(st.stress) > 0.0 else 0.0
		draw_set_transform(c, float(st.pin) + wob - PI / 2)
		draw_line(Vector2.ZERO, Vector2(R * 1.55, 0), Color(0.85, 0.85, 0.82), 5.0, true)
		draw_line(Vector2(R * 1.55, 0), Vector2(R * 1.65, -R * 0.12), Color(0.85, 0.85, 0.82), 4.0, true)
		draw_set_transform(Vector2.ZERO, 0.0)
		var bw := R * 2.0
		draw_rect(Rect2(c.x - R, size.y - 22, bw, 8), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(c.x - R, size.y - 22, bw * float(st.stress), 8), Color(0.91, 0.29, 0.16) if float(st.stress) > 0.6 else Color(0.91, 0.78, 0.38))

# ================================================================ TERMINAL
func open_term(head: String, text: String) -> void:
	_open("term")
	Sfx.play("o_typing", -10.0)
	_clear()
	var top := _row()
	var t := _label(top, head, 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(top, "CLOSE", close, 120)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	term_l = Label.new()
	term_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	term_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	term_l.add_theme_font_size_override("font_size", 20)
	term_l.add_theme_font_override("font", _mono())
	sc.add_child(term_l)
	term_text = text
	term_i = 0
	term_l.text = ""

func _mono() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Droid Sans Mono", "DejaVu Sans Mono", "monospace"])
	return f
