extends CharacterBody2D

@export var health: int = 100  # Vida del asteroide
@export var min_speed: float = 50.0  # Velocidad mínima
@export var max_speed: float = 150.0  # Velocidad máxima
@export var explosion_scene: PackedScene  # Escena de la explosión
@export var laser_explosion: PackedScene  # Escena del impacto del láser

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var screen_size: Vector2 = get_viewport_rect().size  # Tamaño de la pantalla

func _ready():
	# Dar velocidad inicial
	var random_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var random_speed = randf_range(min_speed, max_speed)
	velocity = random_direction * random_speed
	
	animation_player.play("healthy")

func _physics_process(delta):
	move_and_slide()
	check_screen_wrap()

func _on_body_entered(body):
	print("Colisión detectada con:", body.name)  # Debug
	if body.is_in_group("laser") or body.is_in_group("enemy_laser"):  
		take_damage(body.global_position)  # 🔥 Pasa la posición del impacto
		body.queue_free()

func take_damage(impact_position):
	health -= 50
	print("Vida restante:", health)  # Debug

	if health <= 50 and health > 0:
		animation_player.play("fractured") 

	if health <= 0:
		explode()

func explode():
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		if explosion == null:
			print("Error: explosion_scene no pudo instanciarse.")  # 🚨 Verificar si la escena es válida
			return

		get_parent().add_child(explosion)
		explosion.global_position = global_position  
		print("¡Explosión instanciada en:", explosion.global_position, "!")

	set_deferred("freeze", true)  
	set_deferred("collision_layer", 0)  
	set_deferred("collision_mask", 0)

	await get_tree().create_timer(0.2).timeout  

	queue_free()

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
