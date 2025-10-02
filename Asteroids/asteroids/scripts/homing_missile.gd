extends Area2D

# --- Movimiento / Homing ---
@export var speed: float = 800.0                    # (Opcional) velocidad tope
@export var acceleration: float = 700.0             # aceleración progresiva
@export var homing_delay: float = 0.5               # tiempo antes de empezar a perseguir
@export var homing_strength: float = 6.0            # qué tan rápido gira hacia el objetivo (lerp)

# --- Vida útil / VFX ---
@export var delay_before_launch: float = 0.01       # tiempo antes de moverse
@export var lifetime: float = 3.0                   # segundos antes de autodestruirse
@export var warning_time: float = 1.0               # parpadeo previo a explotar
@export var explosion_scene: PackedScene            # escena de la explosión
@export var flame_scene: PackedScene                # escena de la llama propulsora

# --- Daño ---
@export var damage: int = 40                        # DAÑO AL IMPACTO (ajustalo a gusto)

# --- Orientación del sprite ---
# Si tu sprite "apunta" hacia ARRIBA en reposo, usá -90° (por defecto).
# Si tu sprite "apunta" hacia la DERECHA, poné 0.
@export var sprite_forward_angle_offset_deg: float = -90.0

# --- Estado ---
var velocity: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO    # se inicializa al lanzar; luego homing
var target: Node2D = null
var launched: bool = false
var flame_instance: Node2D = null
var screen_size: Vector2
var elapsed_time: float = 0.0
var flashing: bool = false
var homing_timer: float = 0.0

func _ready():
	screen_size = get_viewport_rect().size

	await get_tree().create_timer(delay_before_launch).timeout
	launched = true
	velocity = Vector2.ZERO

	# Dirección inicial: toma la orientación actual del nodo
	var offset := deg_to_rad(sprite_forward_angle_offset_deg)
	direction = Vector2.RIGHT.rotated(rotation + offset).normalized()

	target = find_closest_target()
	add_flame()

func _process(delta):
	if !launched:
		return

	elapsed_time += delta
	homing_timer += delta

	# Explosión por tiempo
	if elapsed_time >= lifetime - warning_time and !flashing:
		start_flashing()
	if elapsed_time >= lifetime:
		explode()
		return

	# Si el objetivo actual desapareció, buscar otro
	if not is_instance_valid(target):
		target = find_closest_target()

	# HOMING tras el delay
	if homing_timer >= homing_delay and target:
		var desired := (target.global_position - global_position).normalized()
		# Lerp suave controlado por homing_strength
		direction = direction.lerp(desired, clamp(homing_strength * delta, 0.0, 1.0)).normalized()

	# Movimiento progresivo + clamp a velocidad tope (opcional)
	velocity += direction * acceleration * delta
	if speed > 0.0 and velocity.length() > speed:
		velocity = velocity.normalized() * speed

	global_position += velocity * delta

	# Orientar el sprite según la velocidad real
	if velocity.length() > 0.01:
		rotation = velocity.angle() - deg_to_rad(sprite_forward_angle_offset_deg)

	check_teleport()

func find_closest_target():
	var potential_targets = get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("asteroid")
	var closest_target = null
	var closest_distance = INF

	for t in potential_targets:
		if is_instance_valid(t) and t is Node2D:
			var distance = global_position.distance_to(t.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_target = t

	return closest_target

func add_flame():
	if flame_scene:
		flame_instance = flame_scene.instantiate()
		add_child(flame_instance)
		# Colocá la llama detrás del misil (ajustá según tu sprite)
		flame_instance.position = Vector2(0, 30)

func _on_body_entered(body):
	if body.is_in_group("enemy") or body.is_in_group("asteroid"):
		_apply_damage(body, damage, global_position)
		explode()

func _on_area_entered(area):
	if area.is_in_group("enemy") or area.is_in_group("asteroid"):
		_apply_damage(area, damage, global_position)
		explode()

func _apply_damage(target_obj: Object, amount: int, hit_point: Vector2) -> void:
	if not (target_obj and target_obj.has_method("take_damage")):
		return

	# Detecta si el método acepta (amount, hit_point) o solo (amount)
	var accepts_two := false
	for m in target_obj.get_method_list():
		if m.name == "take_damage":
			if "args" in m and m.args is Array and m.args.size() >= 2:
				accepts_two = true
			break

	if accepts_two:
		target_obj.take_damage(amount, hit_point)
	else:
		target_obj.take_damage(amount)

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
		tween.tween_property(self, "modulate", Color(1.0, 0.55, 0.15), 0.1) # naranja suave
		tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)
	tween.tween_callback(func(): flashing = false)
