extends Node2D

## Controla a partida: rounds, placar, posicionamento e separação dos corpos.

const ROUNDS_TO_WIN := 2
const P1_START := Vector2(420, 600)
const P2_START := Vector2(860, 600)
const MIN_SEPARATION := Fighter.BODY_HALF_WIDTH * 2.0 * Fighter.BODY_SCALE + 8.0
## Elenco do P1: dois lutadores. A pasta de arte define quem aparece na tela
## ("faixa" = Bolsonaro, "azul" = Lula).
const P1_ROSTER := [
	{"id": "ryu", "art": "faixa", "label": "BOLSONARO", "color": Color(0.85, 0.28, 0.30)},
	{"id": "ken", "art": "azul", "label": "LULA", "color": Color(0.32, 0.55, 0.95)},
]

@onready var p1: Fighter = $P1
@onready var p2: Fighter = $P2
@onready var hud: CanvasLayer = $HUD

var _wins := {1: 0, 2: 0}
var _round_active := true
var _match_over := false
var _p1_index := 0

func _ready() -> void:
	p1.opponent = p2
	p2.opponent = p1
	p1.health_changed.connect(_on_health_changed.bind(1))
	p2.health_changed.connect(_on_health_changed.bind(2))
	p1.special_changed.connect(_on_special_changed.bind(1))
	p2.special_changed.connect(_on_special_changed.bind(2))
	p1.defeated.connect(_on_defeated)
	p2.defeated.connect(_on_defeated)
	hud.cpu_toggled.connect(_on_cpu_toggled)
	hud.character_cycled.connect(_on_character_cycled)
	hud.set_character_label(P1_ROSTER[_p1_index].label)
	_reset_positions()
	hud.update_round_wins(_wins[1], _wins[2])

func _process(_delta: float) -> void:
	_separate_bodies()
	p1.update_facing()
	p2.update_facing()

func _separate_bodies() -> void:
	if p1.state == Fighter.State.KO or p2.state == Fighter.State.KO:
		return
	# Durante juggle / wall splat / queda o corpo pode atravessar o outro.
	if p1.is_airborne() or p2.is_airborne():
		return
	var dx := p2.global_position.x - p1.global_position.x
	var dist := absf(dx)
	if dist >= MIN_SEPARATION:
		return
	var push := (MIN_SEPARATION - dist) * 0.5
	var dir := signf(dx)
	if dir == 0.0:
		dir = 1.0
	p1.global_position.x -= dir * push
	p2.global_position.x += dir * push

func _reset_positions() -> void:
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()
	p1.reset_for_round(P1_START)
	p2.reset_for_round(P2_START)
	p1.facing = 1
	p2.facing = -1
	p1.update_facing()
	p2.update_facing()
	hud.set_health(1, Fighter.MAX_HEALTH, Fighter.MAX_HEALTH)
	hud.set_health(2, Fighter.MAX_HEALTH, Fighter.MAX_HEALTH)
	hud.set_special(1, 0.0, Fighter.MAX_SPECIAL)
	hud.set_special(2, 0.0, Fighter.MAX_SPECIAL)

func _on_health_changed(current: int, maximum: int, player: int) -> void:
	hud.set_health(player, current, maximum)

func _on_special_changed(current: float, maximum: float, player: int) -> void:
	hud.set_special(player, current, maximum)

func _on_defeated(fighter: Fighter) -> void:
	if not _round_active or _match_over:
		return
	_round_active = false
	var winner := 2 if fighter == p1 else 1
	_wins[winner] += 1
	hud.update_round_wins(_wins[1], _wins[2])
	hud.show_message("%s WINS THE ROUND" % _name_of(winner))
	await get_tree().create_timer(1.6).timeout
	if _wins[winner] >= ROUNDS_TO_WIN:
		_match_over = true
		hud.show_message("%s WINS THE MATCH!" % _name_of(winner))
		await get_tree().create_timer(2.2).timeout
		_full_reset()
	else:
		hud.show_message("ROUND %d" % (_wins[1] + _wins[2] + 1))
		_reset_positions()
		_round_active = true
		await get_tree().create_timer(0.9).timeout
		if not _match_over:
			hud.show_message("")

func _full_reset() -> void:
	_wins = {1: 0, 2: 0}
	_match_over = false
	_round_active = true
	hud.update_round_wins(0, 0)
	hud.show_message("")
	_reset_positions()

func _name_of(player: int) -> String:
	return "P1" if player == 1 else "P2"

func _on_character_cycled() -> void:
	_p1_index = (_p1_index + 1) % P1_ROSTER.size()
	var entry: Dictionary = P1_ROSTER[_p1_index]
	p1.set_character(entry.id, entry.art, entry.color)
	hud.set_character_label(entry.label)

func _on_cpu_toggled(enabled: bool) -> void:
	p2.ai_enabled = enabled
	InputBridge.clear_virtual(2)
