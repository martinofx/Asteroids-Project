extends Node2D
# Visual Effects container. Provides a high level interface to create Ships visual effects

const TRAIL_VELOCITY_THRESHOLD := 500

@onready var _ship_trail := $MoveTrail
func make_trail(current_speed: float) -> void:
	_ship_trail.emitting = current_speed > TRAIL_VELOCITY_THRESHOLD
