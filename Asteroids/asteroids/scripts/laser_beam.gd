extends RayCast2D

# --- Ajustes de haz / casting ---
@export var cast_speed := 7700.0
@export var max_length := 1200.0
@export var growth_time := 0.1
@export var max_cast_duration := 1.2        # segundos
@export var warning_time := 0.5             # tiempo antes de apagarse para warning

# --- Daño ---
@export var damage_per_second := 280.0       # SUBÍ esto para pegar más fuerte
@export var min_damage_tick := 1             # mínimo aplicado por “tick”
@export var damage_ramp_enabled := true      # bonus de daño si sostiene el rayo
@export var ramp_max_bonus := 0.5            # +50% máx
@export var ramp_time := 0.8                 # alcanza el bonus a los 0.8s

# --- Nodos ---
@onready var casting_particles := $CastingParticles2D
@onready var collision_particles := $CollisionParticles2D
@onready var beam_particles := $BeamParticles2D
@onready var fill: Line2D = $FillLine2D
@onready var tween : Tween
@onready var line_width: float = fill.width

# --- Estado ---
var is_casting := false : set = set_is_casting
var cast_timer := 0.0
var _damage_pool := 0.0

func _ready() -> void:
	set_physics_process(false)
	# Asegurar 2 puntos en la línea
	if fill.points.size() < 2:
		fill.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	else:
		fill.points[1] = Vector2.ZERO
	fill.modulate = Color(1, 1, 1)  # blanco inicial
	collide_with_areas = true

func _physics_process(delta: float) -> void:
	# Empuja el target hacia la derecha hasta max_length
	target_position = (target_position + Vector2.RIGHT * cast_speed * delta).limit_length(max_length)
	# Actualiza haz y partículas
	cast_beam()

	if is_casting:
		cast_timer += delta

		# Advertencia en NARANJA suave
		if cast_timer >= max_cast_duration - warning_time:
			fill.modulate = Color(1.0, 1, 1)  # naranja cálido

		# Apaga al vencer la duración máxima
		if cast_timer >= max_cast_duration:
			is_casting = false
			return

		# Aplicación de daño (acumulado por segundo) contra el collider actual
		if is_colliding():
			var ramp := 1.0
			if damage_ramp_enabled:
				ramp += clamp(cast_timer / ramp_time, 0.0, ramp_max_bonus)
			_damage_pool += (damage_per_second * ramp) * delta

			var dmg := int(_damage_pool)
			if dmg >= min_damage_tick:
				_apply_damage(dmg, get_collider(), get_collision_point())
				_damage_pool -= float(dmg)
		else:
			# opcional: para evitar “explosión” al retocar
			_damage_pool = 0.0

func set_is_casting(cast: bool) -> void:
	is_casting = cast
	cast_timer = 0.0
	_damage_pool = 0.0

	if is_casting:
		target_position = Vector2.ZERO
		fill.points[1] = target_position
		fill.modulate = Color(1, 1, 1)  # reset a blanco al iniciar
		appear()
	else:
		collision_particles.emitting = false
		disappear()
		fill.modulate = Color(0, 0, 0)  # oscurece al apagar

	set_physics_process(is_casting)
	beam_particles.emitting = is_casting
	casting_particles.emitting = is_casting

func cast_beam() -> void:
	var cast_point := target_position

	force_raycast_update()
	if is_colliding():
		cast_point = to_local(get_collision_point())
		# Dirección de partículas de colisión (si tu material lo usa)
		if collision_particles.process_material and collision_particles.process_material.has_method("set"):
			var n := get_collision_normal()
			# Algunas configs usan Vector3 incluso en 2D; mantenemos tu enfoque original.
			collision_particles.process_material.direction = Vector3(n.x, n.y, 0)

	collision_particles.emitting = is_colliding()

	# Actualiza la geometría del haz y VFX
	fill.points[1] = cast_point
	collision_particles.position = cast_point
	beam_particles.position = cast_point * 0.5
	if beam_particles.process_material and beam_particles.process_material.has_method("set"):
		beam_particles.process_material.emission_box_extents.x = cast_point.length() * 0.5

func _apply_damage(amount: int, hit: Object, world_hit_point: Vector2) -> void:
	if not (hit and hit.has_method("take_damage")):
		return

	# Intentar detectar si take_damage acepta 2 parámetros (amount, hit_point)
	var accepts_two := false
	var methods := hit.get_method_list()
	for m in methods:
		if m.name == "take_damage":
			if "args" in m and m.args is Array and m.args.size() >= 2:
				accepts_two = true
			break

	if accepts_two:
		hit.take_damage(amount, world_hit_point)
	else:
		hit.take_damage(amount)

func appear() -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()
	tween.tween_property(fill, "width", line_width, growth_time * 2).from(0.0)
	tween.play()

func disappear() -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()
	tween.tween_property(fill, "width", 0, growth_time).from(fill.width)
	tween.play()
