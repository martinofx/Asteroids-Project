extends Control

@export var weapon_icon: TextureRect  # Referencia al icono en la UI

var weapon_icons = {}  # Diccionario de armas e iconos

func _ready():
	# Agregar los iconos de las armas al diccionario (reemplazar con tus texturas)
	weapon_icons["missile"] = preload("res://assets/powerups/missile.png")
	weapon_icons["raygun"] = preload("res://assets/powerups/raygun.png")
	weapon_icons["cluster"] = preload("res://assets/powerups/cluster.png")
	weapon_icons["nuke"] = preload("res://assets/powerups/nuke.png")

	# Establecer el arma por defecto
	update_weapon_icon("missile")

func update_weapon_icon(weapon_name: String):
	if weapon_name in weapon_icons:
		weapon_icon.texture = weapon_icons[weapon_name]
