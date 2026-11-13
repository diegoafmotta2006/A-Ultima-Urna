extends Node2D

const INK := Color(0.07, 0.08, 0.12)
const SKIN := Color(0.96, 0.79, 0.64)
const HAIR := Color(0.12, 0.10, 0.15)
const LEG_COLOR := Color(0.16, 0.17, 0.23)
const STROKE := 5.5
const BONE_WIDTH := 11.0

const SHOULDER := Vector2(0, -84)
const HIP := Vector2(0, -48)
const UPPER_ARM := 22.0
const FOREARM := 20.0
const THIGH := 24.0
const SHIN := 24.0

var _primary := Color(0.85, 0.28, 0.30)

const ART_TARGET_HEIGHT := 112.0
const ART_POSES := ["idle", "walk", "jump", "light", "heavy", "launcher", "special", "hit", "block", "knockdown", "ko"]

var _art: Dictionary = {}
var _sprite: Sprite2D
var _art_scale := 1.0
var _use_art := false
var _current_pose := ""

var _rig: Node2D
var _torso: Polygon2D
var _head_pivot: Node2D

var _arm_f_upper: Node2D
var _arm_f_lower: Node2D
var _arm_b_upper: Node2D
var _arm_b_lower: Node2D
var _leg_f_upper: Node2D
var _leg_f_lower: Node2D
var _leg_b_upper: Node2D
var _leg_b_lower: Node2D

var _t := 0.0

func _ready() -> void:
	_rig = Node2D.new()
	_rig.name = "Rig"
	add_child(_rig)

	_leg_b_upper = _bone(_rig, HIP + Vector2(-3, 0), THIGH, BONE_WIDTH, LEG_COLOR, -6)
	_leg_b_lower = _bone(_leg_b_upper, Vector2(THIGH, 0), SHIN, BONE_WIDTH * 0.9, LEG_COLOR, 0)
	_foot(_leg_b_lower, Vector2(SHIN, 0), LEG_COLOR, -6)

	_arm_b_upper = _bone(_rig, SHOULDER + Vector2(-3, 0), UPPER_ARM, BONE_WIDTH * 0.8, SKIN, -4)
	_arm_b_lower = _bone(_arm_b_upper, Vector2(UPPER_ARM, 0), FOREARM, BONE_WIDTH * 0.72, SKIN, 0)
	_hand(_arm_b_lower, Vector2(FOREARM, 0), 5.5, SKIN, -4)

	_torso = _poly(_rig, PackedVector2Array([
		Vector2(-15, -48), Vector2(15, -48), Vector2(19, -84), Vector2(-19, -84),
	]), _primary, 0)
	_poly(_rig, PackedVector2Array([
		Vector2(-16, -51), Vector2(16, -51), Vector2(16, -44), Vector2(-16, -44),
	]), INK, 1)

	_leg_f_upper = _bone(_rig, HIP + Vector2(3, 0), THIGH, BONE_WIDTH, LEG_COLOR, 2)
	_leg_f_lower = _bone(_leg_f_upper, Vector2(THIGH, 0), SHIN, BONE_WIDTH * 0.9, LEG_COLOR, 0)
	_foot(_leg_f_lower, Vector2(SHIN, 0), LEG_COLOR, 2)

	_head_pivot = Node2D.new()
	_head_pivot.name = "Head"
	_head_pivot.position = Vector2(0, -96)
	_head_pivot.z_index = 3
	_rig.add_child(_head_pivot)
	_poly(_head_pivot, _circle(13.0), SKIN, 0)
	_poly(_head_pivot, PackedVector2Array([
		Vector2(-13, -2), Vector2(13, -2), Vector2(11, -10), Vector2(0, -14), Vector2(-11, -10),
	]), HAIR, 1)
	_poly(_head_pivot, _circle(2.0), INK, 2)

	_arm_f_upper = _bone(_rig, SHOULDER + Vector2(3, 0), UPPER_ARM, BONE_WIDTH * 0.8, SKIN, 4)
	_arm_f_lower = _bone(_arm_f_upper, Vector2(UPPER_ARM, 0), FOREARM, BONE_WIDTH * 0.72, SKIN, 0)
	_hand(_arm_f_lower, Vector2(FOREARM, 0), 5.5, SKIN, 4)

	set_primary_color(_primary)

func set_primary_color(color: Color) -> void:
	_primary = color
	if _torso != null:
		_torso.color = color

## Troca o rig de poligonos pela arte recortada em assets/characters/<set>/.
func set_art(set_name: String) -> void:
	if set_name.is_empty():
		return
	_art.clear()
	for pose in ART_POSES:
		var path := "res://assets/characters/%s/%s.png" % [set_name, pose]
		if ResourceLoader.exists(path):
			_art[pose] = load(path)
	if not _art.has("idle"):
		push_warning("CharacterVisual: arte '%s' sem idle.png" % set_name)
		return
	_use_art = true
	if _rig != null:
		_rig.visible = false
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
	_current_pose = ""
	_sprite = Sprite2D.new()
	_sprite.name = "Art"
	_sprite.centered = false
	add_child(_sprite)
	var idle_tex: Texture2D = _art["idle"]
	_art_scale = ART_TARGET_HEIGHT / float(idle_tex.get_height())
	_apply_pose("idle")

func _apply_pose(pose_name: String) -> void:
	if not _use_art or _sprite == null:
		return
	if pose_name == _current_pose:
		return
	var tex: Texture2D = _art.get(pose_name, _art["idle"])
	_sprite.texture = tex
	_sprite.scale = Vector2(_art_scale, _art_scale)
	_sprite.offset = Vector2(-float(tex.get_width()) * 0.5, -float(tex.get_height()))
	_current_pose = pose_name

func _pose_art(f: Fighter) -> void:
	var p := "idle"
	match f.state:
		Fighter.State.IDLE:
			p = "idle"
		Fighter.State.WALK:
			p = "walk"
		Fighter.State.JUMP:
			p = "jump"
		Fighter.State.ATTACK:
			match f._attack_name:
				"heavy", "air_heavy":
					p = "heavy"
				"launcher":
					p = "launcher"
				"special":
					p = "special" if _art.has("special") else "heavy"
				_:
					p = "light"
		Fighter.State.HIT:
			p = "block" if f._blocked_pose else "hit"
		Fighter.State.AIR_HIT, Fighter.State.WALL_SPLAT:
			p = "hit"
		Fighter.State.KNOCKDOWN, Fighter.State.GETUP:
			p = "knockdown"
		Fighter.State.KO:
			p = "ko"
	_apply_pose(p)

func _process(delta: float) -> void:
	_t += delta
	var f := get_parent() as Fighter
	if f == null:
		return
	if _use_art:
		_pose_art(f)
		return
	if _rig == null:
		return
	_pose(f, delta)

func _pose(f: Fighter, delta: float) -> void:
	var arm_f_up := deg_to_rad(72.0)
	var arm_f_lo := deg_to_rad(14.0)
	var arm_b_up := deg_to_rad(82.0)
	var arm_b_lo := deg_to_rad(8.0)
	var leg_f_up := deg_to_rad(92.0)
	var leg_f_lo := deg_to_rad(-3.0)
	var leg_b_up := deg_to_rad(88.0)
	var leg_b_lo := deg_to_rad(3.0)
	var rig_rot := 0.0
	var rig_y := 0.0
	var head_rot := 0.0

	match f.state:
		Fighter.State.IDLE:
			var breath := sin(_t * 2.4)
			arm_f_up += deg_to_rad(2.5 * breath)
			arm_b_up -= deg_to_rad(2.5 * breath)
			rig_y = -1.2 * (0.5 + 0.5 * breath)
		Fighter.State.WALK:
			var swing := sin(_t * 10.0) * deg_to_rad(24.0)
			leg_f_up += swing
			leg_b_up -= swing
			leg_f_lo = -absf(swing) * 0.6
			leg_b_lo = -absf(swing) * 0.6
			arm_f_up -= swing * 0.7
			arm_b_up += swing * 0.7
			rig_y = -absf(sin(_t * 10.0)) * 1.5
		Fighter.State.JUMP:
			leg_f_up = deg_to_rad(64.0)
			leg_f_lo = deg_to_rad(-70.0)
			leg_b_up = deg_to_rad(112.0)
			leg_b_lo = deg_to_rad(-45.0)
			arm_f_up = deg_to_rad(-40.0)
			arm_b_up = deg_to_rad(-25.0)
			arm_f_lo = deg_to_rad(-15.0)
			arm_b_lo = deg_to_rad(-10.0)
		Fighter.State.ATTACK:
			var atk: Dictionary = f._attack
			if not atk.is_empty():
				var startup: float = maxf(float(atk.get("startup", 0.05)), 0.0001)
				var active: float = maxf(float(atk.get("active", 0.06)), 0.0001)
				var recovery: float = maxf(float(atk.get("recovery", 0.1)), 0.0001)
				var elapsed: float = float(f._attack_elapsed)
				var is_launcher: bool = bool(atk.get("launcher", false))
				var windup := deg_to_rad(128.0)
				var strike := deg_to_rad(-58.0) if is_launcher else deg_to_rad(18.0)
				if elapsed < startup:
					var tw := elapsed / startup
					arm_f_up = lerp_angle(deg_to_rad(72.0), windup, tw)
					arm_f_lo = lerp_angle(deg_to_rad(14.0), deg_to_rad(-38.0), tw)
					rig_rot = deg_to_rad(-4.0)
				elif elapsed < startup + active:
					var ta := clampf((elapsed - startup) / (active * 0.35), 0.0, 1.0)
					arm_f_up = lerp_angle(windup, strike, ta)
					arm_f_lo = lerp_angle(deg_to_rad(-38.0), 0.0, ta)
					rig_rot = deg_to_rad(-8.0) * ta if is_launcher else deg_to_rad(6.0) * ta
				else:
					var tr := clampf((elapsed - startup - active) / recovery, 0.0, 1.0)
					arm_f_up = lerp_angle(strike, deg_to_rad(72.0), tr)
					arm_f_lo = lerp_angle(0.0, deg_to_rad(14.0), tr)
				arm_b_up = deg_to_rad(100.0)
				rig_y = -2.0
				leg_f_up = deg_to_rad(96.0)
				leg_b_up = deg_to_rad(84.0)
		Fighter.State.HIT:
			arm_f_up = deg_to_rad(150.0)
			arm_f_lo = deg_to_rad(10.0)
			arm_b_up = deg_to_rad(160.0)
			arm_b_lo = deg_to_rad(10.0)
			rig_rot = deg_to_rad(-12.0)
			head_rot = deg_to_rad(-8.0)
			leg_f_up = deg_to_rad(100.0)
			leg_b_up = deg_to_rad(80.0)
		Fighter.State.AIR_HIT:
			arm_f_up = deg_to_rad(-55.0)
			arm_b_up = deg_to_rad(-75.0)
			leg_f_up = deg_to_rad(55.0)
			leg_f_lo = deg_to_rad(-65.0)
			leg_b_up = deg_to_rad(125.0)
			leg_b_lo = deg_to_rad(-40.0)
			rig_rot = deg_to_rad(-6.0)
		Fighter.State.WALL_SPLAT:
			arm_f_up = deg_to_rad(-30.0)
			arm_b_up = deg_to_rad(-45.0)
			leg_f_up = deg_to_rad(95.0)
			leg_b_up = deg_to_rad(85.0)
			rig_rot = deg_to_rad(-8.0)
		Fighter.State.KNOCKDOWN:
			rig_rot = deg_to_rad(-80.0)
			rig_y = -4.0
			arm_f_up = deg_to_rad(140.0)
			arm_b_up = deg_to_rad(150.0)
		Fighter.State.GETUP:
			var tg := clampf(1.0 - f._getup_timer / FightPhysics.GETUP_TIME, 0.0, 1.0)
			rig_rot = deg_to_rad(-80.0) * (1.0 - tg)
			arm_f_up = lerp_angle(deg_to_rad(140.0), deg_to_rad(72.0), tg)
			arm_b_up = lerp_angle(deg_to_rad(150.0), deg_to_rad(82.0), tg)
		Fighter.State.KO:
			rig_rot = deg_to_rad(-86.0)
			rig_y = -6.0
			arm_f_up = deg_to_rad(135.0)
			arm_b_up = deg_to_rad(155.0)
			leg_f_up = deg_to_rad(100.0)
			leg_b_up = deg_to_rad(80.0)

	_smooth_rot(_arm_f_upper, arm_f_up, delta)
	_smooth_rot(_arm_f_lower, arm_f_lo, delta)
	_smooth_rot(_arm_b_upper, arm_b_up, delta)
	_smooth_rot(_arm_b_lower, arm_b_lo, delta)
	_smooth_rot(_leg_f_upper, leg_f_up, delta)
	_smooth_rot(_leg_f_lower, leg_f_lo, delta)
	_smooth_rot(_leg_b_upper, leg_b_up, delta)
	_smooth_rot(_leg_b_lower, leg_b_lo, delta)
	_smooth_rot(_rig, rig_rot, delta)
	_smooth_rot(_head_pivot, head_rot, delta)
	_rig.position.y = lerpf(_rig.position.y, rig_y, clampf(delta * 14.0, 0.0, 1.0))

func _smooth_rot(node: Node2D, target: float, delta: float) -> void:
	if node == null:
		return
	node.rotation = lerp_angle(node.rotation, target, clampf(delta * 18.0, 0.0, 1.0))

func _bone(parent: Node2D, joint: Vector2, length: float, width: float, color: Color, z: int) -> Node2D:
	var pivot := Node2D.new()
	pivot.position = joint
	pivot.z_index = z
	parent.add_child(pivot)
	_stroke(pivot, PackedVector2Array([Vector2.ZERO, Vector2(length, 0)]), width, color, 0)
	return pivot

func _hand(parent: Node2D, at: Vector2, radius: float, color: Color, z: int) -> void:
	var holder := Node2D.new()
	holder.position = at
	holder.z_index = z
	parent.add_child(holder)
	_poly(holder, _circle(radius), color, 0)

func _foot(parent: Node2D, at: Vector2, color: Color, z: int) -> void:
	var holder := Node2D.new()
	holder.position = at
	holder.z_index = z
	parent.add_child(holder)
	_stroke(holder, PackedVector2Array([Vector2(-3, 0), Vector2(9, 0)]), 7.0, color, 0)

func _stroke(parent: Node2D, points: PackedVector2Array, width: float, color: Color, z: int) -> void:
	var outline := Line2D.new()
	outline.points = points
	outline.width = width + STROKE
	outline.default_color = INK
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.antialiased = true
	outline.z_index = z
	parent.add_child(outline)

	var fill := Line2D.new()
	fill.points = points
	fill.width = width
	fill.default_color = color
	fill.begin_cap_mode = Line2D.LINE_CAP_ROUND
	fill.end_cap_mode = Line2D.LINE_CAP_ROUND
	fill.joint_mode = Line2D.LINE_JOINT_ROUND
	fill.antialiased = true
	fill.z_index = z + 1
	parent.add_child(fill)

func _poly(parent: Node2D, points: PackedVector2Array, color: Color, z: int) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	poly.z_index = z
	parent.add_child(poly)

	var loop := points.duplicate()
	loop.append(points[0])
	var outline := Line2D.new()
	outline.points = loop
	outline.width = STROKE
	outline.default_color = INK
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.antialiased = true
	outline.z_index = z + 1
	parent.add_child(outline)
	return poly

func _circle(radius: float, segments := 28) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		points.append(Vector2(cos(a), sin(a)) * radius)
	return points
