# A terminal that feels like one: a green phosphor screen with scanlines and a faint flicker, a boot-up typed out
# line by line, a menu of entries to pick from, and the text of the entry typing itself out. Some terminals are
# password-locked: the memory dump shows a jumble of symbols with words hidden in it, one of them the password.
# Pick a word; a wrong one tells you how many letters it shares, in place, with the password. Four tries (five with
# Intelligence 7+, and at 9+ one wrong word is crossed out before you start); run out and the terminal locks you
# out until tomorrow.
class_name Terminal
extends Control

const GREEN := Color(0.45, 1.0, 0.55)
const DIM := Color(0.25, 0.62, 0.32)
const WORDS := {5: ["WATER", "STEEL", "SHAFT", "VAULT", "CRANE", "SPARK", "TOWER", "DRILL", "GAUGE", "VALVE", "FLASH", "PANEL", "CABLE", "SCREW", "NORTH", "PLANT", "TRAIN", "STAKE", "STORM", "BLAST"],
	7: ["REACTOR", "COOLANT", "TURBINE", "SHELTER", "CONTROL", "PISTONS", "MERCURY", "STATION", "BATTERY", "CIRCUIT", "WARHEAD", "NEUTRON", "FISSION", "CONDUIT", "MACHINE", "CAPTAIN", "FREIGHT", "COMPASS"],
	9: ["CONTAINED", "PRESSURES", "OPERATORS", "SHUTDOWNS", "MAINFRAME", "ISOLATION", "EMERGENCY", "SIGNATURE", "TRANSFORM", "AUTHORITY", "TELEMETRY", "CONDENSER", "GENERATOR", "SCRUBBERS"]}
const JUNK := "!@#$%^&*()-_=+[]{};:'\",.<>/?\\|`~"

var panel: Panel
var out: RichTextLabel
var dump_box: GridContainer
var foot: HBoxContainer
var mono: SystemFont
var head := ""
var entries: Array = []     # [title, text]
var on_done: Callable
var lock_id := ""
var level := 0
var password := ""
var tries := 4
var typing := ""
var typed := 0
var type_t := 0.0
var log_lines: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Screens._fill(self, 0, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Droid Sans Mono", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.045, 0.02)
	sb.border_color = Color(0.12, 0.14, 0.12)
	sb.set_border_width_all(14)
	sb.set_corner_radius_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	Screens._fill(panel, 30, 16)
	panel.visible = false
	var v := VBoxContainer.new()
	Screens._fill(v, 34, 26)
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	out = RichTextLabel.new()
	out.bbcode_enabled = true
	out.scroll_following = true
	out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	out.add_theme_font_override("normal_font", mono)
	out.add_theme_font_size_override("normal_font_size", 19)
	out.add_theme_color_override("default_color", GREEN)
	v.add_child(out)
	dump_box = GridContainer.new()
	dump_box.columns = 2
	dump_box.add_theme_constant_override("h_separation", 26)
	v.add_child(dump_box)
	foot = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	# scanlines, a slow roll and a little flicker over the whole screen
	var crt := ColorRect.new()
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Screens._fill(crt, 0, 0)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment(){
	float line = sin(FRAGCOORD.y * 1.6) * 0.5 + 0.5;
	float roll = smoothstep(0.0, 0.04, abs(fract(UV.y - TIME * 0.07) - 0.5) - 0.46);
	float flick = 0.03 * sin(TIME * 47.0) + 0.02 * sin(TIME * 13.0);
	vec2 c = UV - 0.5;
	float vig = smoothstep(0.35, 0.75, length(c * vec2(1.0, 1.2)));
	COLOR = vec4(0.0, 0.02, 0.0, line * 0.22 + vig * 0.55 + flick + (1.0 - roll) * 0.05);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	crt.material = m
	panel.add_child(crt)

func is_open() -> bool:
	return panel.visible

# entries: [[title, text], ...]; lock: 0 open, 1..3 password strength
func open(header: String, items: Array, lock := 0, id := "", done := Callable()) -> void:
	head = header
	entries = items
	on_done = done
	lock_id = id
	level = lock
	panel.visible = true
	Game.paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Game.main and Game.main.hud:
		Game.main.hud.touch.visible = false
		Game.main.hud.set_prompt("")
	Sfx.play("x_computer0", -6.0)
	out.text = ""
	log_lines = []
	_clear_foot()
	_clear_dump()
	if lock > 0 and Game.dev.get("locks", false):
		Game.opened["t_" + id] = true
	if lock > 0 and Game.flags.get("tlock_" + id) == Game.day:
		_type("MERIDIAN ATOMICS DATANET v2.3\n\n> TERMINAL LOCKED\n> TOO MANY FAILED LOGON ATTEMPTS\n> LOCKOUT CLEARS AT THE NEXT DAILY RESET (TOMORROW)\n> OR CONTACT AN ADMINISTRATOR\n", func(): _exit_only())
		return
	if lock > 0 and not Game.opened.has("t_" + id):
		_type("MERIDIAN ATOMICS DATANET v2.3\nCOPYRIGHT MERIDIAN ATOMICS POWER CO.\n\n> SET TERMINAL/INQUIRE\n> SET HALT RESTART/MAINT\n> RUN DEBUG/ACCOUNTS.F\n\nPASSWORD REQUIRED\n", _hack)
	else:
		_boot()

func close() -> void:
	if not panel.visible:
		return
	panel.visible = false
	Game.paused = false
	get_tree().paused = false
	if Game.main and Game.main.hud:
		Game.main.hud.touch.visible = Game.main.hud.touch_on
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Game.main.hud.touch_on else Input.MOUSE_MODE_CAPTURED
	if on_done.is_valid():
		on_done.call()

func _unhandled_key_input(e: InputEvent) -> void:
	if panel.visible and e.pressed and not e.echo and (e.keycode == KEY_ESCAPE or e.keycode == KEY_TAB):
		close()
		get_viewport().set_input_as_handled()

func _process(d: float) -> void:
	if not panel.visible or typing == "":
		return
	type_t += d
	var per := 0.012
	while type_t > per and typed < typing.length():
		type_t -= per
		typed += 1
		if typed % 5 == 0:
			Sfx.play("k_click", -26.0, randf_range(1.4, 1.8))
	out.text = "\n".join(log_lines) + ("\n" if not log_lines.is_empty() else "") + typing.substr(0, typed) + ("_" if int(Time.get_ticks_msec() / 300) % 2 == 0 else " ")
	if typed >= typing.length():
		log_lines.append(typing)
		out.text = "\n".join(log_lines)
		typing = ""
		if has_meta("then"):
			var c: Callable = get_meta("then")
			remove_meta("then")
			if c.is_valid():
				c.call()

func _type(t: String, then := Callable()) -> void:
	typing = t
	typed = 0
	type_t = 0.0
	set_meta("then", then)

func _btn(t: String, f: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", mono)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", GREEN)
	b.add_theme_color_override("font_hover_color", Color(0.02, 0.08, 0.03))
	var hv := StyleBoxFlat.new()
	hv.bg_color = GREEN
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func():
		Sfx.play("k_click", -10.0, 1.4)
		f.call())
	(parent if parent else foot).add_child(b)
	return b

func _clear_foot() -> void:
	for c in foot.get_children():
		c.queue_free()

func _clear_dump() -> void:
	for c in dump_box.get_children():
		c.queue_free()
	dump_box.visible = false

func _exit_only() -> void:
	_clear_foot()
	_btn("[ EXIT ]", close)

# ---------------------------------------------------------------- the menu and the entries
func _boot() -> void:
	log_lines = []
	_type("%s\n%s\n" % [head, "=".repeat(mini(48, head.length() + 4))], _menu)

func _menu() -> void:
	_clear_foot()
	_clear_dump()
	# a long menu scrolls inside the screen instead of running off the bottom of it (build 17 report: the Meridian
	# reactor's terminal)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var room := get_viewport_rect().size.y * 0.5
	sc.custom_minimum_size = Vector2(0, minf((entries.size() + 1) * 46.0, room))
	foot.add_child(sc)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	for e in entries:
		var ee: Array = e
		_btn("> " + String(ee[0]).to_upper(), func(): _read(ee), col)
	_btn("> EXIT", close, col)

func _read(e: Array) -> void:
	_clear_foot()
	log_lines = []
	_type("%s\n\n%s\n" % [String(e[0]).to_upper(), String(e[1])], func():
		_clear_foot()
		_btn("[ BACK ]", func():
			log_lines = []
			_boot())
		_btn("[ EXIT ]", close))

# ---------------------------------------------------------------- the password hack
func _hack() -> void:
	var n: int = [5, 5, 7, 9][clampi(level, 0, 3)]
	var pool: Array = WORDS[n].duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(lock_id + str(Game.day))
	# shuffle deterministically for the day
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var words: Array = pool.slice(0, mini(10, pool.size()))
	password = words[rng.randi() % words.size()]
	tries = 4 + (1 if int(Game.stats.get("intellect", 5)) >= 7 else 0)
	_clear_foot()
	_clear_dump()
	dump_box.visible = true
	var addr := 0xF4A0 + rng.randi() % 0x300
	var cross := ""
	if int(Game.stats.get("intellect", 5)) >= 9:
		for w in words:
			if w != password:
				cross = w
				break
	for i in words.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		dump_box.add_child(row)
		var pre := Label.new()
		var junk := ""
		for k in 6:
			junk += JUNK[rng.randi() % JUNK.length()]
		pre.text = "0x%04X %s" % [addr + i * 12, junk]
		pre.add_theme_font_override("font", mono)
		pre.add_theme_font_size_override("font_size", 19)
		pre.add_theme_color_override("font_color", DIM)
		row.add_child(pre)
		var w: String = words[i]
		var b := _btn(w, func(): _guess(w), row)
		if w == cross:
			b.disabled = true
			b.text = ".".repeat(w.length())
		var post := Label.new()
		var j2 := ""
		for k in 4:
			j2 += JUNK[rng.randi() % JUNK.length()]
		post.text = j2
		post.add_theme_font_override("font", mono)
		post.add_theme_font_size_override("font_size", 19)
		post.add_theme_color_override("font_color", DIM)
		row.add_child(post)
	_tries_label()
	_btn("[ GIVE UP ]", close)

func _tries_label() -> void:
	var l := foot.get_node_or_null("Tries") as Label
	if l == null:
		l = Label.new()
		l.name = "Tries"
		l.add_theme_font_override("font", mono)
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", GREEN)
		foot.add_child(l)
		foot.move_child(l, 0)
	l.text = "ATTEMPTS LEFT: " + " ".join(PackedStringArray(range(tries).map(func(_i): return "■"))) + "     "

func _guess(w: String) -> void:
	if typing != "":
		return
	if w == password:
		Sfx.play("x_computer1", -4.0)
		Game.opened["t_" + lock_id] = true
		Game.add_xp(20 + level * 15)
		_clear_dump()
		_clear_foot()
		log_lines = ["> " + w, "> EXACT MATCH!", "> PLEASE WAIT WHILE SYSTEM IS ACCESSED."]
		_type("\n%s\n%s\n" % [head, "=".repeat(mini(48, head.length() + 4))], _menu)
		return
	tries -= 1
	var like := 0
	for i in mini(w.length(), password.length()):
		if w[i] == password[i]:
			like += 1
	log_lines.append("> %s\n> ENTRY DENIED\n> LIKENESS=%d" % [w, like])
	out.text = "\n".join(log_lines)
	Sfx.play("k_metal_click", -6.0)
	_tries_label()
	if tries <= 0:
		Game.flags["tlock_" + lock_id] = Game.day
		_clear_dump()
		_type("\n> TERMINAL LOCKED\n> LOCKOUT CLEARS AT THE NEXT DAILY RESET (TOMORROW)\n> COME BACK AFTER YOU HAVE SLEPT, OR CONTACT AN ADMINISTRATOR\n", func(): _exit_only())
