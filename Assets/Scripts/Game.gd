extends Node
## Estado global de la partida (autoload "Game", plan P1).
## Único dueño del puntaje y de las vidas: nadie más los modifica.

signal score_changed(total: int)
signal lives_changed(lives: int)

const MAX_LIVES := 3

var score: int = 0
var lives: int = MAX_LIVES


func add_score(points: int) -> void:
	if points <= 0:
		return
	score += points
	score_changed.emit(score)


func lose_life() -> void:
	_set_lives(lives - 1)


func gain_life() -> void:
	_set_lives(lives + 1)


func _set_lives(value: int) -> void:
	var nuevo := clampi(value, 0, MAX_LIVES)
	if nuevo == lives:
		return
	lives = nuevo
	lives_changed.emit(lives)


func reset_run() -> void:
	score = 0
	lives = MAX_LIVES
	score_changed.emit(score)
	lives_changed.emit(lives)
