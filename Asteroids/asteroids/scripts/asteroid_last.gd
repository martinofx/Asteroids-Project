extends RigidBody2D  # Cambio de CharacterBody2D a Rigidbody2D para física realista

@export var health: int = 100  # Vida del asteroide
@export var min_speed: float = 500.0  # Velocidad mínima
@export var max_speed: float = 800.0  # Velocidad máxima
@export var explosion_scene: PackedScene  # Escena de la explosión
@export var laser_explosion: PackedScene  # Escena del impacto del láser
@export var push_force: float = 500.0  # Fuerza con la que empuja a otros objetos
@export var fade_duration: float = 0.1  # Duración del desvanecimiento

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

	health -= 100
	print("Vida restante: ", health)  
	set_damage_frame()	

	if health <= 0:
		is_dead = true
		print("Ejecutando explode()")
		explode()	

	if health <= 0:
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
		var explosion_count = randi_range(1, 3)  # Cantidad aleatoria de explosiones
		for i in range(explosion_count):
			var explosion = explosion_scene.instantiate()
			if explosion:
				get_parent().add_child(explosion)
				
				# Posición aleatoria cerca del asteroide
				var random_offset = Vector2(randf_range(-20, 10), randf_range(-20, 10))
				explosion.global_position = global_position + random_offset
				
				# Escala aleatoria entre 0.5 y 1.5 veces el tamaño normal
				var random_scale = randf_range(0.7, 1)
				explosion.scale = Vector2(random_scale, random_scale)

				# Agregar un pequeño retraso entre explosiones
				await get_tree().create_timer(randf_range(0.05, 0.2)).timeout

		print("¡Explosión múltiple generada!")

	else:
		print("Error: explosion_scene es null")
	
	
	# **Eliminar el asteroide grande**
	queue_free()
	
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
		
