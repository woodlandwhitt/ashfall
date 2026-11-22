# A hostile: wanders near its spawn, notices you by sight or by gunfire, paths to you over Godot's navigation mesh
# (straight-line steering until the mesh has baked), then bites or shoots. Dead ones can be searched.
extends CharacterBody3D

var type := ""
var def: Dictionary = {}
var hp := 40.0
var hp_max := 40.0
var model: Node3D
var rig: Rig
var agent: NavigationAgent3D
var home := Vector3.ZERO
var state := "idle"
var target := Vector3.ZERO
var wait := 0.0
var face_yaw := 0.0
var atk_cd := 0.0
var repath := 0.0
var dead := false
var looted := false
var t := 0.0
var flash := 0.0
var quad := false
var ranged := false
var speed := 3.0
var dmg := 8.0
var hostile := true
var bark_cd := 0.0
var ap: AnimationPlayer   # people use Quaternius bodies; creatures keep their original models
var act_t := 0.0          # a one-shot animation (shoot, hit, punch) is playing
var near := true
var idx := -1
var eid := ""          # the spawn's id: quests ask whether a named enemy is dead
var group := ""        # neutral groups (Kess's crew, the herd) turn on you together
var loot = null          # what the body holds once searched
var npc = null           # a townsperson you provoked
var essential := false   # they yield instead of dying
var foe = null           # the companion it is fighting, or null for you
var crip := {}           # FOCUS hits: crippled legs slow it, crippled arms spoil its aim
# tactics: what it is doing inside a fight
var tac := "advance"     # advance, strafe, cover, peek, flee, circle
var tac_t := 0.0
var strafe := 1.0
var cover := Vector3.ZERO
var burst := 0           # shots left in this burst
var windup := 0.0        # a melee blow on its way (you can step out of it)
var slot := 0.0          # the side it comes at you from, so a pack spreads out instead of stacking
var fled := false
var seen_t := 0.0        # how long you've been in its sight

# outfit, cloth tint, skin tint for the human hostiles
const PEOPLE := {
	"raider": ["Male_Ranger", Color(0.62, 0.5, 0.44), Color(1.0, 0.85, 0.75)],
	"jackal": ["Male_Peasant", Color(0.7, 0.58, 0.4), Color(0.85, 0.7, 0.6)],
	"heavy": ["Male_Ranger", Color(0.38, 0.38, 0.42), Color(0.8, 0.66, 0.56)],
	"marauder": ["Female_Ranger", Color(0.6, 0.32, 0.28), Color(1.0, 0.86, 0.78)],
	"pyro": ["Male_Peasant", Color(0.4, 0.37, 0.34), Color(0.75, 0.6, 0.5)],
	"ghoul": ["Male_Peasant", Color(0.48, 0.48, 0.4), Color(0.7, 0.85, 0.55)],
	"tollking": ["Male_Ranger", Color(0.75, 0.62, 0.3), Color(0.9, 0.75, 0.65)],
}

func setup(d: Dictionary, td: Dictionary) -> void:
	type = d.type
	def = td
	if d.get("name") != null:
		def = td.duplicate()
		def["name"] = String(d.name)
	quad = bool(td.get("quad", false))
	ranged = (bool(td.get("ranged", false)) or bool(d.get("ranged", false))) and not quad
	hp_max = float(td.get("hp", 40)) if td.get("hp") != null else 40.0
	hp = hp_max
	speed = (float(td.speed) if td.get("speed") != null else 3.2) * (1.0 if quad else 0.85)
	speed = clampf(speed, 2.2, 6.5)
	dmg = float(td.dmg) if td.get("dmg") != null else 8.0
	hostile = bool(d.get("hostile", true))
	eid = String(d.get("id", "")) if d.get("id") != null else ""
	group = String(d.get("group", "")) if d.get("group") != null else ""
	position = Vector3(d.x, Game.height(d.x, d.z), d.z)
	home = position
	face_yaw = randf() * TAU
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	if quad:
		var b := BoxShape3D.new()
		b.size = Vector3(0.7, 0.9, 1.3)
		cs.shape = b
		cs.position.y = 0.45
	else:
		var cap := CapsuleShape3D.new()
		cap.radius = 0.34
		cap.height = 1.75
		cs.shape = cap
		cs.position.y = 0.88
	add_child(cs)
	if d.has("look"):
		# a townsperson who turned on you keeps their own face and clothes
		model = Humanoid.person(d.look, hash(String(d.get("npc", ""))), "guard" if type == "townguard" else "")
		add_child(model)
		ap = model.get_node("AnimationPlayer")
		if ranged:
			ap.play("Pistol_Aim_Neutral")
			ap.seek(0.0, true)
			Humanoid.hold_gun(model, load("res://guns/Pistol_4.glb"), Basis(Vector3.UP, PI / 2.0).scaled(Vector3.ONE * 0.121))
		ap.play("Pistol_Idle" if ranged else "Idle")
	elif PEOPLE.has(type) and not quad:
		var p: Array = PEOPLE[type]
		# every raider his own: cut, dye, skin, hair, beard, headgear
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(d.get("id", "")) + type + str(d.x))
		var fem: bool = String(p[0]).begins_with("Female") or (type in ["raider", "jackal"] and rng.randf() < 0.25)
		var outfit: String = p[0]
		if not fem and type in ["raider", "jackal", "pyro"]:
			outfit = ["Male_Ranger", "Male_Peasant", "Male_Knight_Cloth", "Male_Ranger"][rng.randi() % 4]
		elif fem:
			outfit = "Female_Ranger" if rng.randf() < 0.6 else "Female_Peasant"
		if type == "heavy":
			outfit = "Male_Knight_Cloth"
		elif type == "tollking":
			outfit = "Male_Noble"
		var cloth: Color = (p[1] as Color).lerp(Color.from_hsv(rng.randf(), 0.4, 0.6), 0.25) * rng.randf_range(0.8, 1.1)
		var skins := [Color(1.0, 0.86, 0.76), Color(0.85, 0.66, 0.52), Color(0.62, 0.45, 0.33), Color(0.45, 0.32, 0.24), Color(0.95, 0.78, 0.66)]
		var skin: Color = p[2] if type == "ghoul" else skins[rng.randi() % skins.size()]
		model = Humanoid.build(outfit, cloth, skin)
		var hc: Color = Humanoid.HAIR_COLS[rng.randi() % Humanoid.HAIR_COLS.size()]
		var hat: String = ["", "", "cap", "wide", "helmet", ""][rng.randi() % 6] if type != "ghoul" else ""
		if type == "heavy":
			hat = "helmet"
		if hat != "helmet" and type != "ghoul":
			Humanoid.add_hair(model, (Humanoid.HAIR_F if fem else Humanoid.HAIR_M)[rng.randi() % 6], hc)
		if not fem and type != "ghoul":
			Humanoid.add_hair(model, Humanoid.FACE_M[rng.randi() % Humanoid.FACE_M.size()], hc)
		if hat != "":
			Humanoid.add_hat(model, hat, Color(0.33, 0.34, 0.33) if hat == "helmet" else Color.from_hsv(rng.randf(), 0.3, 0.35))
		var hh := rng.randf_range(0.95, 1.05)
		model.scale = Vector3.ONE * hh * (1.12 if type == "heavy" else 1.0)
		add_child(model)
		ap = model.get_node("AnimationPlayer")
		if ranged:
			ap.play("Pistol_Aim_Neutral")
			ap.seek(0.0, true)
			Humanoid.hold_gun(model, load("res://guns/Pistol_4.glb"), Basis(Vector3.UP, PI / 2.0).scaled(Vector3.ONE * 0.121))
		ap.play("Pistol_Idle" if ranged else "Idle")
		ap.seek(randf() * 2.0, true)
	else:
		var ps: PackedScene = load(Game.char_path("enemy_" + type + ".glb"))
		model = ps.instantiate()
		add_child(model)
		rig = Rig.new(model, quad)
	for mi in model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).visibility_range_end = 150.0
	slot = float(absi(hash(eid + str(d.x) + str(d.z))) % 6283) / 1000.0
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 1.0
	agent.target_desired_distance = 1.2
	agent.radius = 0.5
	add_child(agent)
	target = home

func hit(amount: float, at: Vector3, dir: Vector3) -> void:
	if dead:
		return
	if Game.dev.onehit:
		amount = maxf(amount, hp + 1.0)
	hp -= amount
	flash = 0.12
	if ap and hp > 0.0:
		_one_shot(["Hit_Chest", "Hit_Head"][randi() % 2], 0.45)
	Game.main.blood(at, dir)
	Sfx.play_at(("o_bark2" if quad else ["o_mhurt1", "o_mhurt2"][randi() % 2]), at, 0.0, randf_range(0.9, 1.1))
	if hp <= 0.0 and essential:
		if hostile:
			Game.main.npc_yield(self)
		hp = 1.0
		return
	if hp <= 0.0:
		die(dir)
	else:
		if state != "chase":
			alert()
		state = "chase"
		if not hostile and eid != "" and Game.main:
			hostile = true
			Game.main.make_hostile(eid)
		hostile = true
		velocity += dir * 2.0

func die(dir: Vector3) -> void:
	dead = true
	if npc != null and Game.main:
		Game.main.npc_died(self)
	if idx >= 0:
		Game.dead[str(idx)] = true
	state = "dead"
	collision_layer = 0
	Sfx.play_at("o_creature2" if quad else ["o_mdie1", "o_mdie2"][randi() % 2], global_position + Vector3.UP)
	if ap:
		ap.active = true
		ap.play("Death01", 0.1)
		Game.on_kill(type, eid)
		Game.add_xp(int(def.get("xp", 40)) if def.get("xp") != null else 40)
		return
	var tw := create_tween()
	var side := 1.0 if randf() < 0.5 else -1.0
	tw.tween_property(model, "rotation:z", side * PI / 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "position:y", 0.25 if quad else 0.3, 0.45)
	Game.on_kill(type, eid)
	Game.add_xp(int(def.get("xp", 25 if quad else 40)) if def.get("xp") != null else (25 if quad else 40))

func hear(at: Vector3) -> void:
	if not dead and hostile and global_position.distance_to(at) < 60.0:
		state = "chase"

# line of sight through the world (not through you or itself: both sit on the world's collision layer)
func can_see(p: Vector3, from := Vector3.INF) -> bool:
	if Game.dev.invis:
		return false
	var a := (global_position if from == Vector3.INF else from) + Vector3.UP * 1.2
	var q := PhysicsRayQueryParameters3D.create(a, p + Vector3.UP * 1.3, 1)
	q.exclude = [get_rid(), Game.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# a shout brings the rest of its group (or anything hostile close by) into the fight
func alert() -> void:
	for e in Game.main.enemies:
		if e != self and is_instance_valid(e) and not e.dead and e.hostile and e.state != "chase" and e.global_position.distance_to(global_position) < 22.0:
			e.state = "chase"
			e.tac = "advance"

func _physics_process(d: float) -> void:
	if Game.dev.noai and not dead:
		velocity = Vector3.ZERO
		return
	t += d
	if flash > 0.0:
		flash -= d
	if dead:
		return
	var P := Game.player
	var pp := P.global_position
	var dist := global_position.distance_to(pp)
	# a companion closer than you draws the fight
	foe = null
	if state == "chase" and hostile:
		for c in Game.main.party:
			if c.down <= 0.0:
				var cd: float = global_position.distance_to(c.global_position)
				if cd < dist * 0.8 and cd < 30.0:
					foe = c
					pp = c.global_position
					dist = cd
	var is_near := dist < 55.0
	if ap and is_near != near:
		near = is_near
		ap.active = near
	if dist > 90.0 and state != "chase":
		return
	act_t -= d
	atk_cd -= d
	bark_cd -= d
	var spd := 0.0
	var aim := false
	if Game.hp <= 0.0 and state == "chase":
		state = "idle"
	match state:
		"idle":
			wait -= d
			if wait <= 0.0:
				var a := randf() * TAU
				target = home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 10.0)
				wait = randf_range(4.0, 9.0)
			if global_position.distance_to(target) > 1.0:
				spd = _move_to(target, speed * 0.35, d)
			# what it notices depends on you: sneaking, standing still and being behind it all help
			var vis: float = Game.player.visibility() if Game.player and foe == null else 1.0
			var facev := Vector3(sin(face_yaw), 0, cos(face_yaw))
			var tov := pp - global_position
			tov.y = 0.0
			if tov.length() > 0.1 and facev.dot(tov.normalized()) < -0.2:
				vis *= 0.55
			if hostile and Game.hp > 0.0 and dist < (24.0 if quad else 30.0) * vis and int(t * 4.0) % 2 == 0 and can_see(pp):
				state = "chase"
				tac = "advance"
				alert()
				if bark_cd <= 0.0:
					bark_cd = 4.0
					Sfx.play_at("o_bark1" if quad else "o_creature1", global_position + Vector3.UP, -2.0)
		"chase":
			if dist > 70.0:
				state = "idle"
			var r := _tactics(d, pp, dist)
			spd = r[0]
			aim = r[1]
	if spd == 0.0:
		velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-8.0 * d))
		velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-8.0 * d))
	# a hostile standing still on the ground skips the physics step
	if spd > 0.0 or not is_on_floor() or Vector2(velocity.x, velocity.z).length() > 0.05:
		velocity.y = -6.0 if not is_on_floor() else -0.5
		move_and_slide()
	model.rotation.y = face_yaw
	if dist < 55.0:
		if ap:
			if act_t <= 0.0:
				var a := "Idle"
				if spd > 2.0:
					a = "Jog_Fwd"
				elif spd > 0.3:
					a = "Walk"
				elif aim:
					a = "Pistol_Aim_Neutral"
				elif ranged:
					a = "Pistol_Idle"
				Humanoid.play(ap, a, clampf(spd / 3.2, 0.8, 1.4) if spd > 2.0 else 1.0)
		else:
			rig.animate(d, spd, t, aim)

# ---------------------------------------------------------------- fighting
# Animals and brawlers come at you from different sides, circle out of reach between bites and wind up each blow
# (step back and it misses). Gunmen keep a working distance, strafe while they shoot in bursts, back off when you
# close in, duck behind cover to recover when hurt, and break and run when nearly dead.
func _tactics(d: float, pp: Vector3, dist: float) -> Array:
	var spd := 0.0
	var aim := false
	tac_t -= d
	var sees := can_see(pp)
	seen_t = seen_t + d if sees else 0.0
	var leg := 0.55 if crip.has("legs") else 1.0
	var to := pp - global_position
	to.y = 0.0
	var dirv := to.normalized() if to.length() > 0.01 else Vector3.FORWARD
	var side := Vector3(-dirv.z, 0, dirv.x)
	var hurt := hp / hp_max
	# nearly dead: run (bosses and the essential never do)
	if not fled and hurt < 0.22 and not def.get("boss", false) and not essential and randf() < 0.6:
		fled = true
		tac = "flee"
		tac_t = randf_range(4.0, 7.0)
	if tac == "flee":
		if tac_t <= 0.0:
			tac = "advance"
		else:
			return [_move_to(global_position - dirv * 8.0 + side * strafe * 3.0, speed * leg, d), false]
	if windup > 0.0:
		windup -= d
		_face(pp, d)
		if windup <= 0.0:
			var reach := (1.9 if quad else 2.0) + 0.4
			if dist <= reach:
				_deal(dmg * randf_range(0.7, 1.2))
			atk_cd = 1.0 if quad else 1.1
			if quad or randf() < 0.5:
				tac = "circle"
				tac_t = randf_range(0.8, 1.6)
				strafe = 1.0 if randf() < 0.5 else -1.0
		return [0.0, false]
	if not ranged:
		var reach := 1.9 if quad else 2.0
		if tac == "circle" and tac_t > 0.0:
			# back off a little and circle, then come again
			var ring := pp - dirv * 3.2 + side * strafe * 2.5
			return [_move_to(ring, speed * 0.8 * leg, d), false]
		tac = "advance"
		if dist > reach:
			# from far away, straight in; close up, come round to its own side of you
			var goal := pp
			if dist < 7.0:
				var off := Vector3(cos(slot), 0, sin(slot))
				goal = pp + off * reach * 0.8
				if goal.distance_to(global_position) < 0.6:
					goal = pp
			# zig-zag when you're pointing a gun at it
			var aimed := (-Game.player.global_transform.basis.z).dot(-dirv) > 0.96
			if aimed and dist > 4.0:
				goal += side * sin(t * 3.0 + slot) * 2.5
			spd = _move_to(goal, speed * leg * (1.15 if dist < 6.0 else 1.0), d)
		else:
			_face(pp, d)
		if atk_cd <= 0.0 and dist <= reach and sees:
			windup = 0.32 if quad else 0.4
			if not quad:
				_one_shot(["Punch_Jab", "Punch_Cross"][randi() % 2], 0.6)
			Sfx.play_at("o_bark1" if quad else "k_cloth1", global_position + Vector3.UP, -3.0, randf_range(0.9, 1.1))
		return [spd, false]
	# ---- gunmen
	var want_lo := 7.0
	var want_hi := 20.0
	if hurt < 0.5 and tac != "cover" and tac != "peek" and tac_t <= 0.0 and randf() < 0.5:
		var c = _find_cover(pp)
		if c != null:
			cover = c
			tac = "cover"
			tac_t = randf_range(5.0, 8.0)
	match tac:
		"cover":
			if global_position.distance_to(cover) > 0.8:
				spd = _move_to(cover, speed * 1.1 * leg, d)
				# shoot back on the way if it can
				aim = sees and dist < 26.0
			else:
				_face(pp, d)
				hp = minf(hp_max, hp + hp_max * 0.03 * d)   # catching its breath behind the wall
				if tac_t <= 2.5 or (tac_t <= 4.0 and randf() < d):
					tac = "peek"
					tac_t = randf_range(2.0, 3.5)
					burst = 3
			if tac_t <= 0.0:
				tac = "strafe"
		"peek":
			# step out sideways until it can see you, empty a burst, then back
			if not sees:
				spd = _move_to(cover + side * strafe * 2.0, speed * leg, d)
			else:
				_face(pp, d)
				aim = true
			if tac_t <= 0.0 or burst <= 0:
				tac = "cover" if hurt < 0.5 else "strafe"
				tac_t = randf_range(2.5, 4.0)
		_:
			if not sees or dist > want_hi:
				tac = "advance"
				spd = _move_to(pp, speed * leg, d)
				aim = sees and dist < 26.0
			elif dist < want_lo:
				# too close for comfort: give ground while shooting
				spd = _move_to(global_position - dirv * 3.0 + side * strafe, speed * 0.85 * leg, d)
				aim = true
			else:
				if tac != "strafe" or tac_t <= 0.0:
					tac = "strafe"
					tac_t = randf_range(1.2, 2.8)
					strafe = -strafe if randf() < 0.7 else strafe
				var sgoal := global_position + side * strafe * 2.0
				if can_see(pp, sgoal):
					spd = _move_to(sgoal, speed * 0.55 * leg, d)
				else:
					strafe = -strafe
				aim = true
			if spd < 0.5:
				_face(pp, d)
	if aim and sees and dist < 28.0:
		face_yaw = lerp_angle(face_yaw, atan2(to.x, to.z), 1.0 - exp(-10.0 * d))
		# it takes a moment to find you, then fires in bursts
		if atk_cd <= 0.0 and seen_t > 0.35:
			if burst <= 0:
				burst = 2 + randi() % 2
			burst -= 1
			atk_cd = 0.35 if burst > 0 else randf_range(1.5, 2.3)
			_attack(dist, spd)
	return [spd, aim]

# somewhere 4-12 m away that a wall or a rock hides from you
func _find_cover(pp: Vector3) -> Variant:
	var best = null
	var bd := 1e9
	for i in 10:
		var a := randf() * TAU
		var r := randf_range(4.0, 12.0)
		var c := global_position + Vector3(cos(a), 0, sin(a)) * r
		c.y = Game.height(c.x, c.z)
		if c.distance_to(pp) < 6.0 or absf(c.y - global_position.y) > 2.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(pp + Vector3.UP * 1.5, c + Vector3.UP * 1.0, 1)
		q.exclude = [get_rid(), Game.player.get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		var sc := c.distance_to(global_position) - c.distance_to(pp) * 0.3
		if sc < bd:
			bd = sc
			best = c
	return best

func _deal(amount: float) -> void:
	if foe and is_instance_valid(foe):
		foe.hurt(amount)
	else:
		if Game.main and Game.main.hud:
			Game.main.hud.hurt_from(global_position + Vector3.UP * 1.2)
		Game.hurt(amount)
	if not ranged:
		Sfx.play_at("o_bark2" if quad else "x_flesh1", global_position + Vector3.UP, 0.0, randf_range(0.9, 1.1))

func _one_shot(anim: String, dur: float) -> void:
	if ap == null:
		return
	ap.play(anim, 0.06)
	ap.seek(0.0, true)
	act_t = dur

func _face(p: Vector3, d: float) -> void:
	var to := p - global_position
	face_yaw = lerp_angle(face_yaw, atan2(to.x, to.z), 1.0 - exp(-8.0 * d))

func _move_to(p: Vector3, spd: float, d: float) -> float:
	var next := p
	if Game.nav_ready:
		repath -= d
		if repath <= 0.0:
			agent.target_position = p
			repath = 0.4
		if not agent.is_navigation_finished():
			next = agent.get_next_path_position()
	var to := next - global_position
	to.y = 0
	if to.length() < 0.05:
		return 0.0
	var v := to.normalized() * spd
	# keep a little room between pack members
	for e in Game.main.enemies:
		if e != self and is_instance_valid(e) and not e.dead:
			var aw: Vector3 = global_position - e.global_position
			aw.y = 0.0
			var l := aw.length()
			if l < 1.7 and l > 0.01:
				v += aw / l * (1.7 - l) * spd * 1.6
	velocity.x = lerpf(velocity.x, v.x, 1.0 - exp(-8.0 * d))
	velocity.z = lerpf(velocity.z, v.z, 1.0 - exp(-8.0 * d))
	face_yaw = lerp_angle(face_yaw, atan2(v.x, v.z), 1.0 - exp(-8.0 * d))
	return Vector2(velocity.x, velocity.z).length()

func _attack(dist: float, moving := 0.0) -> void:
	_one_shot("Pistol_Shoot", 0.3)
	Sfx.play_at("pistol_far" if dist > 14.0 else "pistol", global_position + Vector3.UP * 1.4, -2.0, randf_range(0.9, 1.05))
	var tp: Vector3 = (foe.global_position if foe else Game.player.global_position) + Vector3.UP * 1.3
	var miss := 1.5
	# harder to hit you when you're moving fast, and it shoots worse on the move
	var pv: Vector3 = Game.player.velocity if not foe else Vector3.ZERO
	var you_move := clampf(Vector2(pv.x, pv.z).length() / 6.0, 0.0, 1.0)
	var chance := clampf(0.78 - dist * 0.02, 0.22, 0.78) * (0.6 if crip.has("arms") else 1.0) * (1.0 - you_move * 0.35) * (0.8 if moving > 0.5 else 1.0)
	var hit_it := randf() < chance
	Game.main.tracer(global_position + Vector3.UP * 1.4 + Vector3(sin(face_yaw), 0, cos(face_yaw)) * 0.5, tp + (Vector3.ZERO if hit_it else Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * miss * 2.0))
	if hit_it:
		_deal(dmg * randf_range(0.7, 1.1))
