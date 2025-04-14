extends RayCast2D

@export var flashes := 3 # (int, 1, 10)
@export var flash_time := 0.1 # (float, 0.0, 3.0)
@export var bounces_max := 3 # (int, 0, 10)
@export var lightning_jolt: PackedScene = preload("res://assets/effects/visuals/lightning_beam/lightning_jolt.tscn")

var target_point := Vector2.ZERO
var _primary_body = get_collider()

@onready var jump_area := $JumpArea


func _physics_process(delta) -> void:
	target_point = to_global(target_position)

	if is_colliding():
		target_point = get_collision_point()

	jump_area.global_position = target_point


func shoot() -> void:
	var _target_point = target_point
	var _primary_body = get_collider()
	var _secondary_bodies = jump_area.get_overlapping_bodies()

	# Procesar el cuerpo primario
	if _primary_body and is_instance_valid(_primary_body):
		_secondary_bodies.erase(_primary_body)
		_target_point = _primary_body.global_position

		if _primary_body.is_in_group("asteroid") or _primary_body.is_in_group("enemy") or _primary_body.is_in_group("enemies"):
			if _primary_body.has_method("take_damage"):
				_primary_body.take_damage(global_position)

	# Disparo inicial (desde el jugador hacia el primer objetivo)
	for flash in range(flashes):
		var _start = global_position

		var jolt = lightning_jolt.instantiate()
		add_child(jolt)
		jolt.create(_start, _target_point)

		_start = _target_point

		for i in range(min(bounces_max, _secondary_bodies.size())):
			var _body = _secondary_bodies[i]

			if not is_instance_valid(_body):
				continue

			if _body.is_in_group("asteroid") or _body.is_in_group("enemy") or _body.is_in_group("enemies"):
				if _body.has_method("take_damage"):
					_body.take_damage(global_position)

				var _bounce_jolt = lightning_jolt.instantiate()
				add_child(_bounce_jolt)
				_bounce_jolt.create(_start, _body.global_position)

				_start = _body.global_position  # siguiente rebote

		await get_tree().create_timer(flash_time).timeout
		

func _on_jump_area_area_entered(area: Area2D) -> void:
	if is_instance_valid(area) and (area.is_in_group("asteroid") or area.is_in_group("enemy") or area.is_in_group("enemies")):
		if area.has_method("take_damage"):
			area.take_damage(global_position)
