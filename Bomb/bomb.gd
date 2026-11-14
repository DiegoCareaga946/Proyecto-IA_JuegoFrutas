@tool
extends Area2D
## Fruta genérica. Se dibuja con formas (sin texturas) y cae hacia abajo.
## Para usar arte propio: agrega un Sprite2D como hijo y borra _draw().

signal Daño(daño: int)

@export var bomb_color: Color = Color("67655fff"):
	set(value):
		bomb_color = value
		queue_redraw()

@export var radius: float = 24.0:
	set(value):
		radius = value
		queue_redraw()

@export var daño: int = 1
@export var fall_speed: float = 180.0

## Altura a partir de la cual la fruta se borra. La asigna el spawner según la cámara.
var despawn_y: float = INF


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	add_to_group("fruits")
	_fit_collision()

	if despawn_y == INF:
		despawn_y = _camera_bottom() + radius * 2.0

	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	position.y += fall_speed * delta
	if position.y > despawn_y:
		queue_free()


## Ajusta el radio del CollisionShape2D al radio visual.
func _fit_collision() -> void:
	var shape := $CollisionShape2D.shape as CircleShape2D
	if shape == null:
		return
	shape = shape.duplicate()
	$CollisionShape2D.shape = shape
	shape.radius = radius


func _camera_bottom() -> float:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return get_viewport_rect().size.y
	return camera.get_screen_center_position().y + get_viewport_rect().size.y / camera.zoom.y * 0.5


func _draw() -> void:
	# Cuerpo
	draw_circle(Vector2.ZERO, radius, bomb_color)

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, bomb_color.darkened(0.35), 3.0, true)

	# Brillo
	draw_circle(Vector2(-radius * 0.35, -radius * 0.35), radius * 0.18,
			Color(1, 1, 1, 0.45))


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	Game.lose_life()
	queue_free()
