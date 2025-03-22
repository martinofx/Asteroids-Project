extends Area2D

@export var speed: float = 1700.0  # Velocidad final del misil
@export var reverse_speed: float = 200.0  # Velocidad inicial hacia atrás
@export var delay_before_launch: float = 0.2  # Tiempo antes de la propulsión
@export var acceleration: float = 1000.0  # Aceleración del misil
@export var explosion_small_scene: PackedScene  # Escena de la explosión pequeña
@export var flame_scene: PackedScene  # Escena de la llama propulsora

var direction: Vector2 = Vector2.ZERO  # Dirección final del misil
var velocity: Vector2 = Vector2.ZERO  # Velocidad del misil
var launched: bool = false  # Indica si el misil ya comenzó a moverse
var flame_instance: Node2D  # Instancia de la llama propulsora

func _ready():
	# **Calcular dirección opuesta a la rotación de la nave**
	direction = Vector2.ZERO.rotated(rotation)   # Dirección hacia donde apunta la nave
	var reverse_direction = -direction  # **Dirección hacia atrás**
	
	# **Colocar el misil detrás de la nave según su rotación**
	global_position -= direction * 500# 50 píxeles detrás de la nave
	
	# **Salida inicial exactamente hacia atrás**
	velocity = reverse_direction * reverse_speed  

	await get_tree().create_timer(delay_before_launch).timeout  # Espera antes de lanzarse
	
	# **Ahora el misil avanza en la dirección de la nave**
	launched = true
	velocity = Vector2.ZERO  # Reiniciar velocidad antes de acelerar
	add_flame()  # Enciende la llama

func _process(delta: float) -> void:
	if launched:
		velocity += direction * acceleration * delta  # Aumenta velocidad progresivamente
	global_position += velocity * delta  # Movimiento del misil

func add_flame():
	if flame_scene:
		flame_instance = flame_scene.instantiate()
		add_child(flame_instance)
		flame_instance.position = Vector2(0, 20)  # Ajustar posición detrás del misil

func _on_body_entered(body):
	if body.is_in_group("enemy") or body.is_in_group("asteroid"):
		body.take_damage(global_position)  # Aplica daño en la posición de impacto
		explode()

func _on_area_entered(area):
	if area.is_in_group("enemy") or area.is_in_group("asteroid"):
		area.take_damage()
		explode()

func explode():
	if explosion_small_scene:
		var explosion = explosion_small_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position
		
	queue_free()  # Destruye el misil

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
