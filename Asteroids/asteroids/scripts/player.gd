extends CharacterBody2D

@export var max_speed: float = 300.0  # Velocidad máxima
@export var acceleration: float = 200.0  # Aceleración al presionar avanzar
@export var angular_speed: float = 2.0  # Velocidad de rotación
@export var friction: float = 0.98  # Fricción al soltar avanzar
@export var explosion_scene: PackedScene  # Asigna aquí la escena de la explosión
@export var laser_scene: PackedScene  # Asigna aquí la escena del láser
@export var missile_scene: PackedScene  # Asigna aquí la escena del misil
@export var homing_missile_scene: PackedScene  # Asigna aquí la escena del misil perseguidor
@export var fire_rate: float = 0.3  # Tiempo entre disparos
@export var fade_duration: float = 0.5  # Duración del desvanecimiento
@export var raygun_scene: PackedScene
@onready var laser_beam = $LaserBeam2D  # Ajustá el path si lo cambiaste

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
var energy_beam: Area2D
var beam_active = false
var raygun_instance = null
var beam_cooldown := false  # 🔹 Evita disparar en bucle


@onready var sprite: Sprite2D = $Sprite2D  # Sprite de la nave
@onready var flame_center: Node2D = $Flame_Center
@onready var flame_left: Node2D = $Flame_Left
@onready var flame_right: Node2D = $Flame_Right
@onready var beam_timer := $BeamTimer  # Timer agregado en el editor

func _ready() -> void:
	update_screen_size()
	get_viewport().connect("size_changed", Callable(self, "update_screen_size"))
	flame_center.visible = false
	flame_left.visible = false
	flame_right.visible = false	
	
	beam_timer = Timer.new()
	beam_timer.wait_time = 1.5  # 🔹 Duración del rayo
	beam_timer.one_shot = true  # 🔹 Se activa una sola vez por disparo
	beam_timer.timeout.connect(_on_beam_timeout)
	add_child(beam_timer)
	
	add_to_group("player")

func update_screen_size() -> void:
	screen_size = get_viewport_rect().size

func _physics_process(delta: float) -> void:
	var moving = false
	var rotating_left = false
	var rotating_right = false

	# Rotación de la nave
	if Input.is_action_pressed("rotate_left"):
		rotation -= angular_speed * delta
		rotating_left = true
	if Input.is_action_pressed("rotate_right"):
		rotation += angular_speed * delta
		rotating_right = true

	# Movimiento hacia adelante
	if Input.is_action_pressed("move_forward"):
		velocity += Vector2.UP.rotated(rotation) * acceleration * delta
		velocity = velocity.limit_length(max_speed)
		moving = true
	else:
		velocity *= friction

	move_and_slide()
	handle_flames(moving, rotating_left, rotating_right)

	if fading:
		fade_timer += delta
		sprite.modulate.a = 1.0 - (fade_timer / fade_duration)
		if fade_timer >= fade_duration:
			complete_fade_transition()
		
func receive_impact(force: float, collision_direction: Vector2, asteroid: RigidBody2D):
	take_damage(25)  

	# Aplicar un rebote proporcional al impacto
	var rebound_force = collision_direction * -force * 5  
	velocity += rebound_force  

	# Si la nave se queda atascada, darle una velocidad mínima
	if velocity.length() < 50:
		velocity = collision_direction * -100  

	# Aplicar una rotación extra si el impacto es fuerte
	if force > 100:
		rotation += randf_range(-0.5, 0.5) * force * 0.01  

	# **Empujar el asteroide si está detenido o muy lento**
	if asteroid.linear_velocity.length() < 30:
		asteroid.linear_velocity += collision_direction * force * 2  

	# **Deshabilitar los controles momentáneamente**
	disable_controls(0.3)

func handle_flames(moving: bool, rotating_left: bool, rotating_right: bool):
	flame_center.visible = moving
	flame_left.visible = rotating_right
	flame_right.visible = rotating_left

	check_screen_wrap()

func _input(event):
		
	if event.is_action_pressed("shoot") and can_shoot:
		shoot()
		
	if event.is_action_pressed("missile_small") and can_shoot:
		fire_missile()
	
	if event.is_action_pressed("homing_missile") and can_shoot:
		fire_homing_missile()
		
	if event.is_action_pressed("shoot_raygun") and not beam_active and not beam_cooldown:
		toggle_beam(true)

	elif event.is_action_released("shoot_raygun"):
		toggle_beam(false)
		beam_cooldown = false  # 🔹 Resetear cooldown
		# 🔹 Reseteamos el Timer para permitir otro disparo completo
		beam_timer.stop()
		
	if laser_beam == null:
		return  # Evita crash si no está bien conectado

	if event.is_action_pressed("laser_beam"):
		laser_beam.is_casting = true
	elif event.is_action_released("laser_beam"):
		laser_beam.is_casting = false

func toggle_beam(active: bool):
	if active and not beam_active:
		beam_active = true
		beam_cooldown = true  # 🔹 Activa el cooldown
		energy_beam = raygun_scene.instantiate()
		add_child(energy_beam)
		energy_beam.activate()

		# 🔹 Inicia el Timer para desactivar el rayo
		beam_timer.start()

	elif not active and beam_active:
		beam_active = false
		energy_beam.deactivate()
		energy_beam.queue_free()

func _on_beam_timeout():
	toggle_beam(false)  # 🔹 Se apaga el rayo cuando el Timer termina
	
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
	
func fire_missile():
	if missile_scene:
		for i in range(3):  # Disparar 3 misiles en sucesión
			var missile = missile_scene.instantiate()			
			get_parent().add_child(missile)
			
			var offset_distance = -30  
			var shoot_position = global_position + Vector2.UP.rotated(rotation) * offset_distance

			missile.global_position = shoot_position
			missile.direction = Vector2.UP.rotated(rotation)
			missile.rotation = rotation
			
			await get_tree().create_timer(0.20).timeout  # Pequeña pausa entre misiles
			
func fire_homing_missile():
	if homing_missile_scene:
		var num_missiles = 4
		var spread_angle = deg_to_rad(90)  # Ángulo total de dispersión (ej: 30 grados)
		var start_angle = -spread_angle / 2  # Comienza a la izquierda

		for i in range(num_missiles):
			var missile = homing_missile_scene.instantiate()
			get_parent().add_child(missile)

			var offset_distance = -50
			var angle = rotation + start_angle + (spread_angle / (num_missiles - 1)) * i  # Espaciado angular

			var shoot_position = global_position + Vector2.UP.rotated(angle) * offset_distance
			missile.global_position = shoot_position
			missile.direction = Vector2.UP.rotated(angle)
			missile.rotation = angle

func _on_body_entered(body):
	if body.is_in_group("enemy"):  
		body.take_damage()  
		queue_free()  

	elif body.is_in_group("asteroid"):  
		var impact_force = body.linear_velocity.length()  
		var impact_direction = (global_position - body.global_position).normalized()
		receive_impact(impact_force, impact_direction, body)
		take_damage(body.global_position)  # Llama a la función de daño
		body.take_damage() 

func take_damage(_impact_position = null):
	health -= 100
	sprite.modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color(1, 1, 1)  
	
	if health <= 0:
		die()
		
func _on_damage_area_area_entered(area):
	if area.is_in_group("asteroid"):
		take_damage(area.global_position)  # Llama a la función de daño correctamente

func die():
	
	get_viewport().get_camera_2d().shake_camera(50.0, 0.7, 6)
	
	if explosion_scene:
		var explosion_count = randi_range(5, 10)  # Cantidad aleatoria de explosiones
		for i in range(explosion_count):
			var explosion = explosion_scene.instantiate()
			if explosion:
				get_parent().add_child(explosion)
				
				# Posición aleatoria cerca del asteroide
				var random_offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
				explosion.global_position = global_position + random_offset
				
				# Escala aleatoria entre 0.5 y 1.5 veces el tamaño normal
				var random_scale = randf_range(0.9,1.5 )
				explosion.scale = Vector2(random_scale, random_scale)

				# Agregar un pequeño retraso entre explosiones
				await get_tree().create_timer(randf_range(0.05, 0.1)).timeout
				
	queue_free()
	#get_node("/root/Game").restart_game()

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
	
func disable_controls(duration):
	controls_disabled = true
	await get_tree().create_timer(duration).timeout
	controls_disabled = false

func apply_impulse(force: Vector2):
	velocity += force  # ✅ Usa velocity, que es la correcta en CharacterBody2D

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("asteroid"):
		take_damage(area.global_position)  # Aplica daño a la nave.
