extends CharacterBody2D

@export var speed: float = 850.0
@export var stop_distance: float = 200.0
@export var stop_time: float = 0.5
@export var health: int = 100
@export var enemy_laser_scene: PackedScene
@export var fire_rate: float = 2.0
@export var explosion_scene: PackedScene
@export var slow_duration: float = 2.0
@export var slow_factor: float = 0.5

var direction: Vector2
var start_position: Vector2
var moving: bool = true
var screen_size: Vector2
var current_speed: float

@onready var sprite: Sprite2D = $Sprite2D
@onready var ray_front: RayCast2D = $RaycastFront
@onready var ray_left: RayCast2D = $RaycastLeft
@onready var ray_right: RayCast2D = $RaycastRight

func _ready():
	ray_front = $RaycastFront
	ray_left = $RaycastLeft
	ray_right = $RaycastRight

	ray_front.enabled = true
	ray_left.enabled = true
	ray_right.enabled = true

	screen_size = get_viewport_rect().size
	start_position = global_position
	pick_new_direction()
	start_shooting()
	current_speed = speed

func _physics_process(delta):
	if moving:
		handle_obstacle_avoidance()
		
		var target_angle = direction.angle()
		rotation = lerp_angle(rotation, target_angle, delta * 0.5)
		
		velocity = direction * current_speed
		move_and_slide()
		rotation = lerp_angle(rotation, direction.angle(), delta * 5.0)

	check_screen_wrap()

	if global_position.distance_to(start_position) >= stop_distance:
		stop_movement()

func handle_obstacle_avoidance():
	if ray_front.is_colliding() and ray_front.get_collider().is_in_group("asteroid"):
		var left_clear = not ray_left.is_colliding()
		var right_clear = not ray_right.is_colliding()

		if left_clear:
			direction = (transform.x - transform.y).normalized() # izquierda
		elif right_clear:
			direction = (transform.x + transform.y).normalized() # derecha
		else:
			direction = direction.rotated(PI) # giro emergencia

		start_position = global_position

func stop_movement():
	moving = false
	velocity = Vector2.ZERO
	await get_tree().create_timer(stop_time).timeout
	pick_new_direction()
	start_position = global_position
	moving = true

func pick_new_direction():
	var angle = randf_range(0, TAU)
	direction = Vector2.RIGHT.rotated(angle)

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
		pick_new_direction()
		start_position = global_position

func take_damage(collision_direction: Vector2 = Vector2.ZERO, force: float = 0.0):
	health -= 50
	sprite.modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color(1, 1, 1)

	if collision_direction != Vector2.ZERO and force > 0.0:
		global_position += collision_direction * -force * 0.1

	current_speed = speed * slow_factor
	await get_tree().create_timer(slow_duration).timeout
	current_speed = speed

	if health <= 0:
		die()

func die():
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position
	queue_free()

func start_shooting():
	while true:
		await get_tree().create_timer(fire_rate).timeout
		shoot()

func shoot():
	if not is_instance_valid(get_tree()) or not is_inside_tree():
		return

	var player = get_parent().get_node_or_null("Player")
	if player:
		var enemy_laser = enemy_laser_scene.instantiate() as Area2D
		get_parent().add_child(enemy_laser)

		enemy_laser.global_position = global_position
		var shoot_direction = (player.global_position - global_position).normalized()

		if enemy_laser.has_method("set_direction"):
			enemy_laser.set_direction(shoot_direction, self)
		elif "direction" in enemy_laser:
			enemy_laser.direction = shoot_direction

		enemy_laser.rotation = shoot_direction.angle()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.take_damage()
		die()
