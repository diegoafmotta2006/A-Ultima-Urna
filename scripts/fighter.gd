extends CharacterBody2D
class_name Fighter

## Lutador com máquina de estados simples e dados de ataque em frames de tempo.
## Sem sprites ainda: o corpo é desenhado com polígonos para o protótipo rodar.

signal health_changed(current: int, maximum: int)
signal defeated(fighter: Fighter)

const GRAVITY := 2000.0
const WALK_SPEED := 250.0
const JUMP_VELOCITY := -780.0
const MAX_HEALTH := 100
const BODY_HALF_WIDTH := 23.0
const BODY_HEIGHT := 112.0

enum State { IDLE, WALK, JUMP, ATTACK, HIT, KO }

## Tempos em segundos (60 fps). Depois você pode converter para frames reais.
const ATTACKS := {
	"light": {
		"startup": 0.055,
		"active": 0.070,
		"recovery": 0.130,
		"damage": 6,
		"box": Vector2(64, 34),
		"offset": Vector2(42, -62),
		"knock": Vector2(170, -60),
		"hitstun": 0.22,
	},
	"heavy": {
		"startup": 0.140,
		"active": 0.090,
		"recovery": 0.280,
		"damage": 14,
		"box": Vector2(100, 46),
		"offset": Vector2(64, -66),
		"knock": Vector2(340, -150),
		"hitstun": 0.38,
	},
}

@export var player_id := 1
@export var ai_enabled := false
@export var body_color := Color(0.85, 0.28, 0.30)

var state: State = State.IDLE
var health := MAX_HEALTH
var facing := 1
var opponent: Fighter

var _attack: Dictionary = {}
var _attack_elapsed := 0.0
var _attack_hit := false
var _hitstun := 0.0
var _move_dir := 0.0

var _prev_light := false
var _prev_heavy := false
var _prev_jump := false

var _ai_attack_cd := 0.0

@onready var _body: Node2D = $Body
@onready var _torso: Polygon2D = $Body/Torso

func _ready() -> void:
	_torso.color = body_color
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
	_move_dir = 0.0
	_ai_attack_cd = 0.0
	set_health(MAX_HEALTH)

func update_facing() -> void:
	if opponent == null:
		return
	if state == State.ATTACK or state == State.HIT or state == State.KO:
		return
	facing = 1 if opponent.global_position.x >= global_position.x else -1
	_body.scale.x = facing

func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-BODY_HALF_WIDTH, -BODY_HEIGHT), Vector2(BODY_HALF_WIDTH * 2.0, BODY_HEIGHT))

func _physics_process(delta: float) -> void:
	var move := 0.0
	var jump_edge := false
	var light_edge := false
	var heavy_edge := false

	if ai_enabled:
		var ai := _ai_input(delta)
		move = ai.move
		jump_edge = ai.jump
		light_edge = ai.light
		heavy_edge = ai.heavy
	else:
		var left := InputBridge.held(player_id, "left")
		var right := InputBridge.held(player_id, "right")
		move = (1.0 if right else 0.0) - (1.0 if left else 0.0)
		var jump_now := InputBridge.held(player_id, "jump")
		var light_now := InputBridge.held(player_id, "light")
		var heavy_now := InputBridge.held(player_id, "heavy")
		jump_edge = jump_now and not _prev_jump
		light_edge = light_now and not _prev_light
		heavy_edge = heavy_now and not _prev_heavy
		_prev_jump = jump_now
		_prev_light = light_now
		_prev_heavy = heavy_now

	_move_dir = move

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match state:
		State.KO:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			move_and_slide()
			return
		State.HIT:
			_hitstun -= delta
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			if _hitstun <= 0.0 and is_on_floor():
				state = State.IDLE
			move_and_slide()
			return
		State.ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, 2800.0 * delta)
			_advance_attack(delta)
			move_and_slide()
			return
		_:
			pass

	var grounded := is_on_floor()

	if grounded and jump_edge:
		velocity.y = JUMP_VELOCITY
		velocity.x = move * WALK_SPEED
		state = State.JUMP
	elif grounded and (light_edge or heavy_edge):
		_start_attack("heavy" if heavy_edge else "light")
	else:
		velocity.x = move * WALK_SPEED
		if grounded:
			state = State.WALK if absf(move) > 0.01 else State.IDLE
		else:
			state = State.JUMP

	move_and_slide()

func _start_attack(name: String) -> void:
	if not ATTACKS.has(name):
		return
	_attack = ATTACKS[name].duplicate()
	_attack_elapsed = 0.0
	_attack_hit = false
	state = State.ATTACK
	velocity.x = 0.0

func _advance_attack(delta: float) -> void:
	_attack_elapsed += delta
	var startup: float = _attack.startup
	var active: float = _attack.active
	var total: float = startup + active + _attack.recovery
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
	if _attack_rect().intersects(opponent.hurt_rect()):
		_attack_hit = true
		var knock := Vector2(facing * _attack.knock.x, _attack.knock.y)
		opponent.receive_hit(_attack.damage, knock, _attack.hitstun)

func receive_hit(damage: int, knock: Vector2, hitstun: float) -> void:
	if state == State.KO:
		return
	if _is_blocking():
		damage = maxi(1, int(round(damage * 0.25)))
		knock.x *= 0.35
		hitstun *= 0.6
	set_health(health - damage)
	velocity.x = knock.x
	velocity.y = knock.y
	_hitstun = hitstun
	if health <= 0:
		state = State.KO
		defeated.emit(self)
	else:
		state = State.HIT

func _is_blocking() -> bool:
	if state == State.ATTACK or not is_on_floor():
		return false
	return _move_dir != 0.0 and signf(_move_dir) == -signf(facing)

func _ai_input(delta: float) -> Dictionary:
	_ai_attack_cd = maxf(0.0, _ai_attack_cd - delta)
	var out := {"move": 0.0, "jump": false, "light": false, "heavy": false}
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
		if randf() < 0.5:
			if randf() < 0.72:
				out.light = true
			else:
				out.heavy = true
			_ai_attack_cd = randf_range(0.45, 0.95)
	return out
