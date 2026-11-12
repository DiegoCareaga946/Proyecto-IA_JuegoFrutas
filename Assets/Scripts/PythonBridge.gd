extends Node
## Lanza Assets/python/detector.py junto con el juego y lo cierra al salir.
## Registrado como autoload ("Detector") en project.godot.

## Ponlo en false para arrancar el juego sin la cámara.
@export var autostart: bool = true

## Ruta a python.exe. Vacío = detección automática.
## También puedes forzarla con la variable de entorno FRUTAS_PYTHON.
@export var python_executable: String = ""

const SCRIPT_RELATIVE := "Assets/python/detector.py"
const EXE_RELATIVE := "Assets/python/detector.exe"

var _pid: int = -1


func _ready() -> void:
	if not autostart:
		return
	# Evita abrir la cámara en ejecuciones headless (tests, export de servidor).
	if DisplayServer.get_name() == "headless":
		return
	start_detector()


func _exit_tree() -> void:
	stop_detector()


func start_detector() -> void:
	if _pid > 0:
		return

	# 1) Si existe un detector empaquetado (PyInstaller), se usa ese.
	var exe := _find_file(EXE_RELATIVE)
	if not exe.is_empty():
		_pid = OS.create_process(exe, PackedStringArray(), false)
		if _pid > 0:
			print("Detector iniciado: ", exe, " (pid ", _pid, ")")
			return
		push_warning("Detector: no se pudo ejecutar " + exe)
		return

	# 2) Si no, se ejecuta el .py con el intérprete de Python.
	var script_path := _find_file(SCRIPT_RELATIVE)
	if script_path.is_empty():
		push_warning("Detector: no se encontró " + SCRIPT_RELATIVE + " ni " + EXE_RELATIVE)
		return

	var python := _resolve_python()
	_pid = OS.create_process(python, PackedStringArray([script_path]), false)
	if _pid > 0:
		print("Detector iniciado: ", python, " ", script_path, " (pid ", _pid, ")")
	else:
		push_warning("Detector: no se pudo lanzar " + python)


func stop_detector() -> void:
	if _pid <= 0:
		return
	OS.kill(_pid)
	print("Detector detenido (pid ", _pid, ")")
	_pid = -1


## Busca el archivo en el proyecto (editor) y junto al ejecutable (build exportado).
func _find_file(relative: String) -> String:
	for base in _search_roots():
		var path := base.path_join(relative)
		if FileAccess.file_exists(path):
			return path
	return ""


func _search_roots() -> Array[String]:
	var roots: Array[String] = [ProjectSettings.globalize_path("res://")]
	var exe_dir := OS.get_executable_path().get_base_dir()
	if not roots.has(exe_dir):
		roots.append(exe_dir)
	return roots


func _resolve_python() -> String:
	if not python_executable.is_empty():
		return python_executable

	var from_env := OS.get_environment("FRUTAS_PYTHON")
	if not from_env.is_empty():
		return from_env

	var from_settings := str(ProjectSettings.get_setting("detector/python_executable", ""))
	if not from_settings.is_empty():
		return from_settings

	if OS.get_name() != "Windows":
		return "python3"

	for candidate in ["python", "py"]:
		var output: Array = []
		if OS.execute("where", PackedStringArray([candidate]), output, true) != 0:
			continue
		var text := str(output[0]) if not output.is_empty() else ""
		for line in text.split("\n"):
			var path := line.strip_edges()
			# El alias de Windows Store no sirve para lanzar procesos.
			if path.is_empty() or path.findn("WindowsApps") != -1:
				continue
			return path

	return "python"
