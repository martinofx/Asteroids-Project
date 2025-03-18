extends RigidBody2D  # Cambio de CharacterBody2D a Rigidbody2D para física realista

@export var health: int = 100  # Vida del asteroide
@export var min_speed: float = 600.0  # Velocidad mínima (reducida para dar sensación de peso)
@export var max_speed: float = 700.0  # Velocidad máxima (reducida)
@export var explosion_scene: PackedScene  # Escena de la explosión
@export var laser_explosion: PackedScene  # Escena del impacto del láser
@export var push_force: float = 10000.0  # Fuerza con la que empuja a otros objetos

@onready var sprite: Sprite2D = $Sprite2D  # Referencia al sprite
@onready var screen_size: Vector2 = get_viewport_rect().size  # Tamaño de la pantalla

func _ready():
	var random_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var random_speed = randf_range(min_speed, max_speed)
	linear_velocity = random_direction * random_speed
	sprite.frame = 0  # Estado inicial sano

func _integrate_forces(state):
	check_screen_wrap()

func _on_body_entered(body):
	print("Colisión detectada con: ", body.name)  # Debug
	if body.is_in_group("laser") or body.is_in_group("enemy_laser"):  
		take_damage(body.global_position)  # Enviar la posición de impacto
		body.queue_free()
	#elif body.is_in_group("player") or body.is_in_group("enemy"):
	#	apply_push_force(body)  # Empujar al player o enemigo
		
	if body.is_in_group("player"):  # Si choca con la nave
		var impact_force = linear_velocity.length()  # Obtener la velocidad del asteroide
		var collision_direction = (body.global_position - global_position).normalized()
		
		# Rebotar el asteroide en la dirección opuesta
		linear_velocity = -linear_velocity * 10  # Reduce la velocidad un poco al rebotar
		
		# Llamar a la función de la nave para que haga el giro descontrolado
		body.receive_impact(impact_force, collision_direction)

func take_damage(impact_position):
	health -= 25
	print("Vida restante: ", health)  # Debug
	set_damage_frame()  # Actualizar apariencia según vida
	
	if health <= 0:
		print("Ejecutando explode()")  # Debug
		explode()

func set_damage_frame():
	# Ajusta el frame del sprite según el porcentaje de vida
	var max_frames = 4  # Total de frames de daño (0 a 5)
	var damage_index = max_frames - int((health / 100.0) * max_frames)
	damage_index = clamp(damage_index, 0, max_frames - 1)
	sprite.frame = damage_index

func explode():
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		if explosion == null:
			print("Error: explosion_scene no pudo instanciarse.")  # 🚨 Verificar si la escena es válida
			return

		get_parent().add_child(explosion)
		explosion.global_position = global_position  
		print("¡Explosión instanciada en:", explosion.global_position, "!")

	else:
		print("Error: explosion_scene es null")  # 🚨 Si sigue en null, hay un problema en la asignación

	queue_free()

func apply_push_force(body):
	# Empujar al jugador o enemigo con una fuerza proporcional a su distancia
	var direction = (body.global_position - global_position).normalized()
	body.apply_impulse(direction * push_force)  # Aplica un empuje al cuerpo

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
