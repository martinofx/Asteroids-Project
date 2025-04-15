extends RayCast2D

@export var flashes := 3
@export var flash_time := 0.1
@export var bounces_max := 3
@export var lightning_jolt: PackedScene = preload("res://assets/effects/visuals/lightning_beam/lightning_jolt.tscn")

var target_point := Vector2.ZERO
var jolted_targets := []
var last_jolt_position := Vector2.ZERO
var is_shooting := false

@onready var jump_area := $JumpArea


func _physics_process(delta) -> void:
	target_point = to_global(target_position)
	if is_colliding():
		target_point = get_collision_point()
	jump_area.global_position = target_point


func shoot() -> void:
	is_shooting = true
	jolted_targets.clear()
	last_jolt_position = global_position

	var _target_point = target_point
	var _primary_body = get_collider()
	var _secondary_areas: Array[Area2D] = jump_area.get_overlapping_areas()  # Enemigos Area2D


	if _primary_body and is_instance_valid(_primary_body):
		_secondary_areas.erase(_primary_body)
		_target_point = _primary_body.global_position
		_apply_damage(_primary_body)

	for flash in range(flashes):
		var _start = global_position
		_spawn_jolt(_start, _target_point)
		last_jolt_position = _target_point
		_start = _target_point

		for i in range(min(bounces_max, _secondary_areas.size())):
			var _area = _secondary_areas[i]
			if not is_instance_valid(_area) or _area in jolted_targets:
				continue

			_apply_damage(_area)
			_spawn_jolt(_start, _area.global_position)
			last_jolt_position = _area.global_position
			_start = _area.global_position

		await get_tree().create_timer(flash_time).timeout

	is_shooting = false


func _apply_damage(node: Node) -> void:
	if node in jolted_targets:
		return
	if not is_instance_valid(node):
		return

	if node.is_in_group("asteroid") or node.is_in_group("enemy") or node.is_in_group("enemies"):
		if node.has_method("take_damage"):
			node.take_damage(global_position)
			jolted_targets.append(node)


func _spawn_jolt(from_pos: Vector2, to_pos: Vector2) -> void:
	var jolt = lightning_jolt.instantiate()
	add_child(jolt)
	jolt.create(from_pos, to_pos)


func _on_jump_area_area_entered(area: Area2D) -> void:
	if not is_shooting:
		return
	if area in jolted_targets:
		return
	if not is_instance_valid(area):
		return

	if area.is_in_group("asteroid") or area.is_in_group("enemy") or area.is_in_group("enemies"):
		if area.has_method("take_damage"):
			area.take_damage(global_position)
			jolted_targets.append(area)
			_spawn_jolt(last_jolt_position, area.global_position)
			last_jolt_position = area.global_position
