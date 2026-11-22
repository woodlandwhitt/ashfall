# FOCUS, the original's targeting mode: time stops, you pick an enemy in view and queue shots at its head, torso,
# arms or legs (each with its own chance from distance, Aim, the weapon and perks), paying action points per shot;
# then the shots play out. Head shots double damage; leg hits slow the target, arm hits make it miss more.
class_name Focus
extends Control

const GREEN := Color(0.55, 1.0, 0.6)
const DIM := Color(0.35, 0.7, 0.42)

var list: Array = []      # enemies in view, best first
var idx := 0
var queue: Array = []     # [{e, part, c}]
var cost := 20.0
var exec := -1            # index of the next queued shot while playing out
var exec_t := 0.0
var panel: PanelContainer
var info: Label
var parts_box: VBoxContainer
var go_b: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -360
	panel.offset_right = -16
	panel.offset_top = 70
	panel.offset_bottom = -16
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.07, 0.03, 0.82)
	sb.border_color = Color(0.3, 0.8, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.theme = Screens.pip_theme()
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_theme_font_size_override("font_size", 18)
	v.add_child(info)
	var nav := HBoxContainer.new()
	v.add_child(nav)
	for t in [["<", -1], [">", 1]]:
		var b := Button.new()
		b.text = t[0] + " TARGET" if t[1] < 0 else "TARGET " + t[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(func(): _cycle(t[1]))
		nav.add_child(b)
	parts_box = VBoxContainer.new()
	parts_box.add_theme_constant_override("separation", 6)
	parts_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(parts_box)
	var bot := HBoxContainer.new()
	v.add_child(bot)
	var cl := Button.new()
	cl.text = "CLEAR"
	cl.custom_minimum_size = Vector2(0, 52)
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.pressed.connect(func(): queue.clear(); Sfx.play("k_click", -8.0); _render())
	bot.add_child(cl)
	var cx := Button.new()
	cx.text = "CANCEL"
	cx.custom_minimum_size = Vector2(0, 52)
	cx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cx.pressed.connect(cancel)
	bot.add_child(cx)
	go_b = Button.new()
	go_b.text = "EXECUTE"
	go_b.custom_minimum_size = Vector2(0, 64)
	go_b.pressed.connect(execute)
	v.add_child(go_b)
	visible = false

func active() -> bool:
	return visible or exec >= 0

# ---------------------------------------------------------------- body parts and chances (main.js focusParts/focusChance)
func hb(e) -> Array:
	var t: Dictionary = Game.L.get("consts", {}).get("HITBOX", {})
	return t.get(String(e.type), [1.2, 0.5, 1.72, 0.2])

func parts(e) -> Array:
	var h := hb(e)
	var s := float(e.def.get("scale", 1.0)) if e.def.get("scale") != null else 1.0
	var out := []
	if float(h[3]) > 0.0:
		out.append({"k": "head", "n": "HEAD", "y": float(h[2]) * s, "mod": 0.58, "mul": 2.0})
	out.append({"k": "torso", "n": "BODY" if e.quad else "TORSO", "y": float(h[0]) * s, "mod": 1.0, "mul": 1.0})
	if not e.quad:
		out.append({"k": "arms", "n": "ARMS", "y": float(h[0]) * s * 1.05, "mod": 0.72, "mul": 0.8, "side": 0.4 * s})
	out.append({"k": "legs", "n": "LEGS", "y": (0.22 if e.quad else 0.45) * s, "mod": 0.74, "mul": 0.8})
	return out

func chance(e, p: Dictionary) -> float:
	var w := Game.item(Game.weapon)
	var kind := String(w.get("kind", "pistol"))
	var rng := float(w.get("range", 60))
	var d: float = e.global_position.distance_to(Game.player.global_position)
	if kind == "melee":
		return 0.95 if d < rng + 1.0 else 0.0
	var c := (1.0 - d / rng * 0.8) * float(p.mod) * (1.0 + (int(Game.stats.aim) - 5) * 0.05) + (0.12 if Game.perks.has("sharpshooter") else 0.0)
	if kind == "shotgun":
		c += 0.2 if d < 12.0 else -0.15
	if kind == "rifle":
		c += 0.1
	return clampf(c, 0.03, 0.95)

# ---------------------------------------------------------------- entering, choosing
func enter() -> void:
	var p = Game.player
	if p == null or active() or Game.paused or Game.main.in_dialog():
		return
	var w := Game.item(Game.weapon)
	if w.is_empty():
		Game.msg("No weapon equipped")
		return
	var kind := String(w.get("kind", "pistol"))
	cost = float(Game.L.get("consts", {}).get("AP_COST", {}).get(kind, 20))
	if Game.ap < cost:
		Game.msg("Not enough Action Points")
		Sfx.play("k_metal_click", -6.0)
		return
	var rng := float(w.get("range", 60)) + 1.0 if kind == "melee" else minf(float(w.get("range", 60)), 90.0)
	var eye: Vector3 = p.cam.global_position
	var fwd: Vector3 = -p.cam.global_basis.z
	var found := []
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for e in Game.main.enemies:
		if e.dead:
			continue
		var at: Vector3 = e.global_position + Vector3.UP * float(hb(e)[0])
		var to := at - eye
		var d := to.length()
		if d > rng:
			continue
		var dot := fwd.dot(to / d)
		if dot < 0.5:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, at, 1)
		if not space.intersect_ray(q).is_empty():
			continue
		found.append({"e": e, "a": dot - (0.3 if not e.hostile else 0.0)})
	if found.is_empty():
		Game.msg("FOCUS: no targets in range")
		Sfx.play("k_metal_click", -6.0)
		return
	found.sort_custom(func(a, b): return a.a > b.a)
	list = found.map(func(f): return f.e)
	idx = 0
	queue.clear()
	visible = true
	Game.paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.main.hud.touch.visible = false
	Sfx.play("o_hatch_open", -14.0, 2.2)
	_look()
	_render()

func _cycle(dv: int) -> void:
	idx = (idx + dv + list.size()) % list.size()
	Sfx.play("k_click", -8.0)
	_look()
	_render()

func _look() -> void:
	var e = list[idx]
	var p = Game.player
	var at: Vector3 = e.global_position + Vector3.UP * float(hb(e)[0])
	var to: Vector3 = at - p.cam.global_position
	p.yaw = atan2(-to.x, -to.z)
	p.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	p.rotation.y = p.yaw
	p.cam.rotation = Vector3(p.pitch, 0, 0)

func _render() -> void:
	var e = list[idx]
	var w := Game.item(Game.weapon)
	var left := Game.ap - queue.size() * cost
	var loaded := (Game.mag - queue.size()) if w.has("mag") else 99
	var nm := String(Game.DB.enemies.get(e.type, {}).get("n", e.type))
	info.text = "%s%s\nHP %d / %d\nAP %d / %d · %d per shot\n%s%s\nQUEUED %d" % [nm.to_upper(), "" if e.hostile else " (not hostile)",
		maxi(0, ceili(e.hp)), int(e.def.get("hp", e.hp)), int(left), int(Game.ap_max), int(cost), Game.iname(Game.weapon),
		(" · %d loaded" % maxi(0, loaded)) if w.has("mag") else "", queue.size()]
	for c in parts_box.get_children():
		c.queue_free()
	for p in parts(e):
		var c := chance(e, p)
		var n := queue.filter(func(s): return s.e == e and s.part.k == p.k).size()
		var b := Button.new()
		b.text = "%s%s%s   %d%%" % [p.n, " (crippled)" if e.get("crip").has(p.k) else "", (" x%d" % n) if n else "", roundi(c * 100.0)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 54)
		b.disabled = left < cost or loaded <= 0 or c <= 0.0
		b.pressed.connect(func():
			queue.append({"e": e, "part": p, "c": c})
			Sfx.play("k_click", -4.0, 1.4)
			_render())
		parts_box.add_child(b)
	go_b.disabled = queue.is_empty()
	queue_redraw()

func cancel() -> void:
	visible = false
	queue.clear()
	_unpause()

func _unpause() -> void:
	Game.paused = false
	get_tree().paused = false
	Game.main.hud.touch.visible = Game.main.hud.touch_on

func execute() -> void:
	if queue.is_empty():
		return
	visible = false
	_unpause()
	exec = 0
	exec_t = 0.25
	Engine.time_scale = 0.35

# ---------------------------------------------------------------- playing the shots out (slow motion)
func _physics_process(dt: float) -> void:
	if exec < 0:
		return
	var p = Game.player
	dt /= maxf(Engine.time_scale, 0.01)
	var cur = queue[exec] if exec < queue.size() else null
	if cur and is_instance_valid(cur.e) and not cur.e.dead:
		var at: Vector3 = cur.e.global_position + Vector3.UP * float(cur.part.y)
		var to: Vector3 = at - p.cam.global_position
		var ty := atan2(-to.x, -to.z)
		var tp := atan2(to.y, Vector2(to.x, to.z).length())
		p.yaw += wrapf(ty - p.yaw, -PI, PI) * minf(1.0, dt * 14.0)
		p.pitch += (tp - p.pitch) * minf(1.0, dt * 14.0)
	exec_t -= dt
	if exec_t > 0.0:
		return
	if cur == null or Game.hp <= 0:
		_done()
		return
	exec += 1
	exec_t = 0.55
	if not is_instance_valid(cur.e) or cur.e.dead:
		exec_t = 0.05
		return
	var w := Game.item(Game.weapon)
	if w.has("mag"):
		if Game.mag <= 0:
			Game.msg("Magazine empty")
			_done()
			return
		Game.mag -= 1
	Game.ap = maxf(0.0, Game.ap - cost)
	var e = cur.e
	var part: Dictionary = cur.part
	var right: Vector3 = p.cam.global_basis.x
	var at: Vector3 = e.global_position + Vector3.UP * float(part.y) + (right * float(part.side) if part.has("side") else Vector3.ZERO)
	var kind := String(w.get("kind", "pistol"))
	p.shot_fx(kind)
	var hit := randf() < chance(e, part)
	if kind != "melee":
		var miss := Vector3.ZERO if hit else Vector3(randf() - 0.5, 0.6 + randf(), randf() - 0.5) * Vector3(2.4, 1.0, 2.4)
		Game.main.tracer(p.vm.muzzle_pos(), at + miss, Color(0.4, 0.85, 1.0) if kind == "energy" else Color(1.0, 0.88, 0.6))
	if hit:
		var pel := int(w.get("pellets", 1))
		var dmg: float = p.weapon_damage() * pel * (0.75 if pel > 1 else 1.0) * float(part.mul) * randf_range(0.9, 1.1)
		if part.k == "legs" or part.k == "arms":
			e.crip[part.k] = true
		e.hit(dmg, at, (at - p.cam.global_position).normalized())
		if e.dead and Game.perks.has("grim_reaper"):
			Game.ap = Game.ap_max
			Game.msg("Grim Reaper's Sprint: Action Points restored.")
		if part.k == "head":
			Game.msg("Head shot!")
	else:
		Game.main.float_text(at + Vector3.UP * 0.4, "MISS")
	p.hurt_shake = maxf(p.hurt_shake, 0.12)
	Game.stats_changed.emit()

func _done() -> void:
	exec = -1
	queue.clear()
	Engine.time_scale = 1.0

# a box around the chosen target while choosing
func _draw() -> void:
	if not visible or list.is_empty():
		return
	var e = list[idx]
	var cam: Camera3D = Game.player.cam
	var h := hb(e)
	var top: Vector3 = e.global_position + Vector3.UP * (float(h[2]) + float(h[3]) if float(h[3]) > 0.0 else float(h[0]) + float(h[1]))
	if cam.is_position_behind(top):
		return
	var a := cam.unproject_position(top)
	var b := cam.unproject_position(e.global_position)
	var hh := maxf(30.0, b.y - a.y)
	var ww := maxf(30.0, hh * (1.5 if e.quad else 0.55))
	draw_rect(Rect2(a.x - ww / 2, a.y, ww, hh), Color(0.55, 1.0, 0.6, 0.9), false, 2.0)
