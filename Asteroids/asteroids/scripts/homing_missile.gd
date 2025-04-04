extends Area2D

@export var speed: float = 800.0  # Velocidad del misil
@export var delay_before_launch: float = 0.1  # Tiempo antes de moverse
@export var acceleration: float = 700.0  # Aceleración progresiva
@export var explosion_scene: PackedScene  # Escena de la explosión
@export var flame_scene: PackedScene  # Escena de la llama propulsora
@export var lifetime: float = 3.0  # Tiempo antes de autodestruirse
@export var warning_time: float = 1  # Tiempo de titileo antes de explotar

var velocity: Vector2 = Vector2.ZERO
var target: Node2D = null  # Objetivo del misil
var launched: bool = false  # Indica si ya comenzó a moverse
var direction: Vector2 = Vector2.ZERO  # Dirección del misil
var flame_instance: Node2D = null  # Instancia de la llama
var screen_size: Vector2  # Tamaño de la pantalla
var elapsed_time: float = 0.0  # Contador de vida útil
var flashing: bool = false  # Indica si está titilando

func _ready():
	screen_size = get_viewport_rect().size  # Obtener tamaño de la pantalla
			
	await get_tree().create_timer(delay_before_launch).timeout  # Esperar antes de moverse
	launched = true
	velocity = Vector2.ZERO
	target = find_closest_target()  # Buscar el enemigo o asteroide más cercano
	add_flame()  # Agregar la llama de propulsión

func _process(delta):
	if launched:
		elapsed_time += delta
		
		# Si queda poco tiempo, empezar a titilar en rojo
		if elapsed_time >= lifetime - warning_time and !flashing:
			start_flashing()

		# Si se acaba el tiempo, explotar
		if elapsed_time >= lifetime:
			explode()

		if not is_instance_valid(target):
			target = find_closest_target()

		if target:
			var target_direction = (target.global_position - global_position).normalized()
			direction = direction.lerp(target_direction, 0.6)  # Suavizar el giro
			look_at(global_position - direction * 90)
			rotation += deg_to_rad(-90)

		
		velocity += direction * acceleration * delta  # Aumentar velocidad progresivamente
		global_position += velocity * delta  # Mover en la dirección final
	
		# Teletransportación en los bordes de la pantalla
		check_teleport()

func find_closest_target():
	var potential_targets = get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("asteroid")
	var closest_target = null
	var closest_distance = INF
	
	for target in potential_targets:
		if is_instance_valid(target):
			var distance = global_position.distance_to(target.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_target = target
	
	return closest_target  # Devuelve el objetivo más cercano o null si no hay ninguno

func add_flame():
	if flame_scene:
		flame_instance = flame_scene.instantiate()
		add_child(flame_instance)
		flame_instance.position = Vector2(0, 50)  # Ajustar posición detrás del misil

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

	# Eliminar la llama también
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
		return  # Evita crear múltiples Tweens

	flashing = true
	var tween = create_tween()
	
	# Alternar entre rojo y blanco varias veces en lugar de infinito
	for i in range(5):  # Hace 5 cambios de color
		tween.tween_property(self, "modulate", Color(1, 0, 0), 0.1)
		tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)

	tween.tween_callback(func(): flashing = false)  # Reinicia flashing al finalizar
