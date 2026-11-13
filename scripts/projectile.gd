extends Node2D
class_name Projectile

## Projetil do golpe especial: anda em linha reta, acerta uma vez e some.

const TRAIL_STEPS := 6
const WALL_LEFT := 40.0
const WALL_RIGHT := 1240.0
const SPARK_TIME := 0.16
const TEXTURE_PATH := "res://assets/effects/picanha.png"
const OLD_TEXTURE_PATH := "res://assets/effects/projetil_especial.png"
const SPIN_SPEED := 7.5

var speed := 620.0
var radius := 22.0
var lifetime := 1.6
var color := Color(0.45, 0.82, 1.0)
var direction := 1
var attack: Dictionary = {}
var shooter
var target
var texture: Texture2D

var _elapsed := 0.0

func setup(from, atk: Dictionary, dir: int) -> void:
	shooter = from
	target = from.opponent if from != null else null
	attack = atk.duplicate(true)
	direction = 1 if dir >= 0 else -1
	speed = float(atk.get("projectile_speed", speed))
	radius = float(atk.get("projectile_radius", radius))
	lifetime = float(atk.get("projectile_lifetime", lifetime))
	color = atk.get("projectile_color", color)
	var offset: Vector2 = atk.get("offset", Vector2(46, -66))
	if from != null:
		global_position = from.global_position + Vector2(direction * offset.x, offset.y)

func _ready() -> void:
	add_to_group("projectiles")
	if ResourceLoader.exists(TEXTURE_PATH):
		texture = load(TEXTURE_PATH)
	elif ResourceLoader.exists(OLD_TEXTURE_PATH):
		texture = load(OLD_TEXTURE_PATH)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	global_position.x += direction * speed * delta
	queue_redraw()
	if _check_hit():
		return
	if global_position.x <= WALL_LEFT or global_position.x >= WALL_RIGHT:
		queue_free()

func _check_hit() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.health <= 0 or target.is_invulnerable():
		return false
	var box := Rect2(global_position - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	var hurt: Rect2 = target.hurt_rect()
	if not box.intersects(hurt):
		return false
	var stop := float(attack.get("hitstop", 0.0))
	target.receive_hit(attack, direction)
	if shooter != null and is_instance_valid(shooter):
		shooter.add_special(shooter.SPECIAL_GAIN_HIT)
		if stop > 0.0:
			shooter.add_hitstop(stop)
	if stop > 0.0:
		target.add_hitstop(stop)
	_spawn_spark(box.intersection(hurt).get_center())
	queue_free()
	return true

func _draw() -> void:
	# Rastro de fogo azul: circulos que encolhem atras da picanha.
	for i in TRAIL_STEPS:
		var t := float(i + 1) / float(TRAIL_STEPS + 1)
		var back := -direction * (radius * 0.8 + float(i) * radius * 0.9)
		var wobble := sin(_elapsed * 18.0 + float(i) * 1.7) * radius * 0.18
		draw_circle(Vector2(back, wobble), radius * (1.05 - 0.55 * t), Color(color, 0.22 * (1.0 - t)))
		draw_circle(Vector2(back, wobble), radius * (0.55 - 0.28 * t), Color(0.9, 0.97, 1.0, 0.20 * (1.0 - t)))
	if texture != null:
		# Aura pulsante atras da carne.
		var pulse := 0.5 + 0.5 * sin(_elapsed * 16.0)
		draw_circle(Vector2.ZERO, radius * (1.7 + 0.25 * pulse), Color(0.20, 0.55, 1.0, 0.28))
		draw_circle(Vector2.ZERO, radius * (1.3 + 0.18 * pulse), Color(0.55, 0.85, 1.0, 0.32))
		draw_circle(Vector2.ZERO, radius * 0.9, Color(1.0, 1.0, 1.0, 0.16))
		# Picanha girando no ar, mantendo a proporcao da textura.
		var side := radius * 3.6
		var aspect := float(texture.get_width()) / float(texture.get_height())
		var w := side * aspect
		var h := side
		draw_set_transform(Vector2.ZERO, _elapsed * SPIN_SPEED * direction, Vector2.ONE)
		draw_texture_rect(texture, Rect2(-w * 0.5, -h * 0.5, w, h), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_circle(Vector2.ZERO, radius, Color(color, 0.85))
	draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 1.0, 1.0, 0.95))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.85), 2.5)

func _spawn_spark(point: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var spark := Polygon2D.new()
	spark.polygon = PackedVector2Array([
		Vector2(18, 0), Vector2(5.4, 5.4), Vector2(0, 18), Vector2(-5.4, 5.4),
		Vector2(-18, 0), Vector2(-5.4, -5.4), Vector2(0, -18), Vector2(5.4, -5.4),
	])
	spark.color = Color(1.0, 0.97, 0.8)
	parent.add_child(spark)
	spark.global_position = point
	spark.scale = Vector2(0.8, 0.8)
	var tween := spark.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "scale", Vector2(2.0, 2.0), SPARK_TIME)
	tween.tween_property(spark, "modulate:a", 0.0, SPARK_TIME)
	tween.chain().tween_callback(spark.queue_free)
