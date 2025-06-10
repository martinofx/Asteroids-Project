extends RigidBody2D

@export var health: int = 100
@export var min_speed: float = 1000.0
@export var max_speed: float = 1220.0
@export var explosion_scene: PackedScene
@export var laser_explosion: PackedScene
@export var push_force: float = 500.0
@export var fade_duration: float = 0.1
@export var contact_damage: int = 100  # Daño base de contacto

@export var asteroid_second_1 : PackedScene
@export var asteroid_second_2 : PackedScene
@export var asteroid_second_3 : PackedScene
@export var asteroid_second_4 : PackedScene

@onready var sprite: Sprite2D = $Sprite2D
@onready var screen_size: Vector2 = get_viewport_rect().size

var fading := false
var fade_timer := 0.0
var fade_target_position := Vector2.ZERO
var is_dead := false


func _ready():
	randomize()
	linear_velocity = Vector2.RIGHT.rotated(randf_range(0, TAU)) * randf_range(100, 1150)
	rotation = randf_range(0, TAU)
	angular_velocity = randf_range(-2.5, 2.5)
	sprite.frame = 0
	add_to_group("asteroid")


func _integrate_forces(state):
	check_screen_wrap()
	if linear_velocity.length() > 800.0:
		linear_velocity = linear_velocity.normalized() * 800.0
	angular_velocity = clamp(angular_velocity, -3.0, 3.0)


func _physics_process(delta):
	ensure_minimum_speed()
	linear_velocity *= 0.995
	angular_velocity *= 0.98
	if fading:
		fade_timer += delta
		sprite.modulate.a = 1.0 - (fade_timer / fade_duration)
		if fade_timer >= fade_duration:
			complete_fade_transition()


func _on_body_entered(body):
	if body.is_in_group("laser") or body.is_in_group("enemy_laser"):
		take_damage(10, body.global_position)
		body.queue_free()

	elif body.is_in_group("player"):
		var impact_force = linear_velocity.length()
		var collision_direction = (body.global_position - global_position).normalized()

		if body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position)

		if body.has_method("receive_impact"):
			body.receive_impact(impact_force, collision_direction, self)	

		# Empuja al jugador con fuerza inversa al impacto
		if body is CharacterBody2D:
			var knockback = collision_direction * -impact_force * 0.5
			body.take_damage(contact_damage, global_position)
			body.velocity += knockback
	


func take_damage(damage: int, impact_position := Vector2.ZERO):
	if is_dead:
		return

	health -= damage
	print("Asteroide - Vida restante: ", health)
	set_damage_frame()

	if health <= 0:
		is_dead = true
		explode()


func set_damage_frame():
	var total_frames = sprite.hframes * sprite.vframes
	if total_frames <= 1:
		return
	var damage_index = total_frames - int((health / 100.0) * total_frames)
	damage_index = clamp(damage_index, 0, total_frames - 1)
	sprite.frame = damage_index


func explode():
	get_viewport().get_camera_2d().shake_camera(20.0, 0.7, 6)
	if explosion_scene:
		for i in range(randi_range(8, 12)):
			var explosion = explosion_scene.instantiate()
			get_parent().add_child(explosion)
			explosion.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
			explosion.scale = Vector2.ONE * randf_range(1.5, 3.5)
			await get_tree().create_timer(randf_range(0.05, 0.2)).timeout

	spawn_fragments()
	queue_free()


func spawn_fragments():
	var base_direction = linear_velocity.normalized()
	var directions = []
	for i in range(4):
		directions.append(base_direction.rotated(randf_range(-PI, PI)))

	var fragments = [
		asteroid_second_1.instantiate(),
		asteroid_second_2.instantiate(),
		asteroid_second_3.instantiate(),
		asteroid_second_4.instantiate()
	]

	for i in range(4):
		var frag = fragments[i]
		get_parent().add_child(frag)
		frag.set_collision_layer(0)
		frag.set_collision_mask(0)
		frag.global_position = global_position + directions[i] * randf_range(25, 40)
		frag.linear_velocity = directions[i] * randf_range(500, 1000)
		frag.angular_velocity = randf_range(-5, 5)
		frag.call_deferred("set_collision_layer", 1)
		frag.call_deferred("set_collision_mask", 1)


func check_screen_wrap():
	var pos = global_position
	var size = sprite.texture.get_size() * sprite.scale
	var half_x = size.x * 0.2
	var half_y = size.y * 0.4
	var crossed = false

	if pos.x < -half_x:
		pos.x = screen_size.x + half_x
		crossed = true
	elif pos.x > screen_size.x + half_x:
		pos.x = -half_x
		crossed = true

	if pos.y < -half_y:
		pos.y = screen_size.y + half_y
		crossed = true
	elif pos.y > screen_size.y + half_y:
		pos.y = -half_y
		crossed = true

	if crossed:
		global_position = pos
		ensure_minimum_speed()


func ensure_minimum_speed():
	if linear_velocity.length() < 100.0:
		linear_velocity = linear_velocity.normalized() * 100.0


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


func _on_detector_area_body_entered(body: Node2D) -> void:
	
	if body.is_in_group("player"):
		print("COLISIÓN DETECTADA CON PLAYER")
		
		var impact_force = linear_velocity.length()
		var direction = (body.global_position - global_position).normalized()

		if body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position)

		if body.has_method("receive_impact"):
			body.receive_impact(impact_force, direction, self)
