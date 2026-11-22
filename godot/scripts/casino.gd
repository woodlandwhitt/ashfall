# The Silver Spur's tables: blackjack (six-deck shoe, 3:2, double, split), roulette (single zero, inside and
# outside bets on a drawn felt), dice (pass line, don't pass, field) and the slots (four machines; Old Patsy's
# reels depend on what you did about her governor chip). A port of the WebView build's casino.js. The house has a
# nightly limit: win past it and Knuckles walks you out until tomorrow. Everything is drawn here (cards, wheel,
# reels, dice) so it needs no art and scales to any screen.
class_name Casino
extends Control

const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const WHEEL := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const REDS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const SYM := ["club", "diamond", "star", "rad", "BAR", "7"]
const PAY3 := [5, 8, 14, 25, 50, 150]
# reel weights per machine mood; payback is about .78 / .90 / .97 / 1.25
const WEIGHTS := {"rigged": [34, 26, 18, 11, 7, 4], "house": [27, 23, 19, 13, 10, 8], "fair": [26, 23, 19, 13, 10, 9.5], "mine": [23, 21, 18, 14, 12, 13]}
const CHIPS := [5, 10, 25, 50, 100]
const VIP_CHIPS := [250, 500]
const PIPS := {1: [4], 2: [0, 8], 3: [0, 4, 8], 4: [0, 2, 6, 8], 5: [0, 2, 4, 6, 8], 6: [0, 2, 3, 5, 6, 8]}
const DBETS := [["pass", "PASS LINE", "Come-out: 7 or 11 wins, 2, 3 or 12 loses. Any other number becomes the point: roll it again before a 7."],
	["dont", "DON'T PASS", "The opposite of pass. 12 on the come-out is a push."],
	["field", "FIELD", "One roll. 3, 4, 9, 10, 11 pay even; 2 and 12 pay double."]]
# outside bets: key, label, payout multiple (including the stake)
const OUTSIDE := [["1st 12", 3], ["2nd 12", 3], ["3rd 12", 3], ["1-18", 2], ["EVEN", 2], ["RED", 2], ["BLACK", 2], ["ODD", 2], ["19-36", 2]]

const GOLD := Color(0.93, 0.78, 0.36)
const FELT := Color(0.06, 0.32, 0.17)
const FELT_D := Color(0.03, 0.2, 0.1)
const CREAM := Color(0.97, 0.94, 0.86)
const CRED := Color(0.72, 0.1, 0.08)
const INK := Color(0.08, 0.08, 0.09)

var panel: Panel
var table: Control
var tabs_box: HBoxContainer
var chips_box: HBoxContainer
var ctrl: HBoxContainer
var note: Label
var bank_l: Label
var serif: SystemFont

var game := "blackjack"
var bet := 10
var machine := 0
var busy := false
var fast := false
var shoe: Array = []
var bj: Dictionary = {}
var rl := {"bets": {}, "spinning": false, "angle": 0.0, "ball": -PI * 0.5, "ball_r": 1.0, "last": -1, "hist": []}
var sl := {"reels": [[0, 1, 2], [3, 4, 5], [0, 2, 4]], "spin": [false, false, false], "off": [0.0, 0.0, 0.0]}
var dc := {"point": 0, "bets": {}, "rolling": false, "dice": [3, 4], "hist": [], "rot": [0.0, 0.0]}
var hits: Array = []           # [Rect2, key] laid out by the last draw, for taps on the felt
var win_t := 0.0
var win_amt := 0
var spin_t := 0.0
var _tick := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Screens._fill(self, 0, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Noto Serif", "DejaVu Serif", "Liberation Serif", "serif"])
	serif.font_weight = 700
	panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.06, 0.04, 0.98)
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.theme = _theme()
	add_child(panel)
	Screens._fill(panel, 14, 10)
	panel.visible = false
	var v := VBoxContainer.new()
	Screens._fill(v, 12, 8)
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	# top bar: name, games, bank, leave
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	var t := Label.new()
	t.text = "THE SILVER SPUR"
	t.add_theme_font_override("font", serif)
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", GOLD)
	top.add_child(t)
	tabs_box = HBoxContainer.new()
	tabs_box.add_theme_constant_override("separation", 4)
	top.add_child(tabs_box)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	bank_l = Label.new()
	bank_l.add_theme_font_size_override("font_size", 19)
	bank_l.add_theme_color_override("font_color", CREAM)
	top.add_child(bank_l)
	var leave := Button.new()
	leave.text = "LEAVE"
	leave.custom_minimum_size = Vector2(96, 46)
	leave.pressed.connect(close)
	top.add_child(leave)
	# chips
	chips_box = HBoxContainer.new()
	chips_box.add_theme_constant_override("separation", 6)
	chips_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(chips_box)
	# the felt
	table = Control.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.clip_contents = true
	table.mouse_filter = Control.MOUSE_FILTER_STOP
	table.draw.connect(_draw_table)
	table.gui_input.connect(_table_input)
	v.add_child(table)
	note = Label.new()
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", serif)
	note.add_theme_font_size_override("font_size", 20)
	note.add_theme_color_override("font_color", GOLD)
	note.custom_minimum_size = Vector2(0, 28)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(note)
	ctrl = HBoxContainer.new()
	ctrl.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrl.add_theme_constant_override("separation", 10)
	v.add_child(ctrl)

static func _theme() -> Theme:
	var th := Theme.new()
	th.set_color("font_color", "Button", CREAM)
	th.set_color("font_hover_color", "Button", Color(1, 1, 0.9))
	th.set_color("font_pressed_color", "Button", INK)
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.42, 0.36))
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.3, 0.1, 0.07)
	bn.border_color = Color(0.7, 0.55, 0.25)
	bn.set_border_width_all(1)
	bn.set_corner_radius_all(6)
	bn.set_content_margin_all(8)
	var bp := bn.duplicate()
	bp.bg_color = GOLD
	var bd := bn.duplicate()
	bd.bg_color = Color(0.18, 0.08, 0.06)
	th.set_stylebox("normal", "Button", bn)
	th.set_stylebox("hover", "Button", bn)
	th.set_stylebox("pressed", "Button", bp)
	th.set_stylebox("disabled", "Button", bd)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_font_size("font_size", "Button", 20)
	return th

# ---------------------------------------------------------------- bankroll and the house limit
func luck() -> int:
	return int(Game.stats.get("luck", 5)) + int(Game.buff("luck", 0.0))

func vip() -> bool:
	return bool(Game.flags.get("spurVip", false)) or Game.caps >= 2500

func net() -> Dictionary:
	var n = Game.flags.get("casinoNet")
	if not (n is Dictionary) or int(n.get("day", -1)) != Game.day:
		n = {"day": Game.day, "net": 0}
		Game.flags["casinoNet"] = n
	return n

func limit() -> int:
	return (2600 if vip() else 1100) + luck() * 60

func stake(n: int) -> bool:
	if Game.caps < n:
		return false
	Game.caps -= n
	net().net = int(net().net) - n
	_bank()
	return true

func payout(n: int) -> void:
	if n <= 0:
		return
	Game.caps += n
	net().net = int(net().net) + n
	_bank()

func _bank() -> void:
	var nn := int(net().net)
	bank_l.text = "%d chits%s" % [Game.caps, ("   tonight %s%d" % ["+" if nn > 0 else "", nn]) if nn != 0 else ""]

func celebrate(won: int, staked: int) -> void:
	if won < maxi(200, staked * 8):
		return
	win_amt = won
	win_t = 0.01 if fast else 2.4
	Game.party_react("casino")
	Sfx.play("o_levelup", -4.0, 1.1)

func check_limit() -> bool:
	if int(net().net) < limit():
		return false
	Game.flags["casinoBan"] = Game.day
	busy = true
	speak("The house thanks you for a remarkable evening. I'll see you out. Come back tomorrow.", "knuckles")
	Sfx.play("k_door_open", -4.0)
	await _wait(2600)
	busy = false
	close()
	return true

func speak(t: String, who: String) -> void:
	note.text = t
	if Game.main and not fast:
		Game.main.speak(t, who)

func info(t: String) -> void:
	note.text = t

func _wait(ms: int) -> void:
	if fast:
		return
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout

# ---------------------------------------------------------------- the shell
func is_open() -> bool:
	return panel.visible

func open(g: String, m := 0) -> void:
	if Game.flags.get("casinoBan") == Game.day:
		Game.msg("Knuckles shakes his head. Not tonight.")
		Sfx.play("k_metal_click", -6.0)
		return
	game = g if g in ["blackjack", "roulette", "dice", "slots"] else "blackjack"
	machine = m
	busy = false
	panel.visible = true
	Game.paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.main and Game.main.hud:
		Game.main.hud.touch.visible = false
		Game.main.hud.set_prompt("")
	if not CHIPS.has(bet) and not (vip() and VIP_CHIPS.has(bet)):
		bet = 10
	_render()
	_bank()
	Sfx.play("k_chip1", -6.0)
	match game:
		"blackjack": speak("Place your bet. Dealer stands on seventeen.", "lou")
		"roulette": speak("Place your bets on the felt.", "lou")
		"dice": speak("New shooter coming out. Put your money on the line.", "lou")
		_: info("Old Patsy. Her lights flicker like she's winking at you." if machine == 0 else "Three reels, one lever. Pull and pray.")

func close() -> void:
	if not panel.visible:
		return
	if busy or rl.spinning or dc.rolling:
		return
	if dc.point:
		info("Finish the point first: the dice are live.")
		return
	if not bj.is_empty() and bj.phase == "player":
		info("Finish the hand first.")
		return
	for k in dc.bets:
		payout(int(dc.bets[k]))
	dc.bets = {}
	payout(_rl_staked())
	rl.bets = {}
	panel.visible = false
	Game.paused = false
	get_tree().paused = false
	if Game.main and Game.main.hud:
		Game.main.hud.touch.visible = Game.main.hud.touch_on
		if Game.main.hud.touch_on:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.stats_changed.emit()
	Game.check_quests()

func _unhandled_key_input(e: InputEvent) -> void:
	if not panel.visible or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE or e.keycode == KEY_TAB:
		close()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_SPACE or e.keycode == KEY_ENTER:
		for b in ctrl.get_children():
			if b is Button and not b.disabled:
				b.pressed.emit()
				break
		get_viewport().set_input_as_handled()

func _locked() -> bool:
	return busy or rl.spinning or dc.rolling or dc.point != 0 or (not bj.is_empty() and bj.phase in ["player", "dealing", "dealer"])

func _render() -> void:
	for c in tabs_box.get_children():
		c.queue_free()
	for c in chips_box.get_children():
		c.queue_free()
	for c in ctrl.get_children():
		c.queue_free()
	for gg in [["blackjack", "BLACKJACK"], ["roulette", "ROULETTE"], ["dice", "DICE"], ["slots", "SLOTS"]]:
		var b := Button.new()
		b.text = gg[1]
		b.toggle_mode = true
		b.button_pressed = gg[0] == game
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 17)
		var k: String = gg[0]
		b.pressed.connect(func():
			if _locked():
				b.button_pressed = k == game
				return
			game = k
			Sfx.play("k_click", -8.0)
			info("Pick a machine and pull." if k == "slots" else "")
			_render())
		tabs_box.add_child(b)
	var chips: Array = CHIPS + (VIP_CHIPS if vip() else [])
	for c in chips:
		var b := Button.new()
		b.text = str(c)
		b.custom_minimum_size = Vector2(56, 50)
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_stylebox_override("normal", _chip_box(int(c), c == bet))
		b.add_theme_stylebox_override("hover", _chip_box(int(c), c == bet))
		b.add_theme_stylebox_override("pressed", _chip_box(int(c), true))
		b.add_theme_stylebox_override("disabled", _chip_box(int(c), false, true))
		b.add_theme_color_override("font_color", INK if int(c) in [5, 250] else CREAM)
		b.disabled = Game.caps < int(c)
		var cv: int = c
		b.pressed.connect(func():
			bet = cv
			Sfx.play("k_chip2", -6.0)
			_render())
		chips_box.add_child(b)
	match game:
		"blackjack": _ctrl_bj()
		"roulette": _ctrl_rl()
		"dice": _ctrl_dc()
		_: _ctrl_sl()
	table.queue_redraw()

static func chip_color(c: int) -> Color:
	match c:
		5: return Color(0.92, 0.9, 0.84)
		10: return Color(0.15, 0.35, 0.75)
		25: return Color(0.15, 0.55, 0.25)
		50: return Color(0.75, 0.15, 0.12)
		100: return Color(0.12, 0.12, 0.12)
		250: return Color(0.95, 0.75, 0.2)
		_: return Color(0.5, 0.2, 0.6)

func _chip_box(c: int, on: bool, off := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = chip_color(c).darkened(0.55 if off else 0.0)
	s.border_color = GOLD if on else Color(0.95, 0.95, 0.9, 0.7)
	s.set_border_width_all(4 if on else 2)
	s.set_corner_radius_all(25)
	return s

func _btn(label: String, fn: Callable, main := false, on := true) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(150 if main else 120, 54)
	b.disabled = not on
	if main:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.55, 0.38, 0.1)
		s.border_color = GOLD
		s.set_border_width_all(2)
		s.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", s)
	b.pressed.connect(func():
		if not busy:
			fn.call())
	ctrl.add_child(b)
	return b

func _table_input(e: InputEvent) -> void:
	var p := Vector2.INF
	# taps arrive as emulated mouse clicks (touch events too, on some devices: take only one kind, or a tap bets twice)
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		p = e.position
	if p == Vector2.INF:
		return
	for h in hits:
		if (h[0] as Rect2).has_point(p):
			if game == "roulette":
				place_rl(String(h[1]))
			elif game == "dice":
				place_dc(String(h[1]))
			return

func _process(dt: float) -> void:
	if not panel.visible:
		return
	var dirty := false
	if not bj.is_empty():
		for h in [bj.dealer] + bj.hands.map(func(x): return x.cards):
			for c in h:
				if float(c.a) < 1.0:
					c.a = minf(1.0, float(c.a) + dt * (60.0 if fast else 4.5))
					dirty = true
	if win_t > 0.0:
		win_t -= dt
		dirty = true
	if rl.spinning or dc.rolling or sl.spin.has(true):
		dirty = true
		_tick -= dt
		if _tick <= 0.0:
			_tick = 0.06
			if dc.rolling:
				dc.dice = [randi_range(1, 6), randi_range(1, 6)]
				dc.rot = [randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)]
			for i in 3:
				if sl.spin[i]:
					var r: Array = sl.reels[i]
					sl.reels[i] = [randi() % 6, r[0], r[1]]
					sl.off[i] = 1.0
		for i in 3:
			if sl.spin[i]:
				sl.off[i] = maxf(0.0, float(sl.off[i]) - dt / 0.06)
	if dirty:
		table.queue_redraw()

# ================================================================ BLACKJACK
func _new_shoe() -> void:
	shoe = []
	for d in 6:
		for s in 4:
			for r in RANKS:
				shoe.append({"r": r, "s": s})
	shoe.shuffle()
	Sfx.play("k_shuffle", -6.0)

static func val(c: Dictionary) -> int:
	var r := String(c.r)
	if r == "A":
		return 11
	if r in ["J", "Q", "K", "10"]:
		return 10
	return int(r)

static func total(h: Array) -> Dictionary:
	var t := 0
	var a := 0
	for c in h:
		t += val(c)
		if String(c.r) == "A":
			a += 1
	while t > 21 and a > 0:
		t -= 10
		a -= 1
	return {"t": t, "soft": a > 0}

static func is_bj(h: Array) -> bool:
	return h.size() == 2 and int(total(h).t) == 21

func draw_card(for_hand = null) -> Dictionary:
	if shoe.size() < 60:
		_new_shoe()
	var c: Dictionary = shoe.pop_back()
	# a lucky wanderer sometimes dodges the card that would bust them
	if for_hand is Array and int(total(for_hand + [c]).t) > 21 and randf() < maxf(0.0, luck() - 5) * 0.04:
		shoe.insert(randi() % shoe.size(), c)
		c = shoe.pop_back()
	c = c.duplicate()
	c.a = 0.0
	Sfx.play("k_card1" if randf() < 0.5 else "k_card2", -4.0)
	return c

func _ctrl_bj() -> void:
	if bj.is_empty() or bj.phase == "done":
		_btn("DEAL  %d" % bet, deal, true, Game.caps >= bet)
	elif bj.phase == "player":
		var h: Dictionary = bj.hands[bj.active]
		_btn("HIT", hit, true)
		_btn("STAND", stand)
		_btn("DOUBLE", dbl, false, h.cards.size() == 2 and Game.caps >= int(h.bet))
		_btn("SPLIT", split, false, bj.hands.size() == 1 and h.cards.size() == 2 and val(h.cards[0]) == val(h.cards[1]) and Game.caps >= int(h.bet))

func deal() -> void:
	if not stake(bet):
		info("Not enough chits.")
		return
	busy = true
	bj = {"phase": "dealing", "dealer": [], "hands": [{"cards": [], "bet": bet, "res": ""}], "active": 0}
	Sfx.play("k_chip1", -4.0)
	info("")
	_render()
	for to in ["p", "d", "p", "d"]:
		if to == "p":
			bj.hands[0].cards.append(draw_card())
		else:
			bj.dealer.append(draw_card())
		table.queue_redraw()
		await _wait(260)
	var h: Array = bj.hands[0].cards
	var up := val(bj.dealer[0])
	bj.phase = "player"
	if is_bj(bj.dealer) and up >= 10:
		bj.phase = "done"
		if is_bj(h):
			bj.hands[0].res = "PUSH"
			payout(bet)
			speak("Two blackjacks. Push.", "lou")
		else:
			bj.hands[0].res = "DEALER BLACKJACK"
			speak("Dealer has blackjack. Sorry, friend.", "lou")
		busy = false
		_render()
		return
	if is_bj(h):
		bj.phase = "done"
		bj.hands[0].res = "BLACKJACK"
		payout(int(floor(bet * 2.5)))
		Sfx.play("o_coin", -2.0)
		speak("Blackjack! Pays three to two.", "lou")
		busy = false
		_render()
		check_limit()
		return
	busy = false
	_render()

func hit() -> void:
	var h: Dictionary = bj.hands[bj.active]
	h.cards.append(draw_card(h.cards))
	_render()
	var t := int(total(h.cards).t)
	if t > 21:
		h.res = "BUST"
		info("Bust.")
		busy = true
		await _wait(400)
		busy = false
		await _next()
	elif t == 21:
		busy = true
		await _wait(250)
		busy = false
		await _next()

func stand() -> void:
	await _next()

func dbl() -> void:
	var h: Dictionary = bj.hands[bj.active]
	if not stake(int(h.bet)):
		return
	h.bet = int(h.bet) * 2
	Sfx.play("k_chip1", -4.0)
	h.cards.append(draw_card(h.cards))
	_render()
	if int(total(h.cards).t) > 21:
		h.res = "BUST"
	busy = true
	await _wait(400)
	busy = false
	await _next()

func split() -> void:
	var h: Dictionary = bj.hands[0]
	if not stake(int(h.bet)):
		return
	Sfx.play("k_chip1", -4.0)
	var c2: Dictionary = h.cards.pop_back()
	bj.hands.append({"cards": [c2], "bet": h.bet, "res": ""})
	for hh in bj.hands:
		hh.cards.append(draw_card(hh.cards))
	_render()
	# split aces get one card each
	if String(h.cards[0].r) == "A":
		busy = true
		await _wait(300)
		busy = false
		bj.active = bj.hands.size() - 1
		await _next()

func _next() -> void:
	var aces: bool = bj.hands.size() > 1 and String(bj.hands[0].cards[0].r) == "A"
	if bj.active < bj.hands.size() - 1 and not aces:
		bj.active += 1
		_render()
		return
	busy = true
	bj.phase = "dealer"
	_render()
	await _wait(400)
	var live := false
	for h in bj.hands:
		if int(total(h.cards).t) <= 21:
			live = true
	if live:
		while int(total(bj.dealer).t) < 17:
			bj.dealer.append(draw_card())
			table.queue_redraw()
			await _wait(420)
	var dt := int(total(bj.dealer).t)
	var won := 0
	var lost := 0
	for h in bj.hands:
		var t := int(total(h.cards).t)
		if t > 21:
			h.res = "BUST"
			lost += 1
		elif dt > 21 or t > dt:
			h.res = "WIN"
			payout(int(h.bet) * 2)
			won += 1
		elif t == dt:
			h.res = "PUSH"
			payout(int(h.bet))
		else:
			h.res = "LOSE"
			lost += 1
	bj.phase = "done"
	busy = false
	_render()
	if won > 0:
		Sfx.play("o_coin", -2.0)
		if dt > 21:
			speak("Dealer busts. Winner.", "lou")
		else:
			speak("Winner. Nicely played.", "lou")
	elif lost > 0:
		info(("Dealer has %d." % dt) if dt <= 21 else "Bust.")
	else:
		info("Push.")
	check_limit()

func _draw_bj(t: Control, S: Vector2) -> void:
	var ch := clampf(S.y * 0.3, 70.0, 150.0)
	var cw := ch * 0.7
	var font := serif
	# felt printing
	t.draw_string(font, Vector2(0, S.y * 0.5 - 4), "BLACKJACK PAYS 3 TO 2", HORIZONTAL_ALIGNMENT_CENTER, S.x, int(ch * 0.2), Color(GOLD, 0.75))
	t.draw_string(font, Vector2(0, S.y * 0.5 + ch * 0.17), "DEALER STANDS ON ALL 17s", HORIZONTAL_ALIGNMENT_CENTER, S.x, int(ch * 0.12), Color(CREAM, 0.45))
	t.draw_arc(Vector2(S.x * 0.5, -S.y * 0.9), S.y * 1.5, PI * 0.25, PI * 0.75, 64, Color(GOLD, 0.3), 2.0)
	# the shoe, top right
	var shoe_p := Vector2(S.x - cw - 24, 12)
	for i in 4:
		_card(t, shoe_p + Vector2(i * 2, i * 2), cw, ch, {}, true)
	# dealer
	var dl := "DEALER"
	if not bj.is_empty():
		dl = ("DEALER  shows %d" % int(total([bj.dealer[0]]).t)) if bj.phase in ["player", "dealing"] and bj.dealer.size() > 0 else "DEALER  %d" % int(total(bj.dealer).t)
	var dw := cw + (cw * 0.55) * maxi(0, (bj.dealer.size() if not bj.is_empty() else 2) - 1)
	var dx := S.x * 0.5 - dw * 0.5
	t.draw_string(font, Vector2(0, 26), dl, HORIZONTAL_ALIGNMENT_CENTER, S.x, 20, CREAM)
	if not bj.is_empty():
		for i in bj.dealer.size():
			var c: Dictionary = bj.dealer[i]
			var to := Vector2(dx + i * cw * 0.55, 36)
			_card(t, shoe_p.lerp(to, _ease(float(c.a))), cw, ch, c, i == 1 and bj.phase in ["player", "dealing"])
	# hands
	var hands: Array = bj.hands if not bj.is_empty() else [{"cards": [], "bet": 0, "res": ""}]
	var n := hands.size()
	var y := S.y * 0.6
	for hi in n:
		var h: Dictionary = hands[hi]
		var cx := S.x * (0.5 if n == 1 else (0.3 + 0.4 * hi))
		var w := cw + cw * 0.55 * maxi(0, h.cards.size() - 1)
		var x0 := cx - w * 0.5
		if not bj.is_empty() and bj.phase == "player" and hi == bj.active and n > 1:
			t.draw_rect(Rect2(x0 - 8, y - 8, w + 16, ch + 16), GOLD, false, 3.0)
		for i in h.cards.size():
			var c: Dictionary = h.cards[i]
			_card(t, shoe_p.lerp(Vector2(x0 + i * cw * 0.55, y), _ease(float(c.a))), cw, ch, c, false)
		var lab := "YOUR HAND"
		if h.cards.size() > 0:
			var tt := total(h.cards)
			lab = "%d%s   bet %d%s" % [int(tt.t), " soft" if tt.soft and int(tt.t) < 21 else "", int(h.bet), ("   " + String(h.res)) if String(h.res) != "" else ""]
		var col := CREAM
		if String(h.res) in ["WIN", "BLACKJACK"]:
			col = Color(0.6, 1.0, 0.55)
		elif String(h.res) in ["BUST", "LOSE", "DEALER BLACKJACK"]:
			col = Color(1.0, 0.5, 0.4)
		t.draw_string(font, Vector2(cx - 200, y + ch + 26), lab, HORIZONTAL_ALIGNMENT_CENTER, 400, 19, col)
		if int(h.bet) > 0:
			_chip_stack(t, Vector2(cx - w * 0.5 - 34, y + ch * 0.6), int(h.bet), 17.0)

static func _ease(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)

func _card(t: Control, p: Vector2, w: float, h: float, c: Dictionary, back: bool) -> void:
	var r := Rect2(p, Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(w * 0.1))
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(2, 3)
	if back or c.is_empty():
		sb.bg_color = Color(0.55, 0.08, 0.08)
		sb.border_color = CREAM
		sb.set_border_width_all(int(maxf(2.0, w * 0.05)))
		t.draw_style_box(sb, r)
		var inner := r.grow(-w * 0.12)
		for i in 6:
			var yy := inner.position.y + inner.size.y * (i + 0.5) / 6.0
			t.draw_line(Vector2(inner.position.x, yy), Vector2(inner.end.x, yy), Color(0.8, 0.3, 0.25, 0.5), 1.5)
		t.draw_rect(inner, Color(GOLD, 0.6), false, 1.5)
		return
	sb.bg_color = CREAM
	sb.border_color = Color(0.6, 0.58, 0.5)
	sb.set_border_width_all(1)
	t.draw_style_box(sb, r)
	var s := int(c.s)
	var col := CRED if s in [1, 2] else INK
	t.draw_string(serif, p + Vector2(w * 0.08, h * 0.2), String(c.r), HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.17), col)
	_suit(t, p + Vector2(w * 0.17, h * 0.3), w * 0.13, s, col)
	_suit(t, p + Vector2(w * 0.56, h * 0.62), w * 0.34, s, col)

# heart, diamond, spade and club drawn from circles and triangles (no font has to carry the glyphs)
static func _suit(t: CanvasItem, c: Vector2, r: float, s: int, col: Color) -> void:
	match s:
		1:
			t.draw_circle(c + Vector2(-r * 0.48, -r * 0.2), r * 0.52, col)
			t.draw_circle(c + Vector2(r * 0.48, -r * 0.2), r * 0.52, col)
			t.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.98, -r * 0.05), c + Vector2(r * 0.98, -r * 0.05), c + Vector2(0, r * 0.95)]), col)
		2:
			t.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)]), col)
		0:
			t.draw_circle(c + Vector2(-r * 0.48, r * 0.15), r * 0.5, col)
			t.draw_circle(c + Vector2(r * 0.48, r * 0.15), r * 0.5, col)
			t.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.96, r * 0.02), c + Vector2(r * 0.96, r * 0.02), c + Vector2(0, -r * 0.95)]), col)
			t.draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.2), c + Vector2(r * 0.32, r), c + Vector2(-r * 0.32, r)]), col)
		_:
			t.draw_circle(c + Vector2(0, -r * 0.45), r * 0.45, col)
			t.draw_circle(c + Vector2(-r * 0.48, r * 0.2), r * 0.45, col)
			t.draw_circle(c + Vector2(r * 0.48, r * 0.2), r * 0.45, col)
			t.draw_circle(c + Vector2(0, r * 0.05), r * 0.3, col)
			t.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.1), c + Vector2(r * 0.3, r), c + Vector2(-r * 0.3, r)]), col)

func _chip_stack(t: Control, c: Vector2, amt: int, r: float) -> void:
	var left := amt
	var stack: Array = []
	for d in [500, 250, 100, 50, 25, 10, 5]:
		while left >= d and stack.size() < 6:
			stack.append(d)
			left -= d
	for i in stack.size():
		var p := c + Vector2(0, -i * r * 0.28)
		t.draw_circle(p + Vector2(1, 2), r, Color(0, 0, 0, 0.4))
		t.draw_circle(p, r, chip_color(int(stack[i])))
		t.draw_arc(p, r * 0.75, 0, TAU, 24, Color(1, 1, 1, 0.75), r * 0.14)
	t.draw_string(serif, c + Vector2(-40, -(stack.size() - 1) * r * 0.28 + r * 0.33), str(amt), HORIZONTAL_ALIGNMENT_CENTER, 80, int(r * 0.9), CREAM if stack.is_empty() or int(stack[-1]) not in [5, 250] else INK)

# ================================================================ ROULETTE
static func color_of(n: int) -> String:
	return "green" if n == 0 else ("red" if REDS.has(n) else "black")

static func outside_wins(k: String, n: int) -> bool:
	if n == 0:
		return false
	match k:
		"1st 12": return n <= 12
		"2nd 12": return n >= 13 and n <= 24
		"3rd 12": return n >= 25
		"1-18": return n <= 18
		"19-36": return n >= 19
		"EVEN": return n % 2 == 0
		"ODD": return n % 2 == 1
		"RED": return REDS.has(n)
		"BLACK": return not REDS.has(n)
	return false

func _rl_staked() -> int:
	var s := 0
	for k in rl.bets:
		s += int(rl.bets[k])
	return s

func _ctrl_rl() -> void:
	var s := _rl_staked()
	_btn(("SPIN  (%d)" % s) if s > 0 else "SPIN", spin, true)
	_btn("CLEAR", func():
		payout(_rl_staked())
		rl.bets = {}
		Sfx.play("k_chip2", -6.0)
		_render())

func place_rl(k: String) -> void:
	if rl.spinning or busy:
		return
	var lim := 2000 if vip() else 500
	if _rl_staked() + bet > lim:
		info("Table limit is %d a spin." % lim)
		return
	if not stake(bet):
		info("Not enough chits.")
		return
	rl.bets[k] = int(rl.bets.get(k, 0)) + bet
	Sfx.play("k_chip1" if randf() < 0.5 else "k_chip2", -4.0)
	_render()

func spin() -> void:
	if rl.spinning:
		return
	if _rl_staked() == 0:
		info("Place a bet first: tap a number or an outside bet.")
		return
	rl.spinning = true
	busy = true
	speak("No more bets.", "lou")
	_render()
	var n: int = WHEEL[randi() % 37]
	var idx := WHEEL.find(n)
	var seg := TAU / 37.0
	# the wheel turns so pocket idx ends under the pointer at the top; the ball runs the other way and drops in
	var start := float(rl.angle)
	var target := -idx * seg
	var turns := TAU * (4 + randi() % 2)
	var goal := start - fposmod(start - target, TAU) - turns
	var dur := 0.0 if fast else 3.8
	var el := 0.0
	while el < dur:
		await get_tree().process_frame
		el += get_process_delta_time()
		var k := clampf(el / dur, 0.0, 1.0)
		var e := _ease(k)
		rl.angle = start + (goal - start) * e
		rl.ball = -PI * 0.5 + (1.0 - e) * TAU * 3.0
		rl.ball_r = smoothstep(0.6, 0.95, k) + sin(k * 50.0) * (1.0 - k) * 0.08
		spin_t += get_process_delta_time()
		if spin_t > 0.18 and k > 0.6:
			spin_t = 0.0
			Sfx.play("k_click", -16.0 - k * 6.0, 1.6)
	rl.angle = goal
	rl.ball = -PI * 0.5
	rl.ball_r = 1.0
	Sfx.play("k_chip2", -2.0)
	rl.last = n
	rl.hist.append(n)
	var stk := _rl_staked()
	var win := 0
	for k in rl.bets:
		var v := int(rl.bets[k])
		if String(k) == str(n):
			win += v * 36
		else:
			for o in OUTSIDE:
				if o[0] == k and outside_wins(String(k), n):
					win += v * int(o[1])
	rl.bets = {}
	rl.spinning = false
	busy = false
	if win > 0:
		payout(win)
		Sfx.play("o_coin", -2.0)
		speak("Winner, winner.", "lou")
		info("%d %s. Winner, %d chits." % [n, color_of(n), win])
		celebrate(win, stk)
	else:
		info("%d %s." % [n, color_of(n)])
	_render()
	check_limit()

func _draw_rl(t: Control, S: Vector2) -> void:
	hits = []
	var D := minf(S.y * 0.96, S.x * 0.36)
	var R := D * 0.5
	var c := Vector2(R + 8, S.y * 0.5)
	var seg := TAU / 37.0
	t.draw_circle(c + Vector2(3, 5), R, Color(0, 0, 0, 0.4))
	t.draw_circle(c, R, Color(0.25, 0.13, 0.06))
	t.draw_arc(c, R - 2, 0, TAU, 96, GOLD, 5.0)
	var a0 := float(rl.angle)
	for i in 37:
		var n: int = WHEEL[i]
		var a := -PI * 0.5 + a0 + i * seg - seg * 0.5
		var pts := PackedVector2Array([c + Vector2.from_angle(a) * R * 0.56, c + Vector2.from_angle(a) * (R - 10), c + Vector2.from_angle(a + seg * 0.5) * (R - 10), c + Vector2.from_angle(a + seg) * (R - 10), c + Vector2.from_angle(a + seg) * R * 0.56])
		var col := Color(0.11, 0.54, 0.29) if n == 0 else (Color(0.69, 0.13, 0.1) if REDS.has(n) else Color(0.08, 0.08, 0.08))
		t.draw_colored_polygon(pts, col)
		t.draw_line(c + Vector2.from_angle(a) * R * 0.56, c + Vector2.from_angle(a) * (R - 10), Color(GOLD, 0.8), 1.0)
		var mid := a + seg * 0.5
		t.draw_set_transform(c + Vector2.from_angle(mid) * (R - 24), mid + PI * 0.5, Vector2.ONE)
		t.draw_string(serif, Vector2(-20, 5), str(n), HORIZONTAL_ALIGNMENT_CENTER, 40, int(maxf(9.0, R * 0.075)), CREAM)
		t.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	t.draw_arc(c, R * 0.56, 0, TAU, 72, GOLD, 2.0)
	t.draw_circle(c, R * 0.52, Color(0.42, 0.24, 0.1))
	for i in 4:
		var a := a0 + i * PI * 0.5
		t.draw_line(c - Vector2.from_angle(a) * R * 0.42, c + Vector2.from_angle(a) * R * 0.42, GOLD, maxf(3.0, R * 0.04))
	t.draw_circle(c, R * 0.09, GOLD)
	# pointer and the ball
	t.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -R - 2), c + Vector2(9, -R - 2), c + Vector2(0, -R + 12)]), GOLD)
	var bp := c + Vector2.from_angle(float(rl.ball)) * lerpf(R - 15, R * 0.64, clampf(float(rl.ball_r), 0.0, 1.0))
	if rl.spinning or int(rl.last) >= 0:
		t.draw_circle(bp, maxf(5.0, R * 0.04), Color(0.98, 0.98, 0.96))
	# the felt: 0, then 12 columns of three; dozens; even-money bets
	var bx := D + 30.0
	var bw := S.x - bx - 8.0
	var hist_h := 30.0
	var ch := minf((S.y - hist_h - 12.0) / 5.0, bw / 13.0 * 1.3)
	var cw := bw / 13.0
	var by := hist_h + 8.0
	var fr := Rect2(bx - 4, by - 4, bw + 8, ch * 5 + 8)
	t.draw_rect(fr, FELT_D)
	# history
	var hs: Array = rl.hist.slice(maxi(0, rl.hist.size() - 14))
	for i in hs.size():
		var n: int = hs[i]
		var rr := Rect2(bx + i * 34, 2, 30, 24)
		t.draw_rect(rr, Color(0.11, 0.54, 0.29) if n == 0 else (CRED if REDS.has(n) else INK))
		t.draw_string(serif, rr.position + Vector2(0, 18), str(n), HORIZONTAL_ALIGNMENT_CENTER, 30, 15, GOLD if i == hs.size() - 1 else CREAM)
	_rl_cell(t, Rect2(bx, by, cw, ch * 3), "0", "0", Color(0.11, 0.54, 0.29))
	for col in 12:
		for row in 3:
			var n := col * 3 + (3 - row)
			_rl_cell(t, Rect2(bx + cw * (col + 1), by + ch * row, cw, ch), str(n), str(n), CRED if REDS.has(n) else INK)
	for i in 3:
		_rl_cell(t, Rect2(bx + cw * (1 + i * 4), by + ch * 3, cw * 4, ch), OUTSIDE[i][0], String(OUTSIDE[i][0]).to_upper(), FELT)
	for i in 6:
		var k: String = OUTSIDE[3 + i][0]
		var col := CRED if k == "RED" else (INK if k == "BLACK" else FELT)
		_rl_cell(t, Rect2(bx + cw * (1 + i * 2), by + ch * 4, cw * 2, ch), k, k, col)

func _rl_cell(t: Control, r: Rect2, key: String, label: String, col: Color) -> void:
	t.draw_rect(r.grow(-1), col)
	t.draw_rect(r, Color(CREAM, 0.7), false, 1.0)
	var hit: bool = int(rl.last) >= 0 and key == str(rl.last) and not rl.spinning
	if hit:
		t.draw_rect(r.grow(-2), GOLD, false, 3.0)
	var fs := int(clampf(r.size.y * 0.36, 11.0, 24.0))
	t.draw_string(serif, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, CREAM)
	if rl.bets.has(key):
		var cr := minf(r.size.y, r.size.x) * 0.27
		_chip_stack(t, r.end - Vector2(cr + 3, cr + 3), int(rl.bets[key]), cr)
	hits.append([r, key])

# ================================================================ DICE
func _ctrl_dc() -> void:
	_btn("ROLL", roll, true)
	_btn("TAKE DOWN", func():
		if dc.point and (dc.bets.has("pass") or dc.bets.has("dont")):
			info("Line bets stay up until the point resolves.")
			return
		for k in dc.bets:
			payout(int(dc.bets[k]))
		dc.bets = {}
		_render())

func place_dc(k: String) -> void:
	if dc.rolling or busy:
		return
	if dc.point and k in ["pass", "dont"]:
		info("Line bets go down on the come-out roll.")
		return
	if not stake(bet):
		info("Not enough chits.")
		return
	dc.bets[k] = int(dc.bets.get(k, 0)) + bet
	Sfx.play("k_chip1" if randf() < 0.5 else "k_chip2", -4.0)
	_render()

func roll() -> void:
	if dc.rolling:
		return
	if dc.bets.is_empty():
		info("Put a bet down first.")
		return
	dc.rolling = true
	busy = true
	Sfx.play("k_dice", -2.0)
	_render()
	await _wait(700)
	var d1 := randi_range(1, 6)
	var d2 := randi_range(1, 6)
	resolve_roll(d1, d2)

func resolve_roll(d1: int, d2: int) -> void:
	var n := d1 + d2
	dc.dice = [d1, d2]
	dc.rot = [randf_range(-0.25, 0.25), randf_range(-0.25, 0.25)]
	dc.hist.append(n)
	var won := 0
	var st := 0
	var msgs: Array = []
	var pay := func(k: String, m: int) -> int:
		var v := int(dc.bets[k])
		var w := 0
		if m > 0:
			w = v * (m + 1)
			payout(w)
			msgs.append(k.to_upper() + " wins")
		elif m == 0:
			payout(v)
			msgs.append(k.to_upper() + " push")
		else:
			msgs.append(k.to_upper() + " loses")
		dc.bets.erase(k)
		return w
	for k in dc.bets:
		st += int(dc.bets[k])
	if dc.bets.has("field"):
		won += pay.call("field", 2 if n in [2, 12] else (1 if n in [3, 4, 9, 10, 11] else -1))
	var line := ""
	if dc.point == 0:
		if n in [7, 11]:
			if dc.bets.has("pass"): won += pay.call("pass", 1)
			if dc.bets.has("dont"): pay.call("dont", -1)
			line = "natural"
		elif n in [2, 3]:
			if dc.bets.has("pass"): pay.call("pass", -1)
			if dc.bets.has("dont"): won += pay.call("dont", 1)
			line = "craps"
		elif n == 12:
			if dc.bets.has("pass"): pay.call("pass", -1)
			if dc.bets.has("dont"): pay.call("dont", 0)
			line = "craps"
		elif dc.bets.has("pass") or dc.bets.has("dont"):
			dc.point = n
			msgs.append("the point is %d" % n)
	else:
		if n == dc.point:
			if dc.bets.has("pass"): won += pay.call("pass", 1)
			if dc.bets.has("dont"): pay.call("dont", -1)
			dc.point = 0
			line = "made"
		elif n == 7:
			if dc.bets.has("pass"): pay.call("pass", -1)
			if dc.bets.has("dont"): won += pay.call("dont", 1)
			dc.point = 0
			line = "out"
	dc.rolling = false
	busy = false
	_render()
	match line:
		"natural":
			if won > 0:
				speak("Winner on the come-out!", "lou")
		"craps": speak("Craps. Line away.", "lou")
		"made": speak("Point made. Pay the line.", "lou")
		"out": speak("Seven out. Line away.", "lou")
	note.text = "%d and %d, %d.%s" % [d1, d2, n, (" " + ", ".join(msgs) + ".") if msgs.size() > 0 else " No decision."]
	if won > 0:
		Sfx.play("o_coin", -2.0)
	celebrate(won, st)
	check_limit()

func _draw_dc(t: Control, S: Vector2) -> void:
	hits = []
	var ds := clampf(S.y * 0.26, 60.0, 130.0)
	var cy := S.y * 0.05
	# rail
	t.draw_rect(Rect2(S.x * 0.18, cy - 6, S.x * 0.64, ds + 24), Color(FELT_D, 0.9))
	t.draw_rect(Rect2(S.x * 0.18, cy - 6, S.x * 0.64, ds + 24), Color(GOLD, 0.4), false, 2.0)
	for i in 2:
		var p := Vector2(S.x * 0.5 + (i * 2 - 1) * ds * 0.7, cy + ds * 0.5 + 6)
		_die(t, p, ds, int(dc.dice[i]), float(dc.rot[i]))
	var py := cy + ds + 46
	var pt := ("POINT  %d" % dc.point) if dc.point else "COME-OUT ROLL"
	var puck := Vector2(S.x * 0.5 - 150, py - 22)
	t.draw_circle(puck, 20, CREAM if dc.point else INK)
	t.draw_string(serif, puck + Vector2(-20, 6), "ON" if dc.point else "OFF", HORIZONTAL_ALIGNMENT_CENTER, 40, 14, INK if dc.point else CREAM)
	t.draw_string(serif, Vector2(0, py - 14), pt, HORIZONTAL_ALIGNMENT_CENTER, S.x, 26, GOLD)
	# last rolls
	var hs: Array = dc.hist.slice(maxi(0, dc.hist.size() - 14))
	var hx := S.x * 0.5 - hs.size() * 17.0
	for i in hs.size():
		t.draw_string(serif, Vector2(hx + i * 34, py + 16), str(hs[i]), HORIZONTAL_ALIGNMENT_CENTER, 34, 17, CRED.lightened(0.3) if int(hs[i]) == 7 else CREAM)
	# bets
	var by := py + 32
	var bh := S.y - by - 6
	var bw := (S.x - 40) / 3.0
	for i in 3:
		var k: String = DBETS[i][0]
		var r := Rect2(10 + i * (bw + 10), by, bw, bh)
		var locked: bool = dc.point != 0 and k in ["pass", "dont"] and not dc.bets.has(k)
		t.draw_rect(r, FELT.darkened(0.3) if locked else FELT)
		t.draw_rect(r, GOLD if dc.bets.has(k) else Color(CREAM, 0.6), false, 2.0)
		t.draw_string(serif, r.position + Vector2(0, 30), DBETS[i][1], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, CREAM)
		if bh > 90:
			t.draw_multiline_string(get_theme_default_font(), r.position + Vector2(12, 58), DBETS[i][2], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 24, 15, 4, Color(CREAM, 0.7))
		if dc.bets.has(k):
			_chip_stack(t, Vector2(r.get_center().x, r.end.y - 28), int(dc.bets[k]), 18.0)
		hits.append([r, k])

func _die(t: Control, c: Vector2, s: float, v: int, rot: float) -> void:
	t.draw_set_transform(c, rot, Vector2.ONE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.12, 0.1)
	sb.set_corner_radius_all(int(s * 0.16))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(3, 4)
	t.draw_style_box(sb, Rect2(-s * 0.5, -s * 0.5, s, s))
	for i in PIPS[v]:
		var px := (int(i) % 3 - 1) * s * 0.28
		var py := (int(i) / 3 - 1) * s * 0.28
		t.draw_circle(Vector2(px, py), s * 0.085, CREAM)
	t.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ================================================================ SLOTS
func mood() -> String:
	if machine != 0:
		return "house"
	var p := String(Game.flags.get("patsy", ""))
	return "fair" if p == "fair" else ("mine" if p == "mine" else "rigged")

func spin_sym() -> int:
	var w: Array = WEIGHTS[mood()]
	var tot := 0.0
	for x in w:
		tot += float(x)
	var r := randf() * tot
	for i in w.size():
		r -= float(w[i])
		if r <= 0.0:
			return i
	return 0

static func score(r: Array) -> int:
	var a: int = r[0]
	var b: int = r[1]
	var c: int = r[2]
	if a == b and b == c:
		return PAY3[a]
	if a == b:
		return 6 if a == 5 else (4 if a == 4 else (2 if a == 3 else 1))
	if a == 5 or b == 5 or c == 5:
		return 1
	return 0

func _ctrl_sl() -> void:
	_btn("PULL  %d" % bet, pull, true, Game.caps >= bet)
	for i in 4:
		var b := _btn("PATSY" if i == 0 else "#%d" % i, func():
			machine = i
			Sfx.play("k_click", -8.0)
			info("Old Patsy. Her lights flicker like she's winking at you." if i == 0 else "Lucky Strike %d." % i)
			_render())
		b.custom_minimum_size = Vector2(84, 54)
		b.toggle_mode = true
		b.button_pressed = i == machine

func pull() -> void:
	if not stake(bet):
		info("Not enough chits.")
		return
	busy = true
	Sfx.play("k_metal_latch", -4.0)
	info("")
	_render()
	var res: Array = [spin_sym(), spin_sym(), spin_sym()]
	if mood() == "rigged" and res[0] == 5 and res[1] == 5 and res[2] == 5:
		res[2] = 0 # Old Patsy never pays the big one
	if score(res) == 0 and randf() < maxf(0.0, luck() - 5) * 0.02:
		res = [spin_sym(), spin_sym(), spin_sym()]
	sl.spin = [true, true, true]
	for i in 3:
		await _wait(550 + i * 350)
		sl.spin[i] = false
		sl.off[i] = 0.0
		sl.reels[i] = [(res[i] + 5) % 6, res[i], (res[i] + 1) % 6]
		Sfx.play("k_switch", -6.0)
		table.queue_redraw()
	var mult := score(res)
	var win := bet * mult
	if win > 0:
		payout(win)
		celebrate(win, bet)
		if mult >= 150:
			speak("Jackpot! The whole room turns to look.", "lou")
		elif mult >= 50:
			info("Big win! Pays %d." % win)
		else:
			info("Pays %d." % win)
		Sfx.play("o_coin", -2.0)
	else:
		info(["Nothing.", "Close. Not close enough.", "The machine hums smugly."][randi() % 3])
	busy = false
	_render()
	check_limit()

func _draw_sl(t: Control, S: Vector2) -> void:
	hits = []
	var w := minf(S.x * 0.62, 640.0)
	var x0 := S.x * 0.5 - w * 0.5
	var cab := Rect2(x0, 4, w, S.y - 8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.32, 0.05, 0.07) if machine == 0 else Color(0.12, 0.14, 0.3)
	sb.border_color = GOLD
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	t.draw_style_box(sb, cab)
	var title := "OLD PATSY" if machine == 0 else "LUCKY STRIKE %d" % machine
	t.draw_string(serif, Vector2(x0, 44), title, HORIZONTAL_ALIGNMENT_CENTER, w, 32, GOLD)
	# marquee bulbs
	for i in 14:
		var on := (int(Time.get_ticks_msec() / 250) + i) % 2 == 0 if busy else i % 2 == 0
		t.draw_circle(Vector2(x0 + 24 + i * (w - 48) / 13.0, 60), 4, GOLD if on else Color(0.4, 0.3, 0.1))
	var rh := minf((S.y - 170) / 3.0, w * 0.22)
	var rw := (w - 80) / 3.0
	var ry := 74.0
	for i in 3:
		var rr := Rect2(x0 + 24 + i * (rw + 16), ry, rw, rh * 3)
		t.draw_rect(rr, CREAM)
		var reel: Array = sl.reels[i]
		var off := float(sl.off[i]) * rh if sl.spin[i] else 0.0
		for k in 3:
			var cc := Vector2(rr.get_center().x, ry + rh * (k + 0.5) - off)
			_sym(t, cc, rh * 0.36, int(reel[k]), sl.spin[i])
		# shading at the top and bottom of the window
		t.draw_rect(Rect2(rr.position, Vector2(rw, rh * 0.35)), Color(0, 0, 0, 0.25))
		t.draw_rect(Rect2(rr.position + Vector2(0, rh * 2.65), Vector2(rw, rh * 0.35)), Color(0, 0, 0, 0.25))
		t.draw_rect(rr, Color(0.25, 0.2, 0.1), false, 3.0)
	t.draw_line(Vector2(x0 + 14, ry + rh * 1.5), Vector2(x0 + w - 14, ry + rh * 1.5), Color(CRED, 0.7), 3.0)
	var py := ry + rh * 3 + 26
	t.draw_string(get_theme_default_font(), Vector2(x0, py), "7 7 7 = 150x   BAR x3 = 50x   RAD x3 = 25x   STAR x3 = 14x   DIAMOND x3 = 8x   CLUB x3 = 5x", HORIZONTAL_ALIGNMENT_CENTER, w, 14, CREAM)
	t.draw_string(get_theme_default_font(), Vector2(x0, py + 20), "Two on the left: RAD 2x, BAR 4x, 7 6x, others return the bet   Any 7 returns the bet", HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(CREAM, 0.7))
	# the lever
	var lx := cab.end.x + 14
	t.draw_line(Vector2(lx, S.y * 0.55), Vector2(lx, S.y * (0.62 if busy else 0.2)), Color(0.7, 0.7, 0.72), 6.0)
	t.draw_circle(Vector2(lx, S.y * (0.62 if busy else 0.2)), 13, CRED)

func _sym(t: Control, c: Vector2, r: float, s: int, blur: bool) -> void:
	var a := 0.55 if blur else 1.0
	match s:
		0: _suit(t, c, r, 3, Color(0.1, 0.45, 0.2, a))
		1: _suit(t, c, r, 2, Color(0.2, 0.4, 0.85, a))
		2:
			var pts := PackedVector2Array()
			for i in 10:
				pts.append(c + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * (r if i % 2 == 0 else r * 0.42))
			t.draw_colored_polygon(pts, Color(0.95, 0.7, 0.1, a))
		3:
			t.draw_circle(c, r, Color(0.98, 0.82, 0.1, a))
			for i in 3:
				var aa := -PI * 0.5 + i * TAU / 3.0
				var pts := PackedVector2Array([c])
				for k in 9:
					pts.append(c + Vector2.from_angle(aa - 0.5 + k * 1.0 / 8.0) * r * 0.86)
				t.draw_colored_polygon(pts, Color(INK, a))
			t.draw_circle(c, r * 0.2, Color(0.98, 0.82, 0.1, a))
			t.draw_circle(c, r * 0.13, Color(INK, a))
		4:
			t.draw_rect(Rect2(c - Vector2(r * 1.2, r * 0.45), Vector2(r * 2.4, r * 0.9)), Color(INK, a))
			t.draw_string(serif, Vector2(c.x - r * 1.2, c.y + r * 0.3), "BAR", HORIZONTAL_ALIGNMENT_CENTER, r * 2.4, int(r * 0.8), Color(CREAM, a))
		_:
			t.draw_string(serif, Vector2(c.x - r, c.y + r * 0.75), "7", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 2.1), Color(CRED, a))

# ================================================================ the felt
func _draw_table() -> void:
	var t := table
	var S := t.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = FELT if game != "slots" else Color(0.1, 0.04, 0.03)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(0.35, 0.18, 0.08)
	sb.set_border_width_all(6)
	t.draw_style_box(sb, Rect2(Vector2.ZERO, S))
	match game:
		"blackjack": _draw_bj(t, S)
		"roulette": _draw_rl(t, S)
		"dice": _draw_dc(t, S)
		_: _draw_sl(t, S)
	if win_t > 0.0:
		var al := clampf(win_t / 0.6, 0.0, 1.0)
		t.draw_rect(Rect2(0, S.y * 0.32, S.x, S.y * 0.36), Color(0, 0, 0, 0.55 * al))
		t.draw_string_outline(serif, Vector2(0, S.y * 0.45), "BIG WIN", HORIZONTAL_ALIGNMENT_CENTER, S.x, 30, 8, Color(0, 0, 0, al))
		t.draw_string(serif, Vector2(0, S.y * 0.45), "BIG WIN", HORIZONTAL_ALIGNMENT_CENTER, S.x, 30, Color(CREAM, al))
		t.draw_string_outline(serif, Vector2(0, S.y * 0.6), "+%d" % win_amt, HORIZONTAL_ALIGNMENT_CENTER, S.x, 64, 10, Color(0, 0, 0, al))
		t.draw_string(serif, Vector2(0, S.y * 0.6), "+%d" % win_amt, HORIZONTAL_ALIGNMENT_CENTER, S.x, 64, Color(GOLD, al))
