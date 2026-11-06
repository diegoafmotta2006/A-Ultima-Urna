extends CanvasLayer

## HUD: barras de vida, placar de rounds, mensagem central,
## botões de toque (Android/móvel) e alternativa contra a CPU.

signal cpu_toggled(enabled: bool)

const BAR_W := 480.0
const BAR_H := 28.0
const PAD := 2.0
const INNER := BAR_W - PAD * 2.0

var _cpu := false

@onready var _p1_fill: ColorRect = $Root/P1BarBG/P1BarFill
@onready var _p2_fill: ColorRect = $Root/P2BarBG/P2BarFill
@onready var _round_label: Label = $Root/RoundLabel
@onready var _center: Label = $Root/CenterLabel
@onready var _cpu_button: Button = $Root/CpuButton

@onready var _touch_buttons: Array[Button] = [
	$Root/TouchLeft, $Root/TouchRight, $Root/TouchJump, $Root/TouchLight, $Root/TouchHeavy,
]

func _ready() -> void:
	_bind_hold($Root/TouchLeft, "left")
	_bind_hold($Root/TouchRight, "right")
	_bind_hold($Root/TouchJump, "jump")
	_bind_hold($Root/TouchLight, "light")
	_bind_hold($Root/TouchHeavy, "heavy")
	_cpu_button.pressed.connect(_on_cpu_pressed)
	var show_touch := DisplayServer.is_touchscreen_available()
	for button in _touch_buttons:
		button.visible = show_touch

func _bind_hold(button: Button, action: String) -> void:
	button.button_down.connect(func() -> void: InputBridge.set_virtual(1, action, true))
	button.button_up.connect(func() -> void: InputBridge.set_virtual(1, action, false))

func _on_cpu_pressed() -> void:
	_cpu = not _cpu
	_cpu_button.text = "CPU: ON" if _cpu else "CPU: OFF"
	cpu_toggled.emit(_cpu)

func set_health(player: int, current: int, maximum: int) -> void:
	var ratio := clampf(float(current) / float(maximum), 0.0, 1.0)
	var w := INNER * ratio
	var h := BAR_H - PAD * 2.0
	if player == 1:
		_p1_fill.position = Vector2(PAD, PAD)
		_p1_fill.size = Vector2(w, h)
	else:
		_p2_fill.position = Vector2(PAD + (INNER - w), PAD)
		_p2_fill.size = Vector2(w, h)

func update_round_wins(p1: int, p2: int) -> void:
	_round_label.text = "P1 %s      %s P2" % [_pips(p1), _pips(p2)]

func show_message(text: String) -> void:
	_center.text = text

func _pips(n: int) -> String:
	var s := ""
	for i in 2:
		s += "*" if i < n else "-"
	return s
