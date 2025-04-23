extends CharacterBody2D

@export var fire_rate: float = 2.0
@export var health: int = 100
@export var target_radius: float = 50.0
@export var attack_range: float = 300.0
@export var current_speed := 150.0
@export var speed: float = 850.0
@export var dash_speed: float = 1800.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 2.0
@export var slow_duration: float = 2.0
@export var slow_factor: float = 0.5
@export var obstacle_detection_distance: float = 200.0
@export var enemy_laser_scene: PackedScene
@export var explosion_scene: PackedScene
@export var stop_time: float = 1.0

var can_dash: bool = true
var dash_timer: Timer
var direction: Vector2 = Vector2.ZERO
var moving: bool = true
var screen_size: Vector2
var target_position: Vector2
var is_evading := false
var evade_direction := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var raycast_front: RayCast2D = $RaycastFront
@onready var raycast_left: RayCast2D = $RaycastLeft
@onready var raycast_right: RayCast2D = $RaycastRight

func _ready():
	screen_size = get_viewport_rect().size
	dash_timer = Timer.new()
	dash_timer.one_shot = true
	add_child(dash_timer)
	pick_new_target_position()
	start_shooting()
	current_speed = speed

func _physics_process(delta):
	var player = get_parent().get_node_or_null("Player")
	if not player:
		return

	if can_dash and (raycast_front.is_colliding() or is_projectile_nearby()):
		do_dash()

	var to_target = target_position - global_position
	var distance_to_target = to_target.length()

	if moving:
		if distance_to_target < target_radius:
			stop_movement()
		else:
			var direction = to_target.normalized()
			direction = await handle_obstacle_avoidance(direction)
			velocity = direction * current_speed
			move_and_slide()

			if direction != Vector2.ZERO:
				rotation = lerp_angle(rotation, direction.angle(), delta * 5.0)
	else:
		velocity = Vector2.ZERO

	check_screen_wrap()

# Función para realizar el dash
func do_dash():
	can_dash = false
	dash_timer.start(dash_cooldown)

	var dash_direction: Vector2

	# Prioridad de esquive lateral
	if not raycast_left.is_colliding():
		dash_direction = -transform.x  # izquierda
	elif not raycast_right.is_colliding():
		dash_direction = transform.x  # derecha
	else:
		# Último recurso: dirección aleatoria
		dash_direction = Vector2.RIGHT.rotated(randf() * PI * 2.0)

	var original_speed = current_speed
	current_speed = dash_speed
	direction = dash_direction

	await get_tree().create_timer(dash_duration).timeout
	current_speed = original_speed
	can_dash = true

# Verificar si hay proyectiles cerca
func is_projectile_nearby() -> bool:
	var area = $DetectionArea
	for body in area.get_overlapping_bodies():
		if body.is_in_group("laser"):
			if global_position.distance_to(body.global_position) < obstacle_detection_distance:
				return true
	return false

# Establecer una nueva posición objetivo
func pick_new_target_position():
	var player = get_parent().get_node_or_null("Player")
	if not player:
		return
	var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(attack_range * 0.5, attack_range)
	target_position = player.global_position + offset

# Detener el movimiento
func stop_movement():
	moving = false
	velocity = Vector2.ZERO
	await get_tree().create_timer(stop_time).timeout
	pick_new_target_position()
	moving = true

# Manejo de esquiva de obstáculos
func handle_obstacle_avoidance(base_direction: Vector2) -> Vector2:
	if is_evading:
		return evade_direction

	if raycast_front.is_colliding():
		var left_clear = not raycast_left.is_colliding()
		var right_clear = not raycast_right.is_colliding()

		if left_clear:
			evade_direction = (transform.x - transform.y).normalized()
		elif right_clear:
			evade_direction = (transform.x + transform.y).normalized()
		else:
			evade_direction = base_direction.rotated(PI)  # dar media vuelta

		is_evading = true
		await get_tree().create_timer(0.5).timeout  # duración del esquive
		is_evading = false
		evade_direction = Vector2.ZERO

	return base_direction

# Revisar si el objeto cruza la pantalla (wrap around)
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
		pick_new_target_position()

# Recibir daño
func take_damage(collision_direction: Vector2 = Vector2.ZERO, force: float = 0.0):
	health -= 50
	sprite.modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color(1, 1, 1)
	
	if health <= 0:
		die()

	if can_dash:
		do_dash()

	if collision_direction != Vector2.ZERO and force > 0.0:
		global_position += collision_direction * -force * 0.1

	current_speed = speed * slow_factor
	await get_tree().create_timer(slow_duration).timeout
	current_speed = speed

# Muerte del enemigo
func die():
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position
	queue_free()

# Iniciar disparo en bucle
func start_shooting():
	call_deferred("_shoot_loop")

# Función de disparo en bucle
func _shoot_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(fire_rate).timeout
		if randi() % 2 == 0 or is_player_close():
			shoot()

# Verificar si el jugador está cerca
func is_player_close() -> bool:
	var player = get_parent().get_node_or_null("Player")
	return player and global_position.distance_to(player.global_position) < 500

# Realizar disparo
func shoot():
	if not is_instance_valid(get_tree()) or not is_inside_tree():
		return

	var player = get_parent().get_node_or_null("Player")
	if not player:
		return

	var distance = global_position.distance_to(player.global_position)
	if distance > 1000 and randi() % 5 != 0:
		return

	var enemy_laser = enemy_laser_scene.instantiate() as Area2D
	get_parent().add_child(enemy_laser)

	enemy_laser.global_position = global_position
	var shoot_direction = (player.global_position - global_position).normalized()

	if enemy_laser.has_method("set_direction"):
		enemy_laser.set_direction(shoot_direction, self)
	elif "direction" in enemy_laser:
		enemy_laser.direction = shoot_direction

	enemy_laser.rotation = shoot_direction.angle()

# Detectar cuando entra en contacto con el jugador
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.take_damage()
		die()

# Dibujar el objetivo de la siguiente posición
func _draw():
	draw_line(Vector2.ZERO, (target_position - global_position).normalized() * 50, Color.RED, 2)

func _process(_delta):
	queue_redraw()
