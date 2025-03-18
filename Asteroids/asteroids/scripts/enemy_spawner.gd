extends Node2D

@export var enemy_scene: PackedScene  # Asignar la escena del enemigo
@export var spawn_rate: float = 10  # Tiempo entre apariciones

@onready var spawn_points: Array = []

func _ready():
	var spawn_positions = get_node_or_null("SpawnPositions")
	
	if spawn_positions:
		for child in spawn_positions.get_children():
			if child is Marker2D:
				spawn_points.append(child)

	if spawn_points.is_empty():
		push_error("No se encontraron puntos de spawn.")
	else:
		#start_spawning()
		return

func start_spawning():
	while true:
		await get_tree().create_timer(spawn_rate).timeout
		spawn_enemy()

func spawn_enemy():
	if enemy_scene == null:
		return

	var spawn_point = spawn_points.pick_random()  # Selecciona un punto de spawn aleatorio
	var enemy = enemy_scene.instantiate() as Node2D  # Instancia el enemigo
	get_parent().add_child(enemy)  # Agrega el enemigo a la escena
	enemy.global_position = spawn_point.global_position  # Lo coloca en el punto de spawn
