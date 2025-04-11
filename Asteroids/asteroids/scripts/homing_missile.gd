extends Area2D

@export var speed: float = 800.0  # Velocidad del misil
@export var delay_before_launch: float = 0.01  # Tiempo antes de moverse
@export var acceleration: float = 700.0  # Aceleración progresiva
@export var explosion_scene: PackedScene  # Escena de la explosión
@export var flame_scene: PackedScene  # Escena de la llama propulsora
@export var lifetime: float = 3.0  # Tiempo antes de autodestruirse
@export var warning_time: float = 1.0  # Tiempo de titileo antes de explotar
@export var homing_delay: float = 0.5  # Tiempo antes de empezar a perseguir

var velocity: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO  # Dirección inicial, luego homing
var target: Node2D = null
var launched: bool = false
var flame_instance: Node2D = null
var screen_size: Vector2
var elapsed_time: float = 0.0
var flashing: bool = false
var homing_timer: float = 0.0  # Tiempo acumulado antes de activar homing

func _ready():
	screen_size = get_viewport_rect().size

	await get_tree().create_timer(delay_before_launch).timeout
	launched = true
	velocity = Vector2.ZERO
	target = find_closest_target()
	add_flame()

func _process(delta):
	if launched:
		elapsed_time += delta
		homing_timer += delta

		# Explosión por tiempo
		if elapsed_time >= lifetime - warning_time and !flashing:
			start_flashing()
		if elapsed_time >= lifetime:
			explode()

		# Si el objetivo actual desapareció, buscar otro
		if not is_instance_valid(target):
			target = find_closest_target()

		# HOMING después del delay
		if homing_timer >= homing_delay and target:
			var target_direction = (target.global_position - global_position).normalized()
			direction = direction.lerp(target_direction, 0.6)
			look_at(global_position - direction * 90)
			rotation += deg_to_rad(-90)

		# Movimiento progresivo
		velocity += direction * acceleration * delta
		global_position += velocity * delta

		check_teleport()

func find_closest_target():
	var potential_targets = get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("asteroid")
	var closest_target = null
	var closest_distance = INF

	for t in potential_targets:
		if is_instance_valid(t):
			var distance = global_position.distance_to(t.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_target = t

	return closest_target

func add_flame():
	if flame_scene:
		flame_instance = flame_scene.instantiate()
		add_child(flame_instance)
		flame_instance.position = Vector2(0, 50)

func _on_body_entered(body):
	if body.is_in_group("enemy") or body.is_in_group("asteroid"):
		body.take_damage(global_position)
		explode()

func _on_area_entered(area):
	if area.is_in_group("enemy") or area.is_in_group("asteroid"):
		area.take_damage()
		explode()

func explode():
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position

	if flame_instance:
		flame_instance.queue_free()

	queue_free()

func check_teleport():
	if global_position.x < 0:
		global_position.x = screen_size.x
	elif global_position.x > screen_size.x:
		global_position.x = 0

	if global_position.y < 0:
		global_position.y = screen_size.y
	elif global_position.y > screen_size.y:
		global_position.y = 0

func start_flashing():
	if flashing:
		return

	flashing = true
	var tween = create_tween()
	for i in range(5):
		tween.tween_property(self, "modulate", Color(1, 0, 0), 0.1)
		tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)
	tween.tween_callback(func(): flashing = false)
