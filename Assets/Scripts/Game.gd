extends Node
## Estado global de la partida (autoload "Game", plan P1).
## Único dueño del puntaje y de las vidas: nadie más los modifica.

signal score_changed(total: int)
signal lives_changed(lives: int)
signal time_changed(seconds: float)
signal combo_changed(combo: int)

const MAX_LIVES := 3
const INTERVALO_TIEMPO := 0.25
const FRUTAS_PARA_RECUPERAR_VIDA := 10

var score: int = 0
var lives: int = MAX_LIVES
var time_played: float = 0.0
var is_running: bool = true
var combo: int = 0


var _acumulado: float = 0.0


func _process(delta: float) -> void:
	if not is_running:
		return
	time_played += delta
	_acumulado += delta
	if _acumulado < INTERVALO_TIEMPO:
		return
	_acumulado = 0.0
	time_changed.emit(time_played)


func add_score(points: int) -> void:
	if points <= 0:
		return
	score += points
	combo += 1
	score_changed.emit(score)
	if combo >= FRUTAS_PARA_RECUPERAR_VIDA:
		if lives < MAX_LIVES:
			gain_life()
		combo = 0
	combo_changed.emit(combo)


func reset_combo() -> void:
	combo = 0
	combo_changed.emit(combo)


func lose_life() -> void:
	reset_combo()
	_set_lives(lives - 1)


func gain_life() -> void:
	_set_lives(lives + 1)


func _set_lives(value: int) -> void:
	var nuevo := clampi(value, 0, MAX_LIVES)
	if nuevo == lives:
		return
	lives = nuevo
	lives_changed.emit(lives)


func end_run() -> void:
	if lives == 0:
		is_running = false


func reset_run() -> void:
	score = 0
	lives = MAX_LIVES
	time_played = 0.0
	_acumulado = 0.0
	combo = 0
	is_running = true
	score_changed.emit(score)
	lives_changed.emit(lives)
	combo_changed.emit(combo)
	time_changed.emit(time_played)
