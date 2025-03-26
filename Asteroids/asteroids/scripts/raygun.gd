extends Area2D

@export var max_length: float = 1000.0
@export var damage_per_second: float = 50.0

@onready var beam_start: Sprite2D = $BeamStart
@onready var beam_segment: Sprite2D = $BeamSegment
@onready var beam_ray: RayCast2D = $BeamRay

var active: bool = false
var direction: Vector2  

func _ready():
	beam_segment.scale.x = 0  # Ocultar rayo al inicio

func _process(delta):
	if active:
		update_beam(delta)

func activate():
	active = true
	beam_ray.add_exception(get_parent())  # Ignorar a la nave
	update_beam(0)

func deactivate():
	active = false
	beam_segment.scale.x = 0  # Ocultar rayo

func update_beam(delta):
	if not active:
		return

	# Asegurar que la dirección siga la rotación del rayo
	direction = Vector2.RIGHT.rotated(rotation)

	# Ajustar la posición para que siga la nave
	global_position = get_parent().global_position + direction

	beam_ray.target_position = direction * max_length
	beam_ray.force_raycast_update()

	var hit_position = global_position + direction * max_length

	if beam_ray.is_colliding():
		var collider = beam_ray.get_collider()

		# Evitar que el rayo golpee a la nave
		if collider != get_parent():  
			hit_position = beam_ray.get_collision_point()
			if collider.has_method("take_damage"):
				collider.take_damage(damage_per_second * delta)

	# Ajustar la escala del segmento del rayo
	var length = global_position.distance_to(hit_position)
	beam_segment.scale.x = length / max_length
