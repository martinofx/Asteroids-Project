extends CharacterBody2D

@export var max_speed: float = 300.0  # Velocidad máxima
@export var acceleration: float = 200.0  # Aceleración al presionar avanzar
@export var angular_speed: float = 2.0  # Velocidad de rotación
@export var friction: float = 0.98  # Fricción al soltar avanzar
@export var explosion_scene: PackedScene  # Asigna aquí la escena de la explosión
@export var laser_scene: PackedScene  # Asigna aquí la escena del láser
@export var missile_scene: PackedScene  # Asigna aquí la escena del misil
@export var fire_rate: float = 0.3  # Tiempo entre disparos
@export var fade_duration: float = 0.5  # Duración del desvanecimiento
@export var weapon_scenes: Array[PackedScene]  # Lista de armas disponibles

var screen_size: Vector2  # Tamaño de la pantalla
var can_shoot: bool = true  # Control de cooldown de disparo
var fading: bool = false
var fade_timer: float = 0.0
var fade_target_position: Vector2
var health: float = 100
var controls_disabled = false
var current_weapon_index: int = 0  # Índice del arma activa
var current_weapon: Node  # Referencia al arma actual
var weapon_ui: Control

@onready var sprite: Sprite2D = $Sprite2D  # Sprite de la nave
@onready var flame_center: Node2D = $Flame_Center
@onready var flame_left: Node2D = $Flame_Left
@onready var flame_right: Node2D = $Flame_Right

func _ready() -> void:
	update_screen_size()
	get_viewport().connect("size_changed", Callable(self, "update_screen_size"))
	flame_center.visible = false
	flame_left.visible = false
	flame_right.visible = false
	weapon_ui = get_node("/Game/WeaponUI")  # Ajusta la ruta según la estructura de tu juego
	add_to_group("player")

	# Verificar que hay armas disponibles antes de cambiar
	if weapon_scenes.size() > 0:
		switch_weapon(0)
	else:
		print("Error: weapon_scenes está vacío. Asegúrate de asignar armas en el inspector.")

func update_screen_size() -> void:
	screen_size = get_viewport_rect().size

func _physics_process(delta: float) -> void:
	var moving = false
	var rotating_left = false
	var rotating_right = false

	if Input.is_action_pressed("rotate_left"):
		rotation -= angular_speed * delta
		rotating_left = true
	if Input.is_action_pressed("rotate_right"):
		rotation += angular_speed * delta
		rotating_right = true

	if Input.is_action_pressed("move_forward"):
		velocity += Vector2.UP.rotated(rotation) * acceleration * delta
		velocity = velocity.limit_length(max_speed)
		moving = true
	else:
		velocity *= friction

	move_and_slide()
	handle_flames(moving, rotating_left, rotating_right)
	check_screen_wrap()

	if fading:
		fade_timer += delta
		sprite.modulate.a = 1.0 - (fade_timer / fade_duration)
		if fade_timer >= fade_duration:
			complete_fade_transition()

func _input(event):
	if event.is_action_pressed("shoot") and can_shoot:
		shoot()
	
	if event.is_action_pressed("weapon_next"):
		cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		cycle_weapon(-1)

func cycle_weapon(direction: int):
	current_weapon_index = (current_weapon_index + direction) % weapon_scenes.size()
	switch_weapon(current_weapon_index)

func switch_weapon(index: int):
	if current_weapon:
		current_weapon.queue_free()
	current_weapon = weapon_scenes[index].instantiate()
	add_child(current_weapon)
	update_weapon_ui()

func update_weapon_ui():
	if weapon_ui:
		weapon_ui.update_weapon_icon(current_weapon_index)

func shoot():
	can_shoot = false  
	var laser = laser_scene.instantiate() as Area2D
	get_parent().add_child(laser)  
	var offset_distance = 50  
	var shoot_position = global_position + Vector2.UP.rotated(rotation) * offset_distance
	laser.global_position = shoot_position
	laser.direction = Vector2.UP.rotated(rotation)
	laser.rotation = rotation
	get_tree().create_timer(fire_rate).timeout.connect(func(): can_shoot = true)

func handle_flames(moving: bool, rotating_left: bool, rotating_right: bool):
	flame_center.visible = moving
	flame_left.visible = rotating_right
	flame_right.visible = rotating_left

func check_screen_wrap():
	if fading:
		return  
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
		start_fade_out(new_position)

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

func receive_impact(force: float, collision_direction: Vector2, asteroid: RigidBody2D):
	take_damage(25)  
	var rebound_force = collision_direction * -force * 5  
	velocity += rebound_force  
	if velocity.length() < 50:
		velocity = collision_direction * -100  
	if force > 100:
		rotation += randf_range(-0.5, 0.5) * force * 0.01  
	if asteroid.linear_velocity.length() < 30:
		asteroid.linear_velocity += collision_direction * force * 2  
	disable_controls(0.3)

func disable_controls(duration):
	controls_disabled = true
	await get_tree().create_timer(duration).timeout
	controls_disabled = false

func take_damage(amount: int = 10):
	health -= amount
	sprite.modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color(1, 1, 1)  
	if health <= 0:
		die()

func die():
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position
	queue_free()
