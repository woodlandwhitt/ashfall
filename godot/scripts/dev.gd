# The developer menu (F1 or ` on a keyboard, DEVELOPER in the pause menu): switches, the player, the world, people
# and monsters, quests, areas, voices and rendering, plus a command console. Ported from the WebView build's dev
# panel (main.js renderDev / CMD) with more besides. The game pauses while it is open.
class_name DevMenu
extends PanelContainer

const AMB := Color(1.0, 0.78, 0.4)
const DIMC := Color(0.75, 0.6, 0.4)
var body: VBoxContainer
var scroll: ScrollContainer
var page := "CHEATS"
var tabs: HBoxContainer
var con_out: RichTextLabel
var con_in: LineEdit
var hist: Array = []
var perf_l: Label

const PAGES := ["CHEATS", "PLAYER", "WORLD", "SPAWN", "QUESTS", "AREAS", "VOICES", "RENDER", "CONSOLE"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 20
	offset_top = 14
	offset_right = -20
	offset_bottom = -14
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.045, 0.03, 0.97)
	sb.border_color = AMB
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Label.new()
	t.text = "DEVELOPER"
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", AMB)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var fb := Button.new()
	fb.text = "FORGE MODE"
	fb.custom_minimum_size = Vector2(170, 44)
	fb.pressed.connect(func():
		Game.main.hud.toggle_dev()
		Game.main.forge.toggle())
	top.add_child(fb)
	var x := Button.new()
	x.text = "X"
	x.custom_minimum_size = Vector2(56, 44)
	x.pressed.connect(func(): Game.main.hud.toggle_dev())
	top.add_child(x)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	for p in PAGES:
		var b := Button.new()
		b.text = p
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(func(): show_page(p))
		tabs.add_child(b)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	visible = false
	perf_l = Label.new()
	perf_l.add_theme_font_size_override("font_size", 14)
	perf_l.position = Vector2(18, 150)
	perf_l.visible = false
	perf_l.mouse_filter = Control.MOUSE_FILTER_IGNORE

func open() -> void:
	visible = true
	show_page(page)

func show_page(p: String) -> void:
	page = p
	for b in tabs.get_children():
		(b as Button).modulate = Color(1, 1, 1) if (b as Button).text == p else Color(0.6, 0.6, 0.6)
	for c in body.get_children():
		c.queue_free()
	match p:
		"CHEATS": _cheats()
		"PLAYER": _player()
		"WORLD": _world()
		"SPAWN": _spawn()
		"QUESTS": _quests()
		"AREAS": _areas()
		"VOICES": _voices()
		"RENDER": _render()
		"CONSOLE": _console()

func _refresh() -> void:
	var y := scroll.scroll_vertical
	show_page(page)
	await get_tree().process_frame
	scroll.scroll_vertical = y

# a row: a label (with a smaller line under it) and a wrapping group of buttons
func _row(label: String, sub := "") -> HFlowContainer:
	var box := VBoxContainer.new()
	body.add_child(box)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", AMB)
	box.add_child(l)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.add_theme_font_size_override("font_size", 14)
		s.add_theme_color_override("font_color", DIMC)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(s)
	var g := HFlowContainer.new()
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	box.add_child(g)
	return g

func _btn(g: Control, t: String, f: Callable, on := false) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 16)
	if on:
		b.add_theme_color_override("font_color", Color(0.1, 0.06, 0.02))
		var st := StyleBoxFlat.new()
		st.bg_color = AMB
		st.set_corner_radius_all(4)
		st.set_content_margin_all(8)
		b.add_theme_stylebox_override("normal", st)
	b.pressed.connect(func():
		Sfx.play("k_click", -10.0)
		f.call()
		_refresh())
	g.add_child(b)
	return b

func _toggle(label: String, sub: String, key: String, after := Callable()) -> void:
	var g := _row(label, sub)
	_btn(g, "ON" if Game.dev[key] else "OFF", func():
		Game.dev[key] = not Game.dev[key]
		if after.is_valid():
			after.call(), Game.dev[key])

func _head(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(1, 0.92, 0.75))
	body.add_child(l)

# ---------------------------------------------------------------- pages
func _cheats() -> void:
	_toggle("God mode", "No damage, no radiation", "god")
	_toggle("Free flight", "Through walls, wherever you look. JUMP rises, RUN sinks (Space and C on a keyboard)", "noclip")
	_toggle("Infinite ammo", "Magazines never run down", "ammo")
	_toggle("Infinite action points", "FOCUS as often as you like", "ap")
	_toggle("One-hit kills", "Everything drops to a single hit", "onehit")
	_toggle("Invisible", "Nothing can see you", "invis")
	_toggle("Freeze AI", "Enemies stand where they are", "noai")
	var gv := _row("Camera", "Third person is also in the pause menu (F5 on a keyboard)")
	_btn(gv, "THIRD PERSON" if Game.player and Game.player.tp and Game.player.tp.on else "FIRST PERSON", func(): Game.player.toggle_view())
	_toggle("Unlimited carry weight", "Never over-encumbered", "carry")
	_toggle("Open every lock", "Locks, safes and locked terminals open on their own", "locks")
	_toggle("Pass every check", "Strength, Charisma, Intelligence... checks in conversation always pass", "checks")
	_toggle("Show the HUD", "Turn off for clean screenshots", "hud", func(): Game.main.hud.set_hud_visible(Game.dev.hud))
	var g := _row("Move speed", "x%s" % str(Game.dev.speed))
	for s in [0.5, 1.0, 2.0, 4.0]:
		_btn(g, "x" + str(s), func(): Game.dev.speed = s, is_equal_approx(float(Game.dev.speed), s))

func _player() -> void:
	var g := _row("Player", "Level %d, %d caps, %d stat points, %d perk points" % [Game.level, Game.caps, Game.points, Game.perk_pts])
	_btn(g, "HEAL", func(): run("heal"))
	_btn(g, "+1 LEVEL", func(): run("level %d" % (Game.level + 1)))
	_btn(g, "+5 LEVELS", func(): run("level %d" % (Game.level + 5)))
	_btn(g, "+500 CAPS", func(): run("caps 500"))
	_btn(g, "+1000 XP", func(): run("xp 1000"))
	_btn(g, "ALL PERKS", func(): run("perk all"))
	_btn(g, "MAX STATS", func(): run("set all 10"))
	_btn(g, "CLEAR RADS", func(): Game.rad = 0.0)
	_btn(g, "CLEAN BLOOD", func(): run("clean"))
	g = _row("S.P.E.C.I.A.L.", "  ".join(Game.SPECIAL.map(func(k): return "%s %d" % [String(Game.DB.statinfo[k][0]).substr(0, 3), int(Game.stats.get(k, 5))])))
	for k in Game.SPECIAL:
		_btn(g, String(Game.DB.statinfo[k][0]).substr(0, 3) + " +", func(): Game.stats[k] = mini(10, int(Game.stats.get(k, 5)) + 1); Game.stats_changed.emit())
		_btn(g, String(Game.DB.statinfo[k][0]).substr(0, 3) + " −", func(): Game.stats[k] = maxi(1, int(Game.stats.get(k, 5)) - 1); Game.stats_changed.emit())
	g = _row("Companion approval", "Tap to add 10; long walks not required")
	for k in Game.L.get("companions", {}):
		if not Game.L.companions[k].get("dog", false):
			_btn(g, "%s %+d" % [String(Game.L.companions[k].n).split(" ")[0].to_upper(), Game.approval(k)], func(): Game.approve(k, 10, "console"))
			_btn(g, "LOYAL " + String(Game.L.companions[k].n).split(" ")[0].to_upper(), func(): Game.make_loyal(k))
	g = _row("Karma", "%d — %s" % [Game.karma, Game.karma_title(Game.karma)])
	for k in [-100, -40, 0, 40, 100]:
		_btn(g, str(k), func(): Game.karma = k)
	g = _row("Give a kit", "Straight into your pack")
	for k in ["guns", "ammo", "meds", "chems", "armor", "mats", "nades", "keys"]:
		_btn(g, k.to_upper(), func(): run("kit " + k))
	for cat in [["aid", "Give aid and chems"], ["junk", "Give junk"], ["quest", "Give quest items and keys"], ["armor", "Give armor"]]:
		g = _row(String(cat[1]), "")
		for k in Game.DB.items:
			if String(Game.DB.items[k].get("t", "")) == cat[0]:
				_btn(g, Game.iname(k), func(): run("give " + k))
	g = _row("Give one weapon", "")
	for k in Game.DB.items:
		if String(Game.DB.items[k].get("t", "")) == "weapon":
			_btn(g, Game.iname(k), func(): run("give " + k))
	g = _row("Companions", "Join you on the spot")
	for k in Game.L.get("companions", {}):
		_btn(g, String(Game.L.companions[k].get("n", k)).to_upper(), func(): Game.main.recruit(k))

func _world() -> void:
	var g := _row("Time of day", Game.main.hud.pip._clock() + ", day %d" % Game.day)
	for t in [["DAWN", 6.6], ["MORNING", 9.0], ["NOON", 12.0], ["DUSK", 17.6], ["NIGHT", 23.0]]:
		_btn(g, t[0], func(): Game.time = float(t[1]) / 24.0)
	g = _row("Day length", "x%s" % str(Game.dev.dayrate))
	for r in [0.0, 1.0, 10.0, 60.0]:
		_btn(g, "STOP" if r == 0.0 else "x" + str(int(r)), func(): Game.dev.dayrate = r, is_equal_approx(float(Game.dev.dayrate), r))
	g = _row("Townspeople's navmesh", "%d areas baked, %d spots" % [Game.main.town.ready_keys.size(), Game.main.town.spots.size()] if Game.main.town else "")
	_btn(g, "SHOW" if not TownLife.debug_on else "HIDE", func(): Game.main.town.show_debug(not TownLife.debug_on); _refresh(), TownLife.debug_on)
	_btn(g, "BAKE HERE", func(): Game.main.town.bake_outdoor(Game.player.global_position); _refresh())
	g = _row("Game speed", "x%s" % str(Engine.time_scale))
	for r in [0.25, 0.5, 1.0, 2.0, 4.0]:
		_btn(g, "x" + str(r), func(): Engine.time_scale = r; Game.dev.timescale = r, is_equal_approx(Engine.time_scale, r))
	if Game.main.atmos:
		g = _row("Weather", String(Game.flags.get("wx", {}).get("k", "?")) if Game.flags.get("wx") is Dictionary else "")
		for w in ["clear", "cloudy", "storm", "rain", "thunder", "radstorm"]:
			_btn(g, w.to_upper(), func(): Game.main.atmos.set_weather(w, true))
	g = _row("Road events", "Start one near you")
	for k in ["caravan", "trader", "stranger", "scav", "radstorm"]:
		_btn(g, k.to_upper(), func():
			if not Game.main.events.start(k):
				Game.msg("No room for that event here."))
	g = _row("World", "")
	_btn(g, "TO QUEST MARKER", func():
		var qt = Game.main.quest_target()
		if qt is Dictionary and qt.has("x"):
			run("tp %s %s" % [str(qt.x), str(qt.z)]))
	_btn(g, "THE SILVER SPUR'S TABLES", func(): Game.main.hud.toggle_dev(); run("casino blackjack"))
	_btn(g, "CALM EVERYONE", func():
		for e in Game.main.enemies.duplicate():
			if is_instance_valid(e) and e.get("npc") != null and not e.dead:
				Game.main._calm(e))
	_btn(g, "KILL NEARBY HOSTILES", func(): run("killall"))
	_btn(g, "REVEAL MAP", func(): run("reveal"))
	_btn(g, "RESTOCK SHOPS", func(): Game.shops = {})
	_btn(g, "FIX AND PARK BUGGY", func(): run("buggy"))
	_btn(g, "SAVE NOW", func(): Game.save_game("auto"))
	g = _row("Open a shop", "From anywhere")
	for k in Game.L.get("vendors", {}):
		_btn(g, k.to_upper(), func():
			Game.main.hud.toggle_dev()
			Game.main.hud.screens.open_trade(k))

func _spawn() -> void:
	var g := _row("Hostile, ahead of you", "Tap to spawn one; the x3 row spawns three")
	var types: Array = Game.region.etypes.keys()
	types.sort()
	for k in types:
		_btn(g, String(Game.region.etypes[k].get("name", k)).to_upper(), func(): run("spawn %s 1" % k))
	g = _row("x3", "")
	for k in ["raider", "hound", "stalker", "heavy", "sniper"]:
		if Game.region.etypes.has(k):
			_btn(g, k.to_upper() + " x3", func(): run("spawn %s 3" % k))
	g = _row("Friendly", "Stand there and don't attack until provoked")
	for k in ["raider", "ox"]:
		if Game.region.etypes.has(k):
			_btn(g, k.to_upper(), func(): run("spawn %s 1 friendly" % k))

func _quests() -> void:
	var g := _row("Preview an ending", "Shows the ending screen; doesn't change your save")
	for k in Game.L.get("endings", {}):
		_btn(g, k.to_upper(), func():
			Game.main.hud.toggle_dev()
			var old = Game.flags.get("ending")
			Game.finish(k)
			if old == null:
				Game.flags.erase("ending"))
	var ids: Array = Game.L.quests.keys()
	ids.sort_custom(func(a, b): return String(Game.L.quests[a].t) < String(Game.L.quests[b].t))
	for id in ids:
		var q = Game.quests.get(id)
		var d: Dictionary = Game.L.quests[id]
		var st := "not started" if q == null else ("complete" if q.done else "stage %d of %d" % [int(q.stage) + 1, d.get("stages", []).size()])
		g = _row(("[MAIN] " if d.get("main", false) else "") + String(d.t), st + " · " + id)
		if q == null:
			_btn(g, "START", func(): Game.start(id))
		elif not q.done:
			_btn(g, "ADVANCE", func(): run("quest %s advance" % id))
			_btn(g, "COMPLETE", func(): Game.complete(id))
			_btn(g, "TRACK", func(): Game.flags["track"] = id; Game.quest_changed.emit())

func _areas() -> void:
	var g := _row("Teleport", "Closes this menu")
	for k in Game.DB.locs:
		_btn(g, String(Game.DB.locs[k].name).to_upper(), func():
			Game.main.hud.toggle_dev()
			run("tp " + k))
	g = _row("Areas", "Haven 12, the Hole, the town's buildings")
	_btn(g, "HAVEN 12", func():
		Game.main.hud.toggle_dev()
		var V: Dictionary = Game.L.consts.VAULT_O
		Game.travel_area("vault", float(V.x) - 19.0, float(V.z) + 10.0, 0.0))
	_btn(g, "THE SURFACE", func():
		Game.main.hud.toggle_dev()
		var D: Dictionary = Game.DB.locs.dustwell
		Game.travel_area("world", float(D.x), float(D.z) + 10.0, 0.0))
	_btn(g, "K-HOLE (THE HOLE)", func():
		Game.main.hud.toggle_dev()
		Game.flags["leftVault"] = 1
		Game.main.khole_start("hole"))
	_btn(g, "K-HOLE (BLACKOUT)", func():
		Game.main.hud.toggle_dev()
		Game.flags["leftVault"] = 1
		Game.main.khole_start("black"))
	g = _row("Inside a building", "")
	for C in Game.CELLS:
		_btn(g, Game.cell_name(int(C.i)).to_upper(), func():
			Game.main.hud.toggle_dev()
			Game.main.cell_travel(int(C.i), true))

func _voices() -> void:
	var g := _row("Hear a voice", "Plays one of the character's recorded lines")
	var who := {}
	var dir := DirAccess.open("res://voice")
	if dir:
		for d in dir.get_directories():
			who[d] = true
	var names: Array = who.keys()
	names.sort()
	for w in names:
		_btn(g, w.to_upper(), func(): _play_any(w))
	if names.is_empty():
		_label("No recorded voices in this build; lines use the device's text-to-speech.")
	g = _row("Device speech for unrecorded lines", "")
	_btn(g, "ON" if ProjectSettings.get_setting("audio/general/text_to_speech", false) else "OFF", func():
		ProjectSettings.set_setting("audio/general/text_to_speech", not ProjectSettings.get_setting("audio/general/text_to_speech", false)))
	g = _row("Volume", "Master %d dB" % int(AudioServer.get_bus_volume_db(0)))
	for db in [-24, -12, -6, 0]:
		_btn(g, str(db) + " dB", func(): AudioServer.set_bus_volume_db(0, db), int(AudioServer.get_bus_volume_db(0)) == db)

func _play_any(w: String) -> void:
	var files: Array = []
	var d := DirAccess.open("res://voice/" + w)
	if d:
		for f in d.get_files():
			f = f.trim_suffix(".import").trim_suffix(".remap")
			if f.ends_with(".ogg") and not f in files:
				files.append(f)
	if files.is_empty():
		return
	Game.main.stop_voice()
	if Game.main.voice_player == null:
		Game.main.speak("", w)
	Game.main.voice_player.stream = load("res://voice/%s/%s" % [w, files[randi() % files.size()]])
	Game.main.voice_player.play()

func _render() -> void:
	var g := _row("Quality", Quality.NAMES[Game.main.quality])
	for i in Quality.NAMES.size():
		_btn(g, Quality.NAMES[i], func():
			while Game.main.quality != i:
				Game.main.cycle_quality(), Game.main.quality == i)
	_toggle("Performance overlay", "Frame rate, frame time, draw calls, objects, memory, position", "perf", func(on): perf_l.visible = on)
	g = _row("HUD", "Hide it for screenshots")
	_btn(g, "SHOWN" if Game.main.hud.root.visible else "HIDDEN", func(): Game.main.hud.root.visible = not Game.main.hud.root.visible)
	g = _row("Field of view", "%d°" % int(Game.player.cam.fov))
	for f in [60, 75, 90, 105]:
		_btn(g, str(f) + "°", func(): Game.player.cam.fov = f)
	g = _row("Debug", "")
	_btn(g, "SHOW COLLISION BOXES" if not get_tree().debug_collisions_hint else "HIDE COLLISION BOXES", func():
		get_tree().debug_collisions_hint = not get_tree().debug_collisions_hint
		Game.msg("Applies to things loaded from now on."))
	_btn(g, "PRINT POSITION", func(): run("pos"))

func _label(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", DIMC)
	body.add_child(l)

func _console() -> void:
	con_out = RichTextLabel.new()
	con_out.custom_minimum_size = Vector2(0, 300)
	con_out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	con_out.scroll_following = true
	con_out.add_theme_font_size_override("normal_font_size", 15)
	con_out.text = "\n".join(hist.slice(-200)) if not hist.is_empty() else "Type help for the commands."
	body.add_child(con_out)
	var row := HBoxContainer.new()
	body.add_child(row)
	con_in = LineEdit.new()
	con_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	con_in.placeholder_text = "command (help lists them)"
	con_in.custom_minimum_size = Vector2(0, 46)
	con_in.text_submitted.connect(func(t):
		_submit(t))
	row.add_child(con_in)
	var go := Button.new()
	go.text = "RUN"
	go.custom_minimum_size = Vector2(100, 46)
	go.pressed.connect(func(): _submit(con_in.text))
	row.add_child(go)
	con_in.grab_focus.call_deferred()

func _submit(t: String) -> void:
	if t.strip_edges() == "":
		return
	hist.append("> " + t)
	var r := run(t)
	if r != "":
		hist.append(r)
	con_out.text = "\n".join(hist.slice(-200))
	con_in.text = ""
	con_in.grab_focus.call_deferred()

func _process(_d: float) -> void:
	if perf_l.get_parent() == null and Game.main and Game.main.hud:
		Game.main.hud.root.add_child(perf_l)
	perf_l.visible = Game.dev.perf
	if Game.dev.perf and Game.player:
		var p: Vector3 = Game.player.global_position
		perf_l.text = "%d FPS  %.1f ms\n%d draw calls  %d objects  %d nodes\n%.0f MB static  %.0f MB video\n%.1f, %.1f, %.1f  %s\n%d enemies  %d people  %d chunks" % [
			Engine.get_frames_per_second(), 1000.0 / maxf(1.0, Engine.get_frames_per_second()),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, p.x, p.y, p.z, Game.area,
			Game.main.enemies.size(), Game.main.npcs.size(), Game.main.chunks.loaded.size()]

# ---------------------------------------------------------------- console commands
const HELP := {
	"casino": "casino [blackjack|roulette|dice|slots]: open the Spur's tables", "approve": "approve <companion> <n>: change approval",
	"loyal": "loyal <companion>: make them loyal", "recruit": "recruit <jory|sable|renn2|biscuit>",
	"help": "list the commands", "god": "toggle invulnerability", "noclip": "toggle free flight", "ammo": "toggle infinite ammo",
	"ai": "ai [on|off]: freeze or resume enemies", "give": "give <item> [n]", "kit": "kit <guns|ammo|meds|chems|armor|mats|nades|keys>",
	"items": "items [filter]: list item ids", "caps": "caps <n>", "xp": "xp <n>", "level": "level <n>", "heal": "full health and AP, no rads",
	"set": "set <stat|all> <1-10>", "perk": "perk <id|all>", "tp": "tp <place> or tp <x> <z>", "locs": "list places", "pos": "your position",
	"time": "time <0-24>", "weather": "weather <kind>", "spawn": "spawn <type> [n] [friendly]", "enemies": "list enemy types",
	"killall": "kill hostiles within 150 m", "quest": "quest <id> [start|advance|complete]", "quests": "list quests",
	"flag": "flag <name> [value]: read or set a story flag", "reveal": "discover every place", "buggy": "fix the buggy and park it by you",
	"event": "event <caravan|trader|stranger|scav|radstorm>", "khole": "khole [hole|black]", "area": "area <world|vault|cell N>",
	"forge": "toggle forge mode", "timescale": "timescale <0.1-8>", "say": "say <who> <text>: speak a line in a character's voice",
	"clean": "clear chems, crashes and addictions", "clear": "clear the console",
}
const KITS := {"meds": [["stimpak", 10], ["super_stim", 5], ["radaway", 6], ["rad_tabs", 4]], "mats": [["scrap_metal", 30], ["duct_tape", 20], ["circuit", 12], ["gears", 12]],
	"keys": [["keycard", 1], ["buggy_key", 1], ["lattice_key", 1], ["vip_marker", 1], ["bobby_pin", 20]]}

func _find(dict: Dictionary, q: String) -> String:
	q = q.to_lower()
	if dict.has(q):
		return q
	for k in dict:
		if String(k).begins_with(q):
			return k
	for k in dict:
		var n := String(dict[k].get("n", dict[k].get("name", k))) if dict[k] is Dictionary else String(k)
		if q in String(k) or q in n.to_lower():
			return k
	return ""

func run(line: String) -> String:
	var a := line.strip_edges().split(" ", false)
	if a.is_empty():
		return ""
	var c := String(a[0]).to_lower()
	var arg := func(i: int, def := "") -> String: return String(a[i]) if a.size() > i else def
	match c:
		"help":
			var ks: Array = HELP.keys()
			ks.sort()
			return "\n".join(ks.map(func(k): return "%-10s %s" % [k, HELP[k]]))
		"casino":
			Game.flags.erase("casinoBan")
			visible = false
			Game.main.hud.casino.open(arg.call(1, "blackjack"))
			return "the Spur's tables" + ("" if Game.main.hud.casino.is_open() else " (could not open)")
		"approve":
			Game.approve(arg.call(1, "jory"), int(arg.call(2, "10")), "console")
			return "%s approval %d" % [arg.call(1, "jory"), Game.approval(arg.call(1, "jory"))]
		"loyal":
			Game.make_loyal(arg.call(1, "jory"))
			return arg.call(1, "jory") + " is loyal"
		"recruit":
			Game.main.recruit(arg.call(1, "jory"))
			return "party: " + str(Game.main.party.map(func(p): return p.id))
		"god", "noclip", "ammo":
			Game.dev[c] = not Game.dev[c]
			return "%s %s" % [c, "ON" if Game.dev[c] else "OFF"]
		"ai":
			Game.dev.noai = arg.call(1) == "off" if arg.call(1) != "" else not Game.dev.noai
			return "enemy AI " + ("OFF" if Game.dev.noai else "ON")
		"give":
			var id := _find(Game.DB.items, arg.call(1))
			if id == "":
				return "unknown item: " + arg.call(1)
			var n := maxi(1, int(arg.call(2, "1")))
			Game.give(id, n)
			return "gave %d x %s" % [n, Game.iname(id)]
		"kit":
			var k: String = arg.call(1)
			var list: Array = []
			match k:
				"guns": list = Game.DB.items.keys().filter(func(x): return String(Game.DB.items[x].get("t", "")) == "weapon").map(func(x): return [x, 1])
				"armor": list = Game.DB.items.keys().filter(func(x): return String(Game.DB.items[x].get("t", "")) == "armor").map(func(x): return [x, 1])
				"ammo": list = Game.DB.items.keys().filter(func(x): return String(Game.DB.items[x].get("t", "")) == "ammo").map(func(x): return [x, 200])
				"chems": list = Game.L.consts.DRUGS.keys().filter(func(x): return Game.DB.items.has(x)).map(func(x): return [x, 3])
				"nades": list = Nade.THROWN.filter(func(x): return Game.DB.items.has(x)).map(func(x): return [x, 5])
				_: list = KITS.get(k, [])
			if list.is_empty():
				return "kits: guns ammo meds chems armor mats nades keys"
			for it in list:
				if Game.DB.items.has(it[0]):
					Game.give(String(it[0]), int(it[1]))
			Game.stats_changed.emit()
			return "added kit " + k
		"items":
			var f: String = arg.call(1)
			return ", ".join(Game.DB.items.keys().filter(func(k): return f == "" or f in k or String(Game.DB.items[k].get("t", "")) == f).map(func(k): return "%s (%s)" % [k, Game.iname(k)]))
		"caps", "chits":
			Game.caps = maxi(0, Game.caps + int(arg.call(1, "0")))
			Game.stats_changed.emit()
			return "%d caps" % Game.caps
		"xp":
			Game.add_xp(int(arg.call(1, "100")))
			return "level %d" % Game.level
		"level":
			var n := clampi(int(arg.call(1, str(Game.level + 1))), 1, 60)
			while Game.level < n:
				Game.level += 1
				Game.points += 1
				if Game.level % 2 == 0:
					Game.perk_pts += 1
			Game.hp = Game.hp_max
			Game.stats_changed.emit()
			return "level %d, %d stat points, %d perk points" % [Game.level, Game.points, Game.perk_pts]
		"heal":
			Game.rad = 0.0
			Game.hp = Game.hp_max
			Game.ap = Game.ap_max
			Game.stats_changed.emit()
			return "healed"
		"clean":
			for k in Game.drugs.keys():
				Game._end_drug(k)
			Game.addict.clear()
			return "clean"
		"set":
			var st: String = arg.call(1)
			var v := clampi(int(arg.call(2, "5")), 1, 10)
			if st == "all":
				for k in Game.stats:
					Game.stats[k] = v
			elif Game.stats.has(st):
				Game.stats[st] = v
			else:
				return "stats: " + " ".join(Game.stats.keys())
			Game.stats_changed.emit()
			return "%s = %d" % [st, v]
		"perk":
			var perks: Dictionary = Game.L.consts.PERKS
			if arg.call(1) == "all":
				for k in perks:
					Game.perks[k] = 1
				return "all perks"
			var id := _find(perks, arg.call(1))
			if id == "":
				return "perks: " + " ".join(perks.keys())
			Game.perks[id] = 1
			return "perk " + String(perks[id].n)
		"tp", "teleport":
			if a.size() >= 3 and arg.call(1).is_valid_float():
				_tp(float(arg.call(1)), float(arg.call(2)))
				return "moved"
			var id := _find(Game.DB.locs, arg.call(1))
			if id == "":
				return "unknown place (see locs)"
			var L: Dictionary = Game.DB.locs[id]
			if Game.area != "world":
				Game.travel_area("world", float(L.x), float(L.z) + float(L.get("r", 30)) * 0.5, 0.0)
				return "travelling to " + String(L.name)
			_tp(float(L.x), float(L.z) + float(L.get("r", 30)) * 0.5)
			Game.discover(id)
			return "at " + String(L.name)
		"locs":
			return "\n".join(Game.DB.locs.keys().map(func(k): return "%s (%s: %d, %d)" % [k, Game.DB.locs[k].name, int(Game.DB.locs[k].x), int(Game.DB.locs[k].z)]))
		"pos":
			var p: Vector3 = Game.player.global_position
			return "x %.1f  y %.1f  z %.1f  yaw %.2f  %s day %d  area %s" % [p.x, p.y, p.z, Game.player.yaw, Game.main.hud.pip._clock(), Game.day, Game.area]
		"time":
			Game.time = fposmod(float(arg.call(1, "12")), 24.0) / 24.0
			return "time " + Game.main.hud.pip._clock()
		"timescale":
			Engine.time_scale = clampf(float(arg.call(1, "1")), 0.1, 8.0)
			return "game speed x%.2f" % Engine.time_scale
		"weather":
			if Game.main.atmos == null:
				return "no weather indoors"
			Game.main.atmos.set_weather(arg.call(1, "clear"), true)
			return "weather " + arg.call(1, "clear")
		"spawn":
			var t := _find(Game.region.etypes, arg.call(1))
			if t == "":
				return "types: " + " ".join(Game.region.etypes.keys())
			var n := clampi(int(arg.call(2, "1")), 1, 20)
			var hostile: bool = arg.call(3) != "friendly"
			var pp: Vector3 = Game.player.global_position
			for i in n:
				var an: float = Game.player.yaw + randf_range(-0.45, 0.45)
				var dd := randf_range(7.0, 11.0)
				var e = Game.main.events._enemy(t, pp.x - sin(an) * dd, pp.z - cos(an) * dd, hostile)
				if e and hostile:
					e.state = "chase"
			return "spawned %d x %s" % [n, t]
		"enemies":
			return ", ".join(Game.region.etypes.keys().map(func(k): return "%s (%d hp)" % [k, int(Game.region.etypes[k].get("hp", 0))]))
		"killall":
			var n := 0
			for e in Game.main.enemies.duplicate():
				if is_instance_valid(e) and not e.dead and e.hostile and e.global_position.distance_to(Game.player.global_position) < 150.0:
					e.hit(99999.0, e.global_position + Vector3.UP, Vector3.FORWARD)
					n += 1
			return "killed %d" % n
		"quest":
			var id := _find(Game.L.quests, arg.call(1))
			if id == "":
				return "unknown quest"
			match arg.call(2, "start"):
				"start": Game.start(id)
				"complete": Game.complete(id)
				"advance":
					if not Game.quests.has(id):
						Game.start(id)
					elif Game.stage(id) < Game.L.quests[id].get("stages", []).size() - 1:
						Game.advance(id)
					else:
						Game.complete(id)
			var q = Game.quests.get(id, {})
			return "%s: %s" % [id, "complete" if q.get("done", false) else "stage %d" % (int(q.get("stage", 0)) + 1)]
		"quests":
			return "\n".join(Game.L.quests.keys().map(func(k): return "%-14s %-12s %s" % [k, ("complete" if Game.quests[k].done else "stage %d" % (int(Game.quests[k].stage) + 1)) if Game.quests.has(k) else "-", String(Game.L.quests[k].t)]))
		"flag":
			if a.size() < 2:
				return JSON.stringify(Game.flags).substr(0, 2000)
			if a.size() < 3:
				return "%s = %s" % [arg.call(1), JSON.stringify(Game.flags.get(arg.call(1)))]
			var raw: String = arg.call(2)
			var val: Variant = true if raw == "true" else (false if raw == "false" else (float(raw) if raw.is_valid_float() else raw))
			if val is bool and val == false:
				Game.flags.erase(arg.call(1))
			else:
				Game.flags[arg.call(1)] = val
			Game.check_quests()
			return "%s = %s" % [arg.call(1), JSON.stringify(Game.flags.get(arg.call(1)))]
		"reveal":
			for k in Game.DB.locs:
				Game.discover(k)
			return "map revealed"
		"buggy":
			if Game.main.buggy == null:
				return "no buggy in this area"
			var pp: Vector3 = Game.player.global_position
			Game.flags["buggy"] = {"fixed": true, "x": pp.x - sin(Game.player.yaw) * 4.0, "z": pp.z - cos(Game.player.yaw) * 4.0, "h": Game.player.yaw + PI}
			if not Game.has("buggy_key"):
				Game.give("buggy_key", 1)
			Game.main.buggy.global_position = Vector3(float(Game.flags.buggy.x), Game.height(float(Game.flags.buggy.x), float(Game.flags.buggy.z)), float(Game.flags.buggy.z))
			Game.main.buggy.h = float(Game.flags.buggy.h)
			Game.main.buggy._sync(0.0, true)
			return "buggy ready"
		"event":
			return ("event " + arg.call(1)) if Game.main.events.start(arg.call(1)) else "no room for that event here"
		"khole":
			Game.flags["leftVault"] = 1
			return "falling" if Game.main.khole_start(arg.call(1, "hole")) else "can't from here"
		"area":
			match arg.call(1):
				"vault":
					var V: Dictionary = Game.L.consts.VAULT_O
					Game.travel_area("vault", float(V.x) - 19.0, float(V.z) + 10.0, 0.0)
				"cell":
					Game.main.cell_travel(int(arg.call(2, "0")), true)
				_:
					var D: Dictionary = Game.DB.locs.dustwell
					Game.travel_area("world", float(D.x), float(D.z) + 10.0, 0.0)
			return "travelling"
		"forge":
			Game.main.forge.toggle()
			return "forge " + ("ON" if Game.main.forge.active else "OFF")
		"say":
			if a.size() < 3:
				return "say <who> <text>"
			Game.main.speak(" ".join(a.slice(2)), arg.call(1))
			return ""
		"clear":
			hist.clear()
			return ""
	return "Unknown command \"%s\". Type help." % c

func _tp(x: float, z: float) -> void:
	Game.player.global_position = Vector3(x, Game.height(x, z) + 0.5, z)
	Game.player.velocity = Vector3.ZERO
	Game.main.chunks.load_now(Game.player.global_position)
