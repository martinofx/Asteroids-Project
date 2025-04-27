extends Node

var weapons = {
	"laser": { "scene": preload("res://scenes/weapons/laser.tscn"), "damage": 100 },
	"missile": { "scene": preload("res://scenes/weapons/missile_small.tscn"), "damage": 20 },
	"homing": { "scene": preload("res://scenes/weapons/homing_missile.tscn"), "damage": 10 },
	"laser_beam": { "scene": preload("res://scenes/weapons/laser_beam.tscn"), "damage": 1 },
	"lightning": { "scene": preload("res://scenes/weapons/lightning_beam.tscn"), "damage": 50 }
}

var current_weapon = "laser"
var fire_rate = 0.5
var can_shoot = true

func shoot(from_position: Vector2, direction: Vector2, rotation: float) -> void:
	if not can_shoot:
		return

	can_shoot = false

	var weapon_data = weapons.get(current_weapon)
	if not weapon_data:
		return

	var projectile = weapon_data["scene"].instantiate()
	projectile.damage = weapon_data["damage"]

	projectile.global_position = from_position
	projectile.direction = direction
	projectile.rotation = rotation

	get_tree().current_scene.add_child(projectile)

	get_tree().create_timer(fire_rate).timeout.connect(func(): can_shoot = true)
