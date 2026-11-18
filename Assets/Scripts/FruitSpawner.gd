extends Node2D
## Genera frutas en una X aleatoria por encima de la pantalla y las deja caer.

const TEX_BROCOLI: Texture2D = preload("res://Assets/Art/Fruit/Brócoli .png")
const TEX_CEREZA: Texture2D = preload("res://Assets/Art/Fruit/Cereza.png")
const TEX_NARANJA: Texture2D = preload("res://Assets/Art/Fruit/Naranja.png")
const TEX_ONIGIRI: Texture2D = preload("res://Assets/Art/Fruit/Onigiri.png")
const TEX_SUSHI: Texture2D = preload("res://Assets/Art/Fruit/Sushi.png")
const TEX_PEPINILLO: Texture2D = preload("res://Assets/Art/Fruit/Pepinillo.png")

## Escena de fruta a instanciar.
@export var fruit_scene: PackedScene = preload("res://Fruits/fruit.tscn")
@export var bomb_scene: PackedScene = preload("res://Bomb/Bomb.tscn")

## Una entrada por tipo de fruta. Si lo dejas vacío se usan los presets de abajo.
## Claves: "color" (Color), "points" (int), "radius" (float), "speed" (float).
@export var fruit_presets: Array[Dictionary] = []
@export var bomb_presets: Array[Dictionary] = []

## Margen horizontal respecto a los bordes de la pantalla.
@export_range(0.0, 2000.0) var side_margin: float = 48.0

## Qué tan arriba, fuera de pantalla, nace la fruta.
@export_range(0.0, 1000.0) var spawn_offset_y: float = 80.0

## Tiempo mínimo / máximo entre apariciones (segundos).
@export_range(0.05, 20.0) var min_interval: float = 0.6
@export_range(0.05, 20.0) var max_interval: float = 1.4

## Nodo donde se cuelgan las frutas. Vacío = este mismo nodo.
@export var container_path: NodePath

var _timer: Timer
var _container: Node
var prob_bomb: float = 0.2


func _ready() -> void:
	_container = get_node_or_null(container_path) if container_path != NodePath() else self

	_timer = get_node_or_null("Timer") as Timer
	if _timer == null:
		_timer = Timer.new()
		_timer.name = "Timer"
		add_child(_timer)

	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	_schedule_next()


func _on_timer_timeout() -> void:
	# Terminada la partida no aparecen más objetos, pero el timer sigue vivo
	# para reanudarse en cuanto se reinicie.
	if Game.is_running:
		if randf() < prob_bomb:
			spawn_bomb()
		else:
			spawn_fruit()

	_schedule_next()


func _schedule_next() -> void:
	_timer.start(randf_range(min_interval, max_interval))


## Rectángulo del mundo que está viendo la cámara actual.
func get_play_rect() -> Rect2:
	var rect := get_viewport().get_visible_rect()
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		var size := rect.size / camera.zoom
		rect = Rect2(camera.get_screen_center_position() - size * 0.5, size)
	return rect


func spawn_bomb() -> Node2D:
	if bomb_scene == null:
		push_warning("FruitSpawner: falta asignar bomb_scene.")
		return null

	var preset: Dictionary = _pick_preset_bomb()
	var bomb := bomb_scene.instantiate()
	var rect := get_play_rect()
	var radius: float = float(preset.get("radius", 24.0))

	# Rango horizontal válido, evitando que la fruta nazca cortada por un borde.
	var left := rect.position.x + side_margin + radius
	var right := rect.end.x - side_margin - radius
	if right < left:
		right = left

	bomb.bomb_color = preset.get("color", Color.WEB_GRAY)
	bomb.bomb_texture = preset.get("texture", null)
	bomb.daño = int(preset.get("daño", 10))
	bomb.radius = radius
	bomb.fall_speed = float(preset.get("speed", 180.0)) * randf_range(0.9, 1.1)

	# X aleatoria, nace justo arriba del borde superior visible.
	bomb.position = Vector2(randf_range(left, right), rect.position.y - spawn_offset_y - radius)
	bomb.despawn_y = rect.end.y + radius * 2.0

	_container.add_child(bomb)
	return bomb

func spawn_fruit() -> Node2D:
	if fruit_scene == null:
		push_warning("FruitSpawner: falta asignar fruit_scene.")
		return null

	var preset: Dictionary = _pick_preset()
	var fruit := fruit_scene.instantiate()
	var rect := get_play_rect()
	var radius: float = float(preset.get("radius", 24.0))

	# Rango horizontal válido, evitando que la fruta nazca cortada por un borde.
	var left := rect.position.x + side_margin + radius
	var right := rect.end.x - side_margin - radius
	if right < left:
		right = left

	fruit.fruit_color = preset.get("color", Color.RED)
	fruit.fruit_texture = preset.get("texture", null)
	fruit.points = int(preset.get("points", 10))
	fruit.radius = radius
	fruit.fall_speed = float(preset.get("speed", 180.0)) * randf_range(0.9, 1.1)
	fruit.fruta_recolectada = 1

	# X aleatoria, nace justo arriba del borde superior visible.
	fruit.position = Vector2(randf_range(left, right), rect.position.y - spawn_offset_y - radius)
	fruit.despawn_y = rect.end.y + radius * 2.0

	_container.add_child(fruit)
	return fruit


func _pick_preset() -> Dictionary:
	var list: Array = fruit_presets if not fruit_presets.is_empty() else _default_presets()
	return list.pick_random()
	
func _pick_preset_bomb() -> Dictionary:
	var list: Array = bomb_presets if not bomb_presets.is_empty() else _default_presets_bomb()
	return list.pick_random()


func _default_presets() -> Array[Dictionary]:
	return [
		{"name": "cereza", "color": Color("e63946"), "texture": TEX_CEREZA, "points": 10, "radius": 24.0, "speed": 200.0},
		{"name": "naranja", "color": Color("f4a300"), "texture": TEX_NARANJA, "points": 15, "radius": 28.0, "speed": 150.0},
		{"name": "onigiri", "color": Color("f5f5f5"), "texture": TEX_ONIGIRI, "points": 20, "radius": 28.0, "speed": 160.0},
		{"name": "sushi", "color": Color("767d85ff"), "texture": TEX_SUSHI, "points": 25, "radius": 28.0, "speed": 180.0},
	]


func _default_presets_bomb() -> Array[Dictionary]:
	return [
		{"name": "pepinillo", "color": Color("6b8e23"), "texture": TEX_PEPINILLO, "radius": 30.0, "speed": 150.0},
		{"name": "brocoli", "color": Color("2eb872"), "texture": TEX_BROCOLI, "radius": 28.0, "speed": 170.0},
	]

func dificultad() -> void:
	pass
