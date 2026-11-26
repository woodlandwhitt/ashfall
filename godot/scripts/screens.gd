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
	_fill(self, 0, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.06, 0.03, 0.96)
	sb.border_color = Color(0.3, 0.8, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.theme = pip_theme()
	add_child(panel)
	_fill(panel, 24, 18)
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

static func _fill(c: Control, mx: float, my: float) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = mx
	c.offset_top = my
	c.offset_right = -mx
	c.offset_bottom = -my

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
	if m in ["title", "intro", "create"]:
		Game.booted = true
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
	l.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD
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
	if mode in ["title", "intro", "create"]:
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
# big centre banners take turns: a second one waits for the first to fade
var banner_q: Array = []
var banner_busy := false
func banner(title: String, sub: String) -> void:
	for b in banner_q:
		if b[0] == title and b[1] == sub:
			return
	banner_q.append([title, sub])
	if not banner_busy:
		_next_banner()

func _next_banner() -> void:
	if banner_q.is_empty():
		banner_busy = false
		return
	banner_busy = true
	var b: Array = banner_q.pop_front()
	banner_l.text = b[0]
	banner_s.text = b[1]
	var tw := banner_box.create_tween()
	tw.tween_property(banner_box, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.6)
	tw.tween_property(banner_box, "modulate:a", 0.0, 0.8)
	tw.tween_interval(0.25)
	tw.tween_callback(_next_banner)

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
	var vf = Game.STORY.get("vendor_faction", {}).get(shop_id)
	if vf != null and String(vf) != "dustwell":
		m += clampf(Game.rep_of(String(vf)) * 0.015, -0.15, 0.15)
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
var loot_check: Callable          # (item, ...) -> bool: may this be taken? (pickpocketing rolls for each)
var loot_store := false           # a container you can put things in as well as take them out
var loot_putting := false

func open_loot(name: String, items: Array, done: Callable, check := Callable(), store := true) -> void:
	loot_name = name
	loot_items = items
	loot_done = done
	loot_check = check
	loot_store = store
	loot_putting = false
	_open("loot")
	Sfx.play("k_cloth1", -6.0)
	_render_loot()

func _take(i: int) -> void:
	var it: Array = loot_items[i]
	if loot_check.is_valid() and not loot_check.call(it):
		return
	if String(it[0]) == "caps":
		Game.caps += int(it[1])
	else:
		Game.give(String(it[0]), int(it[1]))
	loot_items.remove_at(i)
	Sfx.play("k_cloth1", -4.0)
	Game.stats_changed.emit()
	Game.check_quests()
	if loot_items.is_empty() and not loot_store:
		close()
	else:
		_render_loot()

func _take_all() -> void:
	while not loot_items.is_empty():
		if loot_check.is_valid() and not loot_check.call(loot_items[loot_items.size() - 1]):
			return
		var it: Array = loot_items.pop_back()
		if String(it[0]) == "caps":
			Game.caps += int(it[1])
		else:
			Game.give(String(it[0]), int(it[1]))
	Sfx.play("k_cloth1", -4.0)
	Game.stats_changed.emit()
	Game.check_quests()
	close()

# putting your own things in: anything you carry that isn't equipped or a quest item
func _put(id: String, n: int) -> void:
	if Game.count(id) < n:
		return
	Game.take(id, n)
	var found := false
	for it in loot_items:
		if String(it[0]) == id:
			it[1] = int(it[1]) + n
			found = true
	if not found:
		loot_items.append([id, n])
	Sfx.play("k_cloth1", -6.0)
	Game.stats_changed.emit()
	_render_loot()

func _render_put() -> void:
	_clear()
	var top := _row()
	var t := _label(top, ("PUT IN: " + loot_name).to_upper(), 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(top, "BACK", func(): loot_putting = false; _render_loot(), 130)
	_button(top, "X", close, 60)
	var list := _scroll()
	var keys: Array = Game.inv.keys()
	keys.sort_custom(func(a, b): return Game.iname(a) < Game.iname(b))
	var any := false
	for id in keys:
		var c := Game.count(String(id))
		var it := Game.item(String(id))
		if c <= 0 or String(it.get("t", "")) == "quest" or id == Game.weapon or id == Game.armor:
			continue
		any = true
		var h := HBoxContainer.new()
		list.add_child(h)
		var l := _label(h, Game.iname(id) + ("  x" + str(c) if c > 1 else ""), 20)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(h, "PUT 1", _put.bind(String(id), 1), 100)
		if c > 1:
			_button(h, "ALL", _put.bind(String(id), c), 80)
	if not any:
		_label(list, "Nothing you can leave here.", 19, DIM)
	_label(body, "Carrying %.0f / %.0f" % [Game.carry_now(), Game.carry_max()], 18, DIM)

func _render_loot() -> void:
	if loot_putting:
		_render_put()
		return
	_clear()
	var top := _row()
	var t := _label(top, loot_name.to_upper(), 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if loot_store:
		_button(top, "PUT IN", func(): loot_putting = true; _render_loot(), 130)
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
	if Game.dev.get("locks", false):
		# developer: every lock simply opens
		Sfx.play("o_unlock", -4.0)
		done.call(true)
		return true
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
	elif (mode == "term" or mode == "intro") and term_i < term_text.length():
		term_i = mini(term_text.length(), term_i + (5 if mode == "term" else 1))
		term_l.text = term_text.substr(0, term_i) + ("█" if term_i < term_text.length() else "")
		if term_i % 20 < 5 and mode == "term":
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

# ================================================================ TITLE, OPENING, REGISTRATION
const SLIDES := [
	"The bombs fell on a Tuesday. Nobody alive remembers which one. The cities burned, the rivers turned, and for a hundred years the sky was the colour of rust.",
	"Beneath a hill in the Meridian valley, four hundred people sealed a steel door and waited. They grew mushrooms. They raised children. They told each other the surface was gone.",
	"That was two hundred years ago. This is Haven 12. And last night, for the first time in living memory, the water stopped running.",
	"You were born here. You have never seen the sky. In the morning, the Overseer is going to change that."]
var slide_i := 0
var slide_l: Label
var cre := {}
var cre_name: LineEdit

# every save slot with what's in it (level, where, when); tap one to load it
func open_load(back: Callable) -> void:
	_open("load")
	_clear()
	var t := _label(body, "LOAD GAME", 40, Color(1.0, 0.85, 0.5))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 12)
	body.add_child(box)
	var any := false
	for slot in ["auto", "1", "2", "3"]:
		var info := Game.save_info(slot)
		var nm: String = "Autosave" if slot == "auto" else "Slot " + slot
		if info == "":
			var b := _button(box, nm + ":  empty", func(): pass)
			b.disabled = true
			continue
		any = true
		var where := ""
		var f := FileAccess.open("user://save_" + slot + ".json", FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				where = String(d.get("name", ""))
				if d.get("pos") is Array and Game.DB.has("locs"):
					var px := float(d.pos[0])
					var pz := float(d.pos[2])
					var best := 1e9
					for k in Game.DB.locs:
						var L: Dictionary = Game.DB.locs[k]
						var dd := Vector2(float(L.get("x", 0)) - px, float(L.get("z", 0)) - pz).length()
						if dd < best:
							best = dd
							where = String(d.get("name", "")) + ", near " + String(L.get("name", k))
				if String(d.get("area", "world")) == "vault":
					where = String(d.get("name", "")) + ", Haven 12"
		var sl: String = slot
		_button(box, "%s:  %s\n%s" % [nm, info, where], func():
			Game.booted = true
			close()
			if Game.main and Game.main.hud:
				Game.main.hud.pause_panel.visible = false
			Loader.begin("Loading " + nm.to_lower())
			Game.load_game(sl))
	if not any:
		_label(box, "No saved games yet.", 18, DIM).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(box, "BACK", back)

func latest_save() -> String:
	var best := ""
	var bt := ""
	for slot in ["auto", "1", "2", "3"]:
		var f := FileAccess.open("user://save_" + slot + ".json", FileAccess.READ)
		if f == null:
			continue
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary and String(d.get("time", "")) > bt:
			bt = String(d.time)
			best = slot
	return best

func open_title() -> void:
	_open("title")
	_clear()
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sp)
	var t := _label(body, "ASHFALL: MERIDIAN", 54, Color(1.0, 0.85, 0.5))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var st := _label(body, "Haven 12 is running dry. Someone has to go up.", 20, DIM)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 12)
	body.add_child(box)
	var last := latest_save()
	if last != "":
		_button(box, "CONTINUE  (" + Game.save_info(last) + ")", func():
			Game.booted = true
			close()
			Loader.begin("Picking up where you left off")
			Game.load_game(last))
	if last != "":
		_button(box, "LOAD GAME", func(): open_load(open_title))
	_button(box, "NEW GAME", func(): Game.booted = true; _intro(0))
	_button(box, "JUMP INTO THE VALLEY", func():
		Game.booted = true
		close())
	_update_row(box)
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sp2)
	var P = get_node_or_null("/root/Patcher")
	if P and int(P.build) > 0:
		var bl := _label(body, "Build %d%s" % [int(P.build), "  (updated in game)" if P.patched else ""], 14, DIM)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# a newer build on GitHub for this APK: offer it, download it in the background, say when it's ready
var updater: Updater
func _update_row(box: VBoxContainer) -> void:
	if OS.get_cmdline_user_args().size() > 0 and not OS.get_cmdline_user_args().has("--updatetest"):
		return
	if updater == null:
		updater = Updater.new()
		add_child(updater)
	var holder := VBoxContainer.new()
	box.add_child(holder)
	var show_offer := func(b: int, mb: float):
		if not is_instance_valid(holder):
			return
		for c in holder.get_children():
			c.queue_free()
		var st := _label(holder, "", 16, DIM)
		var btn: Button = _button(holder, "UPDATE TO BUILD %d  (%.0f MB)" % [b, mb], func(): pass)
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
	else:
		updater.found.connect(show_offer, CONNECT_ONE_SHOT)
		updater.check()

func _intro(i: int) -> void:
	slide_i = i
	mode = "intro"
	_clear()
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sp)
	slide_l = _label(body, "", 26, Color(0.9, 0.95, 0.85))
	slide_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	term_text = SLIDES[i]
	term_i = 0
	term_l = slide_l
	if Game.main:
		Game.main.speak(SLIDES[i], "narrator")
	var dots := _label(body, " ".join(range(SLIDES.size()).map(func(j): return "●" if j == i else "○")), 20, DIM)
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sp2)
	var row := _row()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button(row, "SKIP", _create, 160)
	_button(row, "NEXT" if i < SLIDES.size() - 1 else "CONTINUE", func():
		if term_i < term_text.length():
			term_i = term_text.length() - 1
			return
		if slide_i < SLIDES.size() - 1:
			_intro(slide_i + 1)
		else:
			_create(), 220)

func _create() -> void:
	mode = "create"
	if cre.is_empty():
		cre = {"stats": {"might": 5, "aim": 5, "endurance": 5, "charm": 5, "intellect": 5, "agility": 5, "luck": 5}, "points": 3}
	_clear()
	_label(body, "HAVEN 12 RESIDENT REGISTRATION", 26, Color(1.0, 0.85, 0.5))
	var nr := _row()
	_label(nr, "Name", 20)
	if cre_name == null or not is_instance_valid(cre_name):
		cre_name = LineEdit.new()
		cre_name.placeholder_text = "Wanderer"
		cre_name.max_length = 18
	cre_name.custom_minimum_size = Vector2(320, 48)
	cre_name.add_theme_font_size_override("font_size", 22)
	if cre_name.get_parent():
		cre_name.get_parent().remove_child(cre_name)
	nr.add_child(cre_name)
	_label(nr, "   %d point%s left" % [cre.points, "" if cre.points == 1 else "s"], 20, Color(1.0, 0.9, 0.5))
	var list := _scroll()
	for k in cre.stats:
		var info: Array = Game.DB.statinfo.get(k, [k.to_upper(), ""])
		var row := HBoxContainer.new()
		list.add_child(row)
		var l := _label(row, "%s  %d   —  %s" % [info[0], cre.stats[k], info[1]], 19)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		_button(row, " − ", func(): cre.stats[k] -= 1; cre.points += 1; _create(), 60, cre.stats[k] > 2)
		_button(row, " + ", func(): cre.stats[k] += 1; cre.points -= 1; _create(), 60, cre.points > 0 and cre.stats[k] < 9)
	var go := _row()
	go.alignment = BoxContainer.ALIGNMENT_END
	_button(go, "CONFIRM AND WAKE UP", func():
		var nm := cre_name.text.strip_edges().substr(0, 18)
		close()
		Game.new_game(nm, cre.stats, int(cre.points)), 320)
