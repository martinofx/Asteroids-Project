extends Area2D

@export var speed: float = 2700.0  # Velocidad final del misil
@export var reverse_speed: float = 50.0  # Velocidad inicial hacia atrás
@export var delay_before_launch: float = 0.5  # Tiempo antes de la propulsión
@export var acceleration: float = 1500.0  # Aceleración del misil
@export var explosion_small_scene: PackedScene  # Escena de la explosión pequeña
@export var flame_scene: PackedScene  # Escena de la llama propulsora
@export var lifetime: float = 2.5  # Tiempo antes de autodestruirse
@export var blink_time: float = 0.5  # Tiempo antes de que empiece a titilar
@export var collision_grace_period: float = 1  # Tiempo antes de activar la colisión con el player
@export var damage: int = 100  # 

@onready var smoke_trail: CPUParticles2D = $SmokeTrail

var direction: Vector2 = Vector2.ZERO  # Dirección final del misil
var velocity: Vector2 = Vector2.ZERO  # Velocidad del misil
var launched: bool = false  # Indica si el misil ya comenzó a moverse
var flame_instance: Node2D  # Instancia de la llama propulsora
var screen_size: Vector2  # Tamaño de la pantalla
var blinking: bool = false  # Indica si está titilando
var can_hit_player: bool = false  # Controla si puede impactar al player


func _ready():
	# **Obtener el tamaño de la pantalla para la teletransportación**
	screen_size = get_viewport_rect().size
	
	# **Calcular dirección opuesta a la rotación de la nave**
	direction = Vector2.UP.rotated(rotation)

	# **Colocar el misil en el centro de la nave**
	global_position = get_parent().global_position
	
	# **Salida inicial hacia atrás**
	velocity = -direction * reverse_speed  

	# **Iniciar temporizador de autodestrucción**
	start_lifetime_timers()

	await get_tree().create_timer(delay_before_launch).timeout  # Espera antes de lanzarse
	
	# **Ahora el misil avanza en la dirección de la nave**
	launched = true
	velocity = Vector2.ZERO  # Reiniciar velocidad antes de acelerar
	add_flame()  # Enciende la llama

	# **Activar colisión con el player después del tiempo de gracia**
	await get_tree().create_timer(collision_grace_period).timeout
	can_hit_player = true  # Ahora puede golpear al player

	
func _process(delta: float) -> void:
	if launched:
		velocity += direction * acceleration * delta  # Aumenta velocidad progresivamente
	global_position += velocity * delta  # Movimiento del misil
	
	# **Teletransporte al cruzar los bordes de la pantalla**
	if global_position.x < 0:
		global_position.x = screen_size.x
	elif global_position.x > screen_size.x:
		global_position.x = 0

	if global_position.y < 0:
		global_position.y = screen_size.y
	elif global_position.y > screen_size.y:
		global_position.y = 0

func add_flame():
	if flame_scene:
		flame_instance = flame_scene.instantiate()
		add_child(flame_instance)
		flame_instance.position = Vector2(0, 70)  # Ajustar posición detrás del misil

func _on_body_entered(body):
	if body.is_in_group("enemy") or body.is_in_group("asteroid"):  # Siempre puede golpear enemigos y asteroides
		body.take_damage(damage)
		explode()
	elif body.is_in_group("player") and can_hit_player:  # Solo afecta al player después del tiempo de gracia
		body.take_damage(damage)
		explode()
		
func _on_area_entered(area):
	if area.is_in_group("enemy") or area.is_in_group("asteroid"):
		area.take_damage(damage)
		explode()

func explode():
	if explosion_small_scene:
		var explosion = explosion_small_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position
		explosion.rotation = direction.angle()
		
	queue_free()  # Destruye el misil

func start_lifetime_timers():
	# **Comenzar el temporizador de parpadeo antes de explotar**
	await get_tree().create_timer(lifetime - blink_time).timeout  
	blinking = true
	start_blinking()

	# **Después del tiempo de vida total, explota**
	await get_tree().create_timer(blink_time).timeout
	explode()

func start_blinking():
	var blink_timer = 0.1  # Tiempo de cada parpadeo
	while blinking:
		modulate = Color(1, 0, 0)  # Rojo
		await get_tree().create_timer(blink_timer).timeout
		modulate = Color(1, 1, 1)  # Normal
		await get_tree().create_timer(blink_timer).timeout
