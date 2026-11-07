extends CharacterBody2D


@export var velocidad:float = 300.0

@export var extremo_izquierdo:Area2D 
@export var extremo_derecho:Area2D

var movimiento_izquierda:bool = false
var movimiento_derecha:bool = false

var mousePosition: Vector2

var udp := PacketPeerUDP.new()
var lado_mano := "centro"
var ultimo_paquete_ms := 0

func _ready() -> void:
	extremo_izquierdo.mouse_entered.connect(_on_izquierdo_mouse_entered)
	extremo_izquierdo.mouse_exited.connect(_on_izquierdo_mouse_exited)
	
	extremo_derecho.mouse_entered.connect(_on_derecho_mouse_entered)
	extremo_derecho.mouse_exited.connect(_on_derecho_mouse_exited)
	
	var error := udp.bind(4242, "127.0.0.1")
	if error != OK:
		push_error("No se pudo abrir el puerto UDP 4242.")
		
func _process(_delta: float) -> void:
	# Actualiza la posición global del mouse en cada frame
	mousePosition = get_viewport().get_mouse_position()

func _input(event: InputEvent) -> void:
	# Detectar movimiento usando directamente los datos del evento
	if event is InputEventMouseMotion:
		print("El mouse se movió a: ", event.global_position)
	# Detectar clics principales (Clic Izquierdo)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				print("Clic izquierdo presionado en: ", mousePosition)
			else:
				print("Clic izquierdo liberado")
func _physics_process(_delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		var mensaje := udp.get_packet().get_string_from_utf8().strip_edges()

		if mensaje in ["izquierda", "derecha", "centro"]:
			lado_mano = mensaje
			ultimo_paquete_ms = Time.get_ticks_msec()

	var mano_conectada := Time.get_ticks_msec() - ultimo_paquete_ms < 500
	var direccion := 0

	if mano_conectada:
		if lado_mano == "izquierda":
			direccion = -1
		elif lado_mano == "derecha":
			direccion = 1
		elif movimiento_izquierda:
			direccion = -1
		elif movimiento_derecha:
			direccion = 1

	velocity.x = direccion * velocidad
	move_and_slide()

func _exit_tree() -> void:
	udp.close()
	
func _on_izquierdo_mouse_entered()-> void:
	movimiento_izquierda = true
func _on_izquierdo_mouse_exited()-> void:
	movimiento_izquierda = false

func _on_derecho_mouse_entered()-> void:
	movimiento_derecha = true
func _on_derecho_mouse_exited()-> void:
	movimiento_derecha = false

	
