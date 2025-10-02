extends RayCast2D

@export var flashes := 3
@export var flash_time := 0.1
@export var bounces_max := 3
@export var lightning_damage: int = 25   # <<< NUEVO
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
	jump_shape.disabled = false
	jolted_targets.clear()

	var _target_point = target_point
	var _primary_body = get_collider()
	var _secondary_bodies = jump_area.get_overlapping_bodies()
	var _secondary_areas = jump_area.get_overlapping_areas()

	# Daño al cuerpo primario
	if _primary_body:
		_secondary_bodies.erase(_primary_body)
		_target_point = _primary_body.global_position

		if _is_chain_target(_primary_body):
			if _primary_body.has_method("take_damage"):
				var hit_point := get_collision_point()
				_primary_body.take_damage(lightning_damage, hit_point)     # ✅
				jolted_targets.append(_primary_body)

				_spawn_jolt(global_position, _primary_body.global_position)
				last_jolt_position = _primary_body.global_position
	else:
		last_jolt_position = global_position

	# Jolts iniciales a lo que ya está en el área
	for node in _secondary_bodies + _secondary_areas:
		_try_apply_damage(node, lightning_damage, last_jolt_position)

	# Rebotar rayos
	for flash in range(flashes):
		var _start = global_position
		_spawn_jolt(_start, _target_point)
		_start = _target_point

		for i in range(min(bounces_max, _secondary_bodies.size())):
			var _body = _secondary_bodies[i]
			if _try_apply_damage(_body, lightning_damage, last_jolt_position):
				_spawn_jolt(_start, last_jolt_position)
				_start = last_jolt_position

		await get_tree().create_timer(flash_time).timeout

	is_shooting = false
	jump_shape.disabled = true

func _is_chain_target(n: Node) -> bool:
	return n and (n.is_in_group("asteroid") or n.is_in_group("enemy") or n.is_in_group("enemies"))

func _try_apply_damage(node: Node, amount: int, from_point: Vector2) -> bool:
	if not is_instance_valid(node): return false
	if node in jolted_targets: return false
	if not _is_chain_target(node): return false
	if not node.has_method("take_damage"): return false

	node.take_damage(amount, from_point)                     # ✅ SIEMPRE int + punto
	_spawn_jolt(from_point, node.global_position)
	last_jolt_position = node.global_position
	jolted_targets.append(node)
	return true

func _spawn_jolt(from_pos: Vector2, to_pos: Vector2) -> void:
	var jolt = lightning_jolt.instantiate()
	add_child(jolt)
	jolt.create(from_pos, to_pos)
	Fx.spawn_impact_effect(to_pos)
	get_viewport().get_camera_2d().shake_camera(15.0, 0.1, 5)

func _on_jump_area_area_entered(area: Node) -> void:
	if not is_shooting: return
	_try_apply_damage(area, lightning_damage, last_jolt_position)

func _on_jump_area_body_entered(body: Node) -> void:
	if not is_shooting: return
	_try_apply_damage(body, lightning_damage, last_jolt_position)
