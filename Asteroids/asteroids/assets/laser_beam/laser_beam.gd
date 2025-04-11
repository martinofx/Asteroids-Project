extends RayCast2D

@export var cast_speed := 7700.0
@export var max_length := 1200
@export var growth_time := 0.1
@export var max_cast_duration := 1.2  # segundos
@export var warning_time := 0.5  # tiempo antes de apagarse para mostrar sobrecarga

@onready var casting_particles := $CastingParticles2D
@onready var collision_particles := $CollisionParticles2D
@onready var beam_particles := $BeamParticles2D
@onready var fill := $FillLine2D
@onready var tween : Tween
@onready var line_width: float = fill.width

var is_casting := false: set = set_is_casting
var cast_timer := 0.0


func _ready() -> void:
	set_physics_process(false)
	fill.points[1] = Vector2.ZERO
	fill.modulate = Color(1, 1, 1)  # Color blanco inicial
	collide_with_areas = true


func _physics_process(delta: float) -> void:
	target_position = (target_position + Vector2.RIGHT * cast_speed * delta).limit_length(max_length)
	cast_beam()
	
	if is_casting:
		cast_timer += delta

		# Se pone rojo al acercarse al final
		if cast_timer >= max_cast_duration - warning_time:
			fill.modulate = Color(1, 0, 1)  # Rojo

		if cast_timer >= max_cast_duration:
			is_casting = false


func set_is_casting(cast: bool) -> void:
	is_casting = cast
	cast_timer = 0.0

	if is_casting:
		target_position = Vector2.ZERO
		fill.points[1] = target_position
		fill.modulate = Color(1, 1, 1)  # Reset a blanco
		appear()
	else:
		collision_particles.emitting = false
		disappear()
		fill.modulate = Color(0, 0, 0)  # Reset al apagar

	set_physics_process(is_casting)
	beam_particles.emitting = is_casting
	casting_particles.emitting = is_casting


func cast_beam() -> void:
	var cast_point := target_position

	force_raycast_update()
	if is_colliding():
		cast_point = to_local(get_collision_point())
		collision_particles.process_material.direction = Vector3(
			get_collision_normal().x, get_collision_normal().y, 0
		)

	collision_particles.emitting = is_colliding()

	fill.points[1] = cast_point
	collision_particles.position = cast_point
	beam_particles.position = cast_point * 0.5
	beam_particles.process_material.emission_box_extents.x = cast_point.length() * 0.5
	
	var hit = get_collider()
	if hit and hit.has_method("take_damage"):
		hit.take_damage(get_collision_point())


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
