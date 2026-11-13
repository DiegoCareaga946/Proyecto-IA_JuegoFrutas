extends CanvasLayer
## Marcador de la partida (plan P2). Solo muestra: el estado vive en Game.

@onready var _puntos: Label = %Puntos
@onready var _corazones: HBoxContainer = %Corazones

@export var color_lleno := Color("e63946")
@export var color_vacio := Color(0.35, 0.35, 0.35, 0.5)


func _ready() -> void:
	Game.score_changed.connect(_actualizar_puntos)
	Game.lives_changed.connect(_actualizar_vidas)
	_actualizar_puntos(Game.score)
	_actualizar_vidas(Game.lives)


func _actualizar_puntos(total: int) -> void:
	_puntos.text = "PUNTOS  %06d" % total


func _actualizar_vidas(vidas: int) -> void:
	for i in _corazones.get_child_count():
		var corazon := _corazones.get_child(i) as Control
		corazon.modulate = color_lleno if i < vidas else color_vacio
