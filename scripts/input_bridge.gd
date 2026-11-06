extends Node

## Camada de input unificada: teclado, gamepad e botões de toque (Android/web móvel).
## Os lutadores consultam apenas held(); a detecção de "acabou de pressionar" fica neles.

const KEYS := {
	1: {"left": KEY_A, "right": KEY_D, "jump": KEY_W, "light": KEY_F, "heavy": KEY_G},
	2: {"left": KEY_LEFT, "right": KEY_RIGHT, "jump": KEY_UP, "light": KEY_K, "heavy": KEY_L},
}

var _virtual: Dictionary = {
	1: {"left": false, "right": false, "jump": false, "light": false, "heavy": false},
	2: {"left": false, "right": false, "jump": false, "light": false, "heavy": false},
}

func set_virtual(player: int, action: String, pressed: bool) -> void:
	if _virtual.has(player) and _virtual[player].has(action):
		_virtual[player][action] = pressed

func clear_virtual(player: int) -> void:
	for action in _virtual[player]:
		_virtual[player][action] = false

func held(player: int, action: String) -> bool:
	if _virtual[player][action]:
		return true
	if _gamepad_held(player, action):
		return true
	return Input.is_physical_key_pressed(KEYS[player][action])

func _gamepad_held(player: int, action: String) -> bool:
	var dev := player - 1
	if not Input.get_connected_joypads().has(dev):
		return false
	match action:
		"left":
			return Input.get_joy_axis(dev, JOY_AXIS_LEFT_X) < -0.35 or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT)
		"right":
			return Input.get_joy_axis(dev, JOY_AXIS_LEFT_X) > 0.35 or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT)
		"jump":
			return Input.is_joy_button_pressed(dev, JOY_BUTTON_A)
		"light":
			return Input.is_joy_button_pressed(dev, JOY_BUTTON_X)
		"heavy":
			return Input.is_joy_button_pressed(dev, JOY_BUTTON_Y)
	return false
