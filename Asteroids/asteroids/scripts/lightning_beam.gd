extends RayCast2D

@export var flashes := 3
@export var flash_time := 0.1
@export var bounces_max := 3
@export var lightning_jolt: PackedScene = preload("res://scenes/weapons/lightning_jolt.tscn")

var target_point := Vector2.ZERO
var jolted_targets: Array = []
var last_jolt_position: Vector2 = Vector2.ZERO
var is_shooting := false

@onready var jump_area := $JumpArea
@onready var jump_shape := $JumpArea/CollisionShape2D

func _ready() -> void:
	jump_shape.disabled = true


func _physics_process(delta) -> void:
	target_point = to_global(target_position)
	if is_colliding():
		target_point = get_collision_point()
	jump_area.global_position = target_point


func shoot() -> void:
	if is_shooting:
		return
	is_shooting = true
	jump_shape.disabled = false  # Activar colisiones
	jolted_targets.clear()
	
	var _target_point = target_point
	var _primary_body = get_collider()
	var _secondary_bodies = jump_area.get_overlapping_bodies()
	var _secondary_areas = jump_area.get_overlapping_areas()

	# Daño al cuerpo primario
	if _primary_body:
		_secondary_bodies.erase(_primary_body)
		_target_point = _primary_body.global_position

		if _primary_body.is_in_group("asteroid") or _primary_body.is_in_group("enemy") or _primary_body.is_in_group("enemies"):
			if _primary_body.has_method("take_damage"):
				_primary_body.take_damage(get_collision_point())
				jolted_targets.append(_primary_body)

				# ⚡ Rayo visual desde el jugador al objetivo
				_spawn_jolt(global_position, _primary_body.global_position)
				last_jolt_position = _primary_body.global_position

	last_jolt_position = global_position

	# Aplicar jolts iniciales a cuerpos ya presentes en el área
	for node in _secondary_bodies + _secondary_areas:
		if node in jolted_targets:
			continue
		if not is_instance_valid(node):
			continue
		if node.is_in_group("asteroid") or node.is_in_group("enemy") or node.is_in_group("enemies"):
			if node.has_method("take_damage"):
				node.take_damage(last_jolt_position)
				_spawn_jolt(last_jolt_position, node.global_position)
				last_jolt_position = node.global_position
				jolted_targets.append(node)

	# Rebotar rayos
	for flash in range(flashes):
		var _start = global_position
		_spawn_jolt(_start, _target_point)
		_start = _target_point

		for i in range(min(bounces_max, _secondary_bodies.size())):
			var _body = _secondary_bodies[i]

			if is_instance_valid(_body) and not (_body in jolted_targets):
				if _body.is_in_group("asteroid") or _body.is_in_group("enemy") or _body.is_in_group("enemies"):
					if _body.has_method("take_damage"):
						_body.take_damage(last_jolt_position)
						_spawn_jolt(last_jolt_position, _body.global_position)
						last_jolt_position = _body.global_position
						jolted_targets.append(_body)

			_spawn_jolt(_start, last_jolt_position)
			_start = last_jolt_position

		await get_tree().create_timer(flash_time).timeout

	is_shooting = false
	jump_shape.disabled = true  # Desactivar colisiones



func _apply_damage(node: Node) -> void:
	if node in jolted_targets:
		return
	if not is_instance_valid(node):
		return

	if node.is_in_group("asteroid") or node.is_in_group("enemy") or node.is_in_group("enemies"):
		if node.has_method("take_damage"):
			node.take_damage(last_jolt_position) # Daño desde el último punto real
			jolted_targets.append(node)


func _spawn_jolt(from_pos: Vector2, to_pos: Vector2) -> void:
	var jolt = lightning_jolt.instantiate()
	add_child(jolt)
	jolt.create(from_pos, to_pos)  # ← esta parte es clave
	Fx.spawn_impact_effect(to_pos)
	get_viewport().get_camera_2d().shake_camera(15.0, 0.1, 5)

	Fx.spawn_impact_effect(to_pos)  # 💥 Se genera donde termina el jolt
	get_viewport().get_camera_2d().shake_camera(15.0, 0.1, 5)

func _on_jump_area_area_entered(area: Node) -> void:
	if not is_shooting:
		return
	if area in jolted_targets:
		return
	if not is_instance_valid(area):
		return

	if area.is_in_group("enemy") or area.is_in_group("enemies") or area.is_in_group("asteroid"):
		if area.has_method("take_damage"):
			area.take_damage(last_jolt_position)
			_spawn_jolt(last_jolt_position, area.global_position)
			last_jolt_position = area.global_position
			jolted_targets.append(area)


func _on_jump_area_body_entered(body: Node) -> void:
	print("Body entered: ", body.name)  # DEBUG
	if not is_shooting:
		return
	if body in jolted_targets:
		return
	if not is_instance_valid(body):
		return

	if body.is_in_group("asteroid") or body.is_in_group("enemy") or body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(last_jolt_position)
			_spawn_jolt(last_jolt_position, body.global_position)
			last_jolt_position = body.global_position
			jolted_targets.append(body)
