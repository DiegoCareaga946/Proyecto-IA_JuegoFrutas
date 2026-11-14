extends CharacterBody2D

## Movimiento horizontal continuo por posición de la mano (UDP 4242).
## El detector manda la X de la palma normalizada (0..1) o "0.0" si no ve mano.

signal reset_run

@export_group("Control")
@export var velocidad_max: float = 520.0     # px/s (plan: 420-520)
@export var suavizado: float = 12.0          # 1/s (plan: ~12)
@export var timeout_ms: int = 500            # sin paquetes -> fallback
@export var margen_pixeles: float = 24.0     # margen extra a cada lado
@export_range(0.0, 0.5, 0.01) var rango_min: float = 0.15
@export_range(0.5, 1.0, 0.01) var rango_max: float = 0.85

# Legado: l_side / r_side ya no se usan para mover. Se dejan declarados
# para que character_body_2d.tscn siga cargando sin errores.
@export var extremo_izquierdo: Area2D
@export var extremo_derecho: Area2D

var palma_objetivo: float = 0.5              # última X válida (NO se reinicia por frame)
var ultimo_paquete_ms: int = -100000
var udp := PacketPeerUDP.new()

var _raton_previo: float = 0.0
var _raton_activo: bool = false

@onready var _colision: CollisionShape2D = $CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	var error := udp.bind(4242, "127.0.0.1")
	if error != OK:
		push_error("No se pudo abrir el UDP 4242: %s" % error_string(error))

func _physics_process(delta: float) -> void:
	_leer_paquetes()
	
	# El mouse solo toma el control cuando se mueve de verdad.
	var raton_x := get_global_mouse_position().x
	if absf(raton_x - _raton_previo) > 0.5:
		_raton_activo = true
	_raton_previo = raton_x

	var limites := _limites_mundo()
	var hay_destino := true
	var destino_x := 0.0

	if Time.get_ticks_msec() - ultimo_paquete_ms <= timeout_ms:
		_raton_activo = false                # la mano manda; el mouse se desarma
		var t := clampf(inverse_lerp(rango_min, rango_max, palma_objetivo), 0.0, 1.0)
		destino_x = lerpf(limites.x, limites.y, t)
	elif _raton_activo:
		destino_x = clampf(raton_x, limites.x, limites.y)
	else:
		hay_destino = false
		animated_sprite.play("idle")

	if hay_destino:
		var fraccion := 1.0 - exp(-suavizado * delta)   # sin sobrepaso, independiente de los fps
		animated_sprite.play("walk")
		velocity.x = clampf(
			(destino_x - global_position.x) * fraccion / delta,
			-velocidad_max, velocidad_max
		)
	else:
		velocity.x = 0.0

	velocity.y = 0.0
	move_and_slide()


func _leer_paquetes() -> void:
	while udp.get_available_packet_count() > 0:
		var texto := udp.get_packet().get_string_from_utf8().strip_edges()
		if not texto.is_valid_float():
			continue                          # p. ej. un detector viejo mandando "izquierda"
		var valor := texto.to_float()
		if valor > 0.0:                       # 0.0 = no hay mano: se conserva el último objetivo
			palma_objetivo = clampf(valor, 0.0, 1.0)
			ultimo_paquete_ms = Time.get_ticks_msec()


func _limites_mundo() -> Vector2:
	var mitad := _mitad_ancho()
	var camara := get_viewport().get_camera_2d()

	if camara == null:
		var r := get_viewport_rect()
		var margen := minf(margen_pixeles + mitad, r.size.x * 0.5)
		return Vector2(r.position.x + margen, r.end.x - margen)

	var ancho_visible := get_viewport_rect().size.x / camara.zoom.x
	# El margen nunca puede comerse más de media pantalla (ventanas muy angostas).
	var margen := minf(margen_pixeles + mitad, ancho_visible * 0.5)
	var centro := camara.get_screen_center_position().x
	return Vector2(
		centro - ancho_visible * 0.5 + margen,
		centro + ancho_visible * 0.5 - margen
	)


func _mitad_ancho() -> float:
	var forma := _colision.shape
	if forma is RectangleShape2D:
		return (forma as RectangleShape2D).size.x * 0.5 * absf(scale.x)
	return 0.0

func reiniciar_juego(event: InputEvent) -> void:
	if event is InputEvent and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_SPACE:
			reset_run.emit()
			
func _exit_tree() -> void:
	udp.close()
