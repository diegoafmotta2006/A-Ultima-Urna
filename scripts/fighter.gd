extends CharacterBody2D
class_name Fighter

## Lutador com maquina de estados e fisica hibrida:
##  - base 2D do Street Fighter vs SNK (MUGEN): caminhada, pulo, hitstop,
##    knockback, hitstun, blockstun e corner push medidos em fight_physics.gd;
##  - camada de Tekken: launcher, juggle com dano decrescente, wall splat,
##    queda (knockdown) e levantada (Rising) com invulnerabilidade.
## Sem sprites ainda: o corpo e desenhado com poligonos para o prototipo rodar.

signal health_changed(current: int, maximum: int)
signal defeated(fighter: Fighter)

const GRAVITY := FightPhysics.GRAVITY
const WALK_SPEED := FightPhysics.WALK_FWD
const WALK_BACK_SPEED := FightPhysics.WALK_BACK
const JUMP_VELOCITY := FightPhysics.JUMP_VY
const JUMP_FWD_SPEED := FightPhysics.JUMP_FWD
const JUMP_BACK_SPEED := FightPhysics.JUMP_BACK
const MAX_HEALTH := 100
const BODY_HALF_WIDTH := 23.0
const BODY_HEIGHT := 112.0

## Feedback de impacto: congelamento, flash e faisca (sem assets).
const HIT_FLASH_TIME := 0.14
const HIT_FLASH_COLOR := Color(2.4, 2.4, 2.4)
const BLOCK_FLASH_COLOR := Color(0.8, 1.7, 2.2)
const HIT_SPARK_COLOR := Color(1.0, 0.95, 0.62)
const BLOCK_SPARK_COLOR := Color(0.62, 0.86, 1.0)
const SPARK_TIME := 0.16
static var SPARK_SHAPE := PackedVector2Array([
	Vector2(14, 0), Vector2(4.4, 4.4), Vector2(0, 14), Vector2(-4.4, 4.4),
	Vector2(-14, 0), Vector2(-4.4, -4.4), Vector2(0, -14), Vector2(4.4, -4.4),
])

enum State { IDLE, WALK, JUMP, ATTACK, HIT, KO, AIR_HIT, WALL_SPLAT, KNOCKDOWN, GETUP }

@export var player_id := 1
@export var ai_enabled := false
@export var body_color := Color(0.85, 0.28, 0.30)
## Peso do Tekken: leve (<1) voa mais alto, pesado (>1) cai antes.
@export_range(0.75, 1.35, 0.01) var weight := 1.0

var state: State = State.IDLE
var health := MAX_HEALTH
var facing := 1
var opponent: Fighter
var juggle_count := 0

var _attack: Dictionary = {}
var _attack_elapsed := 0.0
var _attack_hit := false
var _hitstun := 0.0
var _hitstop := 0.0
var _invuln := 0.0
var _move_dir := 0.0
var _down_held := false
var _flash_tween: Tween

var _wall_timer := 0.0
var _knockdown_timer := 0.0
var _getup_timer := 0.0

var _prev_light := false
var _prev_heavy := false
var _prev_jump := false

var _jump_edge := false
var _light_edge := false
var _heavy_edge := false
var _launcher_edge := false

var _ai_attack_cd := 0.0

@onready var _body: Node2D = $Body
@onready var _torso: Polygon2D = $Body/Torso

func _ready() -> void:
	weight = clampf(weight, 0.75, 1.35)
	_torso.color = body_color
	_body.modulate = Color.WHITE
	set_health(MAX_HEALTH)

func set_health(value: int) -> void:
	health = clampi(value, 0, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)

func reset_for_round(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	state = State.IDLE
	_attack = {}
	_attack_elapsed = 0.0
	_attack_hit = false
	_hitstun = 0.0
	_hitstop = 0.0
	_invuln = 0.0
	_move_dir = 0.0
	_down_held = false
	juggle_count = 0
	_wall_timer = 0.0
	_knockdown_timer = 0.0
	_getup_timer = 0.0
	_ai_attack_cd = 0.0
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_body.modulate = Color.WHITE
	set_health(MAX_HEALTH)

func update_facing() -> void:
	if opponent == null:
		return
	if state in [State.ATTACK, State.HIT, State.KO, State.AIR_HIT, State.WALL_SPLAT, State.KNOCKDOWN, State.GETUP]:
		return
	facing = 1 if opponent.global_position.x >= global_position.x else -1
	_body.scale.x = facing

func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-BODY_HALF_WIDTH, -BODY_HEIGHT), Vector2(BODY_HALF_WIDTH * 2.0, BODY_HEIGHT))

func is_invulnerable() -> bool:
	return _invuln > 0.0

func is_airborne() -> bool:
	return state in [State.AIR_HIT, State.WALL_SPLAT, State.KNOCKDOWN]

func _physics_process(delta: float) -> void:
	if _hitstop > 0.0:
		_hitstop -= delta
		return

	if _invuln > 0.0:
		_invuln -= delta

	_read_input()

	match state:
		State.KO:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			move_and_slide()
			return

		State.WALL_SPLAT:
			_wall_timer -= delta
			velocity.x = 0.0
			velocity.y = FightPhysics.WALL_SLIDE
			move_and_slide()
			if _wall_timer <= 0.0 or is_on_floor():
				_enter_knockdown()
			return

		State.KNOCKDOWN:
			_knockdown_timer -= delta
			velocity.x = 0.0
			if is_on_floor():
				velocity.y = 0.0
			else:
				velocity.y += GRAVITY * delta
			move_and_slide()
			if _knockdown_timer <= 0.0 and is_on_floor():
				_enter_getup()
			return

		State.GETUP:
			_getup_timer -= delta
			velocity.x = 0.0
			if is_on_floor():
				velocity.y = 0.0
			else:
				velocity.y += GRAVITY * delta
			move_and_slide()
			if _getup_timer <= 0.0:
				state = State.IDLE
			return

		State.HIT:
			_hitstun -= delta
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			velocity.x *= pow(FightPhysics.GROUND_FRICTION, 60.0 * delta)
			move_and_slide()
			if _hitstun <= 0.0 and is_on_floor():
				state = State.IDLE
			return

		State.AIR_HIT:
			velocity.y += FightPhysics.JUGGLE_GRAVITY * delta
			velocity.x *= pow(1.0 - FightPhysics.AIR_DRAG, 60.0 * delta)
			var vx_before := velocity.x
			move_and_slide()
			if is_on_wall() and absf(vx_before) >= FightPhysics.WALL_SPLAT_SPEED:
				_enter_wall_splat()
			elif is_on_floor():
				_enter_knockdown()
			return

		State.ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, 2800.0 * delta)
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			_advance_attack(delta)
			move_and_slide()
			return

		_:
			pass

	# ---------------------------------------------------------- livre
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var grounded := is_on_floor()

	if grounded and _jump_edge:
		velocity.y = JUMP_VELOCITY
		velocity.x = _jump_horizontal()
		state = State.JUMP
	elif grounded and (_light_edge or _heavy_edge or _launcher_edge):
		if _launcher_edge:
			_start_attack("launcher")
		elif _heavy_edge:
			_start_attack("heavy")
		else:
			_start_attack("light")
	else:
		if grounded:
			_apply_walk_speed()
			state = State.WALK if absf(_move_dir) > 0.01 else State.IDLE
		else:
			state = State.JUMP

	move_and_slide()

func _apply_walk_speed() -> void:
	if absf(_move_dir) <= 0.01:
		velocity.x = 0.0
		return
	# Andar "para tras" usa a velocidade de walk.back medida no MUGEN.
	var going_back := signf(_move_dir) != float(facing)
	velocity.x = _move_dir * (WALK_BACK_SPEED if going_back else WALK_SPEED)

func _jump_horizontal() -> float:
	if absf(_move_dir) <= 0.01:
		return 0.0
	if signf(_move_dir) == float(facing):
		return float(facing) * JUMP_FWD_SPEED
	return float(facing) * JUMP_BACK_SPEED

func _start_attack(name: String) -> void:
	if not FightPhysics.ATTACKS.has(name):
		return
	_attack = FightPhysics.ATTACKS[name].duplicate(true)
	_attack_elapsed = 0.0
	_attack_hit = false
	state = State.ATTACK
	velocity.x = 0.0

func _advance_attack(delta: float) -> void:
	_attack_elapsed += delta
	var startup: float = _attack.startup
	var active: float = _attack.active
	var total: float = startup + active + float(_attack.recovery)
	var in_active := _attack_elapsed >= startup and _attack_elapsed < startup + active
	if in_active and not _attack_hit:
		_try_hit()
	if _attack_elapsed >= total:
		state = State.IDLE
		_attack = {}

func _attack_rect() -> Rect2:
	if _attack.is_empty():
		return Rect2()
	var center := global_position + Vector2(facing * _attack.offset.x, _attack.offset.y)
	var box: Vector2 = _attack.box
	return Rect2(center - box * 0.5, box)

func _try_hit() -> void:
	if opponent == null or opponent.state == State.KO:
		return
	var attack := _attack_rect()
	var hurt := opponent.hurt_rect()
	if not attack.intersects(hurt):
		return
	_attack_hit = true
	var blocked := opponent.is_blocking()
	opponent.receive_hit(_attack, facing)

	var stop: float = _attack.get("hitstop", 0.0)
	if stop > 0.0:
		add_hitstop(stop)
		opponent.add_hitstop(stop)

	# Corner push: se o oponente esta encurralado, quem recua e o atacante.
	if opponent.is_against_wall():
		velocity.x = -float(facing) * float(_attack.corner_push) * 0.5

	_spawn_spark(attack.intersection(hurt).get_center(), BLOCK_SPARK_COLOR if blocked else HIT_SPARK_COLOR)

func is_against_wall() -> bool:
	return global_position.x <= FightPhysics.CORNER_MARGIN or global_position.x >= 1280.0 - FightPhysics.CORNER_MARGIN

func add_hitstop(duration: float) -> void:
	_hitstop = maxf(_hitstop, duration)

## Aplica um HitDef. `from_facing` e a direcao de quem atacou.
func receive_hit(atk: Dictionary, from_facing: int) -> void:
	if state == State.KO or _invuln > 0.0:
		return

	var blocked := is_blocking()
	var damage: int = int(atk.damage)
	var w := maxf(weight, 0.75)

	if blocked:
		# Street Fighter: dano reduzido, blockstun e empurrao proprios.
		damage = maxi(1, int(round(damage * FightPhysics.CHIP_RATIO)))
		_hitstun = float(atk.blockstun)
		velocity = Vector2(from_facing * float(atk.guard_knock), 0.0)
		state = State.HIT
		_flash(BLOCK_FLASH_COLOR)
	else:
		var airborne := not is_on_floor() or state == State.AIR_HIT
		if airborne or bool(atk.launcher):
			# Tekken: launch + juggle com dano decrescente (damage_adjust_aircombo).
			juggle_count += 1
			var scale := pow(FightPhysics.JUGGLE_DAMAGE_DECAY, maxf(0.0, float(juggle_count - 1)))
			if juggle_count > int(FightPhysics.MAX_JUGGLE):
				scale *= 0.5
			damage = maxi(1, int(round(damage * scale)))
			var lift := float(atk.air_knock.y)
			if juggle_count > 1:
				lift *= 0.45
			lift *= pow(FightPhysics.JUGGLE_LIFT_DECAY, maxf(0.0, float(juggle_count - 1)))
			velocity.x = from_facing * absf(float(atk.air_knock.x)) / sqrt(w)
			velocity.y = lift / w
			_hitstun = float(atk.air_hitstun)
			state = State.AIR_HIT
			_flash(HIT_FLASH_COLOR)
		else:
			velocity = Vector2(from_facing * absf(float(atk.knock.x)) / w, 0.0)
			_hitstun = float(atk.hitstun)
			state = State.HIT
			_flash(HIT_FLASH_COLOR)

	set_health(health - damage)
	if health <= 0:
		state = State.KO
		defeated.emit(self)

func _enter_wall_splat() -> void:
	state = State.WALL_SPLAT
	_wall_timer = FightPhysics.WALL_SPLAT_TIME
	velocity = Vector2(0.0, FightPhysics.WALL_SLIDE)

func _enter_knockdown() -> void:
	state = State.KNOCKDOWN
	_knockdown_timer = FightPhysics.KNOCKDOWN_TIME
	juggle_count = 0
	velocity = Vector2.ZERO

func _enter_getup() -> void:
	state = State.GETUP
	_getup_timer = FightPhysics.GETUP_TIME
	_invuln = maxf(_invuln, FightPhysics.GETUP_INVULN)
	velocity = Vector2.ZERO

func is_blocking() -> bool:
	if state in [State.ATTACK, State.HIT, State.AIR_HIT, State.WALL_SPLAT, State.KNOCKDOWN, State.GETUP, State.KO]:
		return false
	if not is_on_floor():
		return false
	return absf(_move_dir) > 0.01 and signf(_move_dir) == -signf(float(facing))

func _read_input() -> void:
	var move := 0.0
	_jump_edge = false
	_light_edge = false
	_heavy_edge = false
	_launcher_edge = false

	if ai_enabled:
		var ai := _ai_input(get_physics_process_delta_time())
		move = ai.move
		_jump_edge = ai.jump
		_light_edge = ai.light
		_heavy_edge = ai.heavy
		_launcher_edge = ai.launcher
		_down_held = ai.down
	else:
		var left := InputBridge.held(player_id, "left")
		var right := InputBridge.held(player_id, "right")
		move = (1.0 if right else 0.0) - (1.0 if left else 0.0)
		_down_held = InputBridge.held(player_id, "down")
		var jump_now := InputBridge.held(player_id, "jump")
		var light_now := InputBridge.held(player_id, "light")
		var heavy_now := InputBridge.held(player_id, "heavy")
		_jump_edge = jump_now and not _prev_jump
		_light_edge = light_now and not _prev_light
		_heavy_edge = heavy_now and not _prev_heavy
		_launcher_edge = _heavy_edge and _down_held
		_prev_jump = jump_now
		_prev_light = light_now
		_prev_heavy = heavy_now

	_move_dir = move

func _flash(color: Color) -> void:
	_body.modulate = color
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_body, "modulate", Color.WHITE, HIT_FLASH_TIME).set_ease(Tween.EASE_OUT)

func _spawn_spark(point: Vector2, color: Color) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var spark := Polygon2D.new()
	spark.polygon = SPARK_SHAPE
	spark.color = color
	parent.add_child(spark)
	spark.global_position = point
	spark.scale = Vector2(0.7, 0.7)
	var tween := spark.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "scale", Vector2(1.9, 1.9), SPARK_TIME)
	tween.tween_property(spark, "modulate:a", 0.0, SPARK_TIME)
	tween.chain().tween_callback(spark.queue_free)

func _ai_input(delta: float) -> Dictionary:
	_ai_attack_cd = maxf(0.0, _ai_attack_cd - delta)
	var out := {"move": 0.0, "jump": false, "light": false, "heavy": false, "launcher": false, "down": false}
	if opponent == null or opponent.state == State.KO:
		return out
	var dx := opponent.global_position.x - global_position.x
	var dist := absf(dx)
	var to_opp := signf(dx)
	if dist > 150.0:
		out.move = to_opp
		if is_on_floor() and randf() < 0.008:
			out.jump = true
	elif dist < 64.0:
		out.move = -to_opp
	elif _ai_attack_cd <= 0.0 and is_on_floor():
		if opponent.is_airborne() and randf() < 0.45:
			out.launcher = true
		elif randf() < 0.5:
			if randf() < 0.72:
				out.light = true
			else:
				out.heavy = true
		_ai_attack_cd = randf_range(0.45, 0.95)
	return out
