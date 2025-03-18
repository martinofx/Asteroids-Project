extends Area2D

@export var speed: float = 850.0  # Velocidad de movimiento
@export var stop_distance: float = 200.0  # Distancia antes de detenerse
@export var stop_time: float = 0.5  # Tiempo detenido antes de moverse otra vez
@export var health: int = 100  # Vida del enemigo
@export var enemy_laser_scene: PackedScene  # Asignar aquí la escena del láser enemigo
@export var fire_rate: float = 2.0  # Tiempo entre disparos
@export var explosion_scene: PackedScene  # Asigna aquí la escena de la explosión

var direction: Vector2  # Dirección del movimiento
var start_position: Vector2  # Posición inicial para calcular distancia
var moving: bool = true  # Control de movimiento
var screen_size: Vector2  # Tamaño de la pantalla

@onready var sprite: Sprite2D = $Sprite2D  # Sprite del enemigo

func _ready():
	screen_size = get_viewport_rect().size  # Obtener el tamaño de la pantalla
	start_position = global_position  # Guardar posición inicial
	pick_new_direction()  # Elegir dirección aleatoria
	start_shooting()

func _process(delta):
	if moving:
		move_enemy(delta)

	check_screen_wrap()  # Verificar si debe teletransportarse

func move_enemy(delta):
	global_position += direction * speed * delta

	if global_position.distance_to(start_position) >= stop_distance:
		stop_movement()

func stop_movement():
	moving = false
	await get_tree().create_timer(stop_time).timeout
	pick_new_direction()
	start_position = global_position
	moving = true

func pick_new_direction():
	direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func check_screen_wrap():
	var new_position = global_position
	var crossed = false

	if global_position.x < 0:
		new_position.x = screen_size.x
		crossed = true
	elif global_position.x > screen_size.x:
		new_position.x = 0
		crossed = true

	if global_position.y < 0:
		new_position.y = screen_size.y
		crossed = true
	elif global_position.y > screen_size.y:
		new_position.y = 0
		crossed = true

	if crossed:
		global_position = new_position  
		pick_new_direction()  # Generar nueva dirección tras el teletransporte
		start_position = global_position  # Reiniciar punto de referencia para distancia

func take_damage(collision_direction: Vector2 = Vector2.ZERO, force: float = 0.0):
	health -= 100
	sprite.modulate = Color(1, 0.5, 0.5)  # Efecto de daño (rojo)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color(1, 1, 1)  # Restaurar color
	
	if collision_direction != Vector2.ZERO and force > 0.0:
	# Aplicar rebote en dirección contraria al impacto
		global_position += collision_direction * -force * 0.1	

	if health <= 0:
		die()

func die():
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position  # La explosión aparece en el punto de impacto
	queue_free()  # Eliminar enemigo

func start_shooting():
	while true:
		await get_tree().create_timer(fire_rate).timeout
		shoot()

func shoot():
	if not is_instance_valid(get_tree()) or not is_inside_tree():
		return  # Evita disparos si el enemigo fue eliminado

	var player = get_parent().get_node_or_null("Player")  # Buscar al jugador
	if player:
		var enemy_laser = enemy_laser_scene.instantiate() as Area2D
		get_parent().add_child(enemy_laser)

		enemy_laser.global_position = global_position  # Disparo desde el enemigo
		var shoot_direction = (player.global_position - global_position).normalized()  # Dirección hacia el jugador

		if enemy_laser.has_method("set_direction"):  # Si el láser tiene el método set_direction()
			enemy_laser.set_direction(shoot_direction)
		elif "direction" in enemy_laser:  # Si tiene la propiedad direction
			enemy_laser.direction = shoot_direction

		enemy_laser.rotation = shoot_direction.angle()  # Rotar el láser hacia el jugador


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):  # Si colisiona con el jugador
		body.take_damage()  # Llama a la función de daño del jugador
		die()
		queue_free()  # El enemigo desaparece tras colisionar
