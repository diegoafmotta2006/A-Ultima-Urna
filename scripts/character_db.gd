class_name CharacterDB
extends RefCounted

## Carrega os perfis de fisica por personagem extraidos do Street Fighter SNK
## (M.U.G.E.N) e devolve os valores ja convertidos para o engine.
##
## Origem dos numeros: data/source/fisica_personagens.json
## Modelo e conversao: data/source/MODELO-FISICA.md
## Valores brutos ficam em data/characters.json (px/tick e px/tick^2).

const DATA_PATH := "res://data/characters.json"
const DEFAULT_ID := "ryu"
const FPS := 60.0
## Nosso lutador tem 112 px de corpo; o M.U.G.E.N de referencia, 100 px.
const MUGEN_TO_GODOT := 67.2
const BODY_SCALE := 1.12

static var _profiles: Array[Dictionary] = []
static var _by_id: Dictionary = {}
static var _loaded := false

static func all() -> Array[Dictionary]:
	_ensure_loaded()
	return _profiles

static func ids() -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for id in _by_id:
		out.append(String(id))
	out.sort()
	return out

static func has(id: String) -> bool:
	_ensure_loaded()
	return _by_id.has(id)

## Perfil pronto para o fighter. Cai no DEFAULT_ID se o id nao existir.
static func get_profile(id: String) -> Dictionary:
	_ensure_loaded()
	if _by_id.has(id):
		return _by_id[id].duplicate(true)
	return _by_id.get(DEFAULT_ID, {}).duplicate(true)

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var text := FileAccess.get_file_as_string(DATA_PATH)
	if text.is_empty():
		push_error("CharacterDB: nao consegui ler %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("CharacterDB: %s nao contem uma lista" % DATA_PATH)
		return
	for raw in parsed:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var profile := _convert(raw)
		if profile.is_empty():
			continue
		_profiles.append(profile)
		_by_id[profile.id] = profile

## Converte um registro bruto (px/tick) para os valores usados pelo engine.
static func _convert(raw: Dictionary) -> Dictionary:
	var id := String(raw.get("id", "")).strip_edges()
	if id.is_empty():
		return {}
	var walk_fwd := absf(_raw(raw, "walk_fwd", 3.0))
	var walk_back := absf(_raw(raw, "walk_back", 2.5))
	var jump_y := _raw(raw, "jump_neu_y", -10.0)
	if jump_y > 0.0:
		jump_y = -jump_y
	var yaccel := maxf(_raw(raw, "yaccel", 0.5), 0.05)
	var friction := clampf(_raw(raw, "stand_friction", 0.85), 0.1, 0.999)
	var jump_fwd := _raw(raw, "jump_fwd_x", 3.0)
	var jump_back := _raw(raw, "jump_back_x", -3.0)
	if jump_back > 0.0:
		jump_back = -jump_back
	return {
		"id": id,
		"name": String(raw.get("name", id)),
		"source_file": String(raw.get("source_file", "")),
		"height": _raw(raw, "height", 100.0),
		"walk_fwd": walk_fwd * MUGEN_TO_GODOT,
		"walk_back": walk_back * MUGEN_TO_GODOT,
		"jump_vy": jump_y * MUGEN_TO_GODOT,
		"jump_fwd": jump_fwd * MUGEN_TO_GODOT,
		"jump_back": jump_back * MUGEN_TO_GODOT,
		"gravity": yaccel * FPS * FPS * BODY_SCALE,
		"ground_friction": friction,
		"airjuggle": _raw(raw, "airjuggle", 15.0),
		"life": _raw(raw, "life", 1000.0),
		"attack": _raw(raw, "attack", 100.0),
		"defence": _raw(raw, "defence", 100.0),
	}

static func _raw(raw: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = raw.get(key)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback
