extends Node

func _ready():
	pass#Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)  # Opcional: Mantener el mouse dentro de la ventana

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):  # Escape para salir
		quit_game()
	if Input.is_action_just_pressed("restart"):  # Presionar "P" para reiniciar
		restart_game()

func restart_game():
	get_tree().reload_current_scene()  # Recarga la escena actual

func quit_game():
	get_tree().quit()  # Cierra el juego
