extends RigidBody2D  # Cambio de CharacterBody2D a Rigidbody2D para física realista

@export var health: int = 100  # Vida del asteroide
@export var min_speed: float = 300.0  # Velocidad mínima
@export var max_speed: float = 600.0  # Velocidad máxima
@export var explosion_scene: PackedScene  # Escena de la explosión
@export var laser_explosion: PackedScene  # Escena del impacto del láser
@export var push_force: float = 500.0  # Fuerza con la que empuja a otros objetos
@export var fade_duration: float = 0.1  # Duración del desvanecimiento

@export var asteroid_third_1 : PackedScene
@export var asteroid_third_2 : PackedScene

@onready var sprite: Sprite2D = $Sprite2D
@onready var screen_size: Vector2 = get_viewport_rect().size

var fading: bool = false
var fade_timer: float = 0.0
var fade_target_position: Vector2
var is_dead: bool = false


func _ready():
	var random_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var random_speed = randf_range(min_speed, max_speed)
	linear_velocity = random_direction * random_speed
	sprite.frame = 0  # Estado inicial sano
	
	randomize() # Asegura que cada ejecución tenga valores distintos

	# Rotación inicial aleatoria
	rotation = randf_range(0, TAU)

	# Velocidad angular aleatoria (negativa o positiva)
	angular_velocity = randf_range(-2.5, 2.5) if randf() < 0.9 else 0.0

	# Si querés también que se muevan con impulso inicial:
	linear_velocity = Vector2.RIGHT.rotated(randf_range(0, TAU)) * randf_range(50, 150)
	
	add_to_group("asteroid")

func _integrate_forces(state):
	check_screen_wrap()
	
	# Limitar velocidad lineal máxima
	var max_speed = 800.0  
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
	
	# Limitar velocidad angular para evitar giros locos
	var max_angular_speed = 3.0
	angular_velocity = clamp(angular_velocity, -max_angular_speed, max_angular_speed)
	
func _physics_process(delta: float) -> void:
	
	ensure_minimum_speed()
	
	# Reducir velocidad con el tiempo
	linear_velocity *= 0.995  
	angular_velocity *= 0.98
	
	if fading:
		fade_timer += delta
		sprite.modulate.a = 1.0 - (fade_timer / fade_duration)
		if fade_timer >= fade_duration:
			complete_fade_transition()

func _on_body_entered(body):
	print("Colisión detectada con: ", body.name)

	if body.is_in_group("laser") or body.is_in_group("enemy_laser"):
		take_damage(body.global_position)
		body.queue_free()

	elif body.is_in_group("player"):
		var impact_force = linear_velocity.length()
		var collision_direction = (body.global_position - global_position).normalized()
		
		# Empuje a la nave basado en la fuerza del impacto
		var push_force = impact_force * 2.5  
		if body is RigidBody2D:
			body.apply_impulse(collision_direction * push_force)
		elif body is CharacterBody2D:
			body.velocity += collision_direction * push_force

		# Aplicar daño si el método existe
		if body.has_method("take_damage"):
			take_damage(body.global_position)
		body.queue_free()

		# Deshabilitar controles si el impacto es fuerte
		if impact_force > 200 and body.has_method("disable_controls"):
			body.disable_controls(0.75) 

func take_damage(impact_position):
	if is_dead:
		return  # Ya explotó, no seguir procesando

	health -= 10
	print("Vida restante: ", health)  
	set_damage_frame()	

	if health <= 0:
		is_dead = true
		print("Ejecutando explode()")
		explode()

func set_damage_frame():
	var total_frames = sprite.hframes * sprite.vframes  # Obtiene el total de frames de la textura
	if total_frames <= 1:  
		return  # Evita errores si el sprite no tiene animaciones

	var damage_index = total_frames - int((health / 100.0) * total_frames)
	damage_index = clamp(damage_index, 0, total_frames - 1)
	
	sprite.frame = damage_index  # Asigna el frame de daño dinámicamente

func explode():
	if explosion_scene:
		var explosion_count = randi_range(2, 6)  # Cantidad aleatoria de explosiones
		for i in range(explosion_count):
			var explosion = explosion_scene.instantiate()
			if explosion:
				get_parent().add_child(explosion)
				
				# Posición aleatoria cerca del asteroide
				var random_offset = Vector2(randf_range(-35, 35), randf_range(-35, 35))
				explosion.global_position = global_position + random_offset
				
				# Escala aleatoria entre 0.5 y 1.5 veces el tamaño normal
				var random_scale = randf_range(1.5, 2.5)
				explosion.scale = Vector2(random_scale, random_scale)

				# Agregar un pequeño retraso entre explosiones
				await get_tree().create_timer(randf_range(0.05, 0.2)).timeout

		print("¡Explosión múltiple generada!")

	else:
		print("Error: explosion_scene es null")
	
	# **Fragmentar el asteroide en 3 partes más pequeñas**
	spawn_fragments()

	# **Eliminar el asteroide grande**
	queue_free()

# **Función que genera los 3 asteroides más pequeños**
func spawn_fragments():
	var spread_angle = PI / 6  # Ángulo de separación base
	var base_direction = linear_velocity.normalized() if linear_velocity.length() > 0 else Vector2.RIGHT
	
	# Lista de prefabs de asteroides
	var asteroides_medianos = [
		asteroid_third_1.instantiate(),
		asteroid_third_2.instantiate(),		
	]

	# **Generar direcciones aleatorias en lugar de seguir una base fija**
	var directions = []
	for i in range(2):
		var random_angle = randf_range(-PI, PI)  # Ahora cada fragmento va en una dirección realmente aleatoria
		directions.append(base_direction.rotated(random_angle))

	for i in range(2):
		if asteroides_medianos[i]:
			get_parent().add_child(asteroides_medianos[i])

			# **Desactivar colisión momentáneamente para evitar empujes extra**
			asteroides_medianos[i].set_collision_layer(0)
			asteroides_medianos[i].set_collision_mask(0)

			# **Separación inicial más grande**
			var spawn_offset = directions[i] * randf_range(25, 40)  
			asteroides_medianos[i].global_position = global_position + spawn_offset  

			# **Impulso completamente aleatorio**
			var extra_force = randf_range(500, 1000)  
			asteroides_medianos[i].linear_velocity = directions[i] * extra_force  # Sin heredar velocidad original

			# Rotación aleatoria
			asteroides_medianos[i].angular_velocity = randf_range(-5, 5)

			# **Reactivar colisión después de un frame**
			asteroides_medianos[i].call_deferred("set_collision_layer", 1)
			asteroides_medianos[i].call_deferred("set_collision_mask", 1)

	print("¡Asteroide fragmentado en 4 partes con direcciones realmente aleatorias!")

	
func check_screen_wrap():
	var new_position = global_position
	var crossed = false

	# Obtener tamaño del asteroide
	var asteroid_size_x = sprite.texture.get_size().x * sprite.scale.x
	var asteroid_size_y = sprite.texture.get_size().y * sprite.scale.y
	var half_width = asteroid_size_x * 0.2
	var half_height = asteroid_size_y * 0.4

	# Wrap horizontal
	if global_position.x < -half_width:
		new_position.x = screen_size.x + half_width  # Aparece fuera antes de entrar
		crossed = true
	elif global_position.x > screen_size.x + half_width:
		new_position.x = -half_width
		crossed = true

	# Wrap vertical
	if global_position.y < -half_height:
		new_position.y = screen_size.y + half_height
		crossed = true
	elif global_position.y > screen_size.y + half_height:
		new_position.y = -half_height
		crossed = true

	# Solo aplicar si se cruzó
	if crossed:
		global_position = new_position
		ensure_minimum_speed()
	

func start_fade_out(new_position: Vector2):
	if not fading:
		fading = true
		fade_timer = 0.0
		fade_target_position = new_position  

func complete_fade_transition():
	global_position = fade_target_position
	start_fade_in()

func start_fade_in():
	fading = false
	fade_timer = 0.0
	sprite.modulate.a = 1.0

func add_impulse(force: Vector2):
	linear_velocity += force
	ensure_minimum_speed()
	
func ensure_minimum_speed():
	var min_speed_threshold = 100.0  # Velocidad mínima permitida

	if linear_velocity.length() < min_speed_threshold:
		# Empujarlo suavemente en la dirección en la que ya se mueve
		linear_velocity = linear_velocity.normalized() * min_speed_threshold
		
