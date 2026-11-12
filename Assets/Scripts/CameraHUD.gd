extends CanvasLayer
## Ventana inferior central que muestra lo que ve la cámara del detector.py.

## Debe coincidir con DESTINO_VIDEO de detector.py.
@export var video_port: int = 4243

## Sin paquetes durante este tiempo -> "Cámara desconectada".
@export var timeout_ms: int = 1500

@onready var _video: TextureRect = %Video
@onready var _estado: Label = %Estado
@onready var _variables: Label = %Variables

var _udp := PacketPeerUDP.new()
var _ultimo_paquete := -1
var _meta: Dictionary = {}

var _seq := -1
var _trozos: Array[PackedByteArray] = []
var _recibidos := 0


func _ready() -> void:
	var err := _udp.bind(video_port, "127.0.0.1")
	if err != OK:
		push_error("CameraHUD: no se pudo escuchar el UDP %d: %s" % [video_port, error_string(err)])
		_estado.text = "Puerto %d en uso" % video_port


func _process(_delta: float) -> void:
	var ahora := Time.get_ticks_msec()

	while _udp.get_available_packet_count() > 0:
		_recibir(_udp.get_packet())
		_ultimo_paquete = ahora

	_actualizar_estado(ahora)


func _exit_tree() -> void:
	_udp.close()


func _recibir(data: PackedByteArray) -> void:
	if data.size() < 4:
		return

	match data.slice(0, 3).get_string_from_ascii():
		"MTA":
			_leer_meta(data.slice(3))
		"FRM":
			_leer_trozo(data)


func _leer_meta(data: PackedByteArray) -> void:
	var json := JSON.new()
	if json.parse(data.get_string_from_utf8()) != OK:
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		return

	_meta = json.data
	_variables.text = "lado: %s   palma_x: %.2f   fps: %.0f   res: %dx%d" % [
		str(_meta.get("lado", "—")),
		float(_meta.get("palma_x", 0.0)),
		float(_meta.get("fps", 0.0)),
		int(_meta.get("ancho", 0)),
		int(_meta.get("alto", 0)),
	]


func _leer_trozo(data: PackedByteArray) -> void:
	if data.size() < 11:
		return

	var seq := data.decode_u32(3)
	var indice := data.decode_u16(7)
	var total := data.decode_u16(9)
	if total == 0 or indice >= total:
		return

	if seq != _seq:
		# Frame nuevo: se descarta cualquier resto del anterior.
		_seq = seq
		_trozos.resize(total)
		for i in _trozos.size():
			_trozos[i] = PackedByteArray()
		_recibidos = 0
	elif _trozos.size() != total:
		return

	if _trozos[indice].is_empty():
		_recibidos += 1
	_trozos[indice] = data.slice(11)

	if _recibidos < total:
		return

	var jpg := PackedByteArray()
	for trozo in _trozos:
		jpg.append_array(trozo)
	_trozos.clear()
	_recibidos = 0

	_mostrar_frame(jpg)


func _mostrar_frame(jpg: PackedByteArray) -> void:
	var img := Image.new()
	if img.load_jpg_from_buffer(jpg) != OK:
		return
	_video.texture = ImageTexture.create_from_image(img)


func _actualizar_estado(ahora: int) -> void:
	if _ultimo_paquete < 0:
		_poner_estado("Esperando cámara...")
	elif ahora - _ultimo_paquete > timeout_ms:
		_poner_estado("Cámara desconectada")
	elif bool(_meta.get("mano", false)):
		_poner_estado("Mano detectada: %s" % str(_meta.get("lado", "—")))
	else:
		_poner_estado("Cámara conectada: Esperando mano")


func _poner_estado(texto: String) -> void:
	if _estado.text != texto:
		_estado.text = texto
