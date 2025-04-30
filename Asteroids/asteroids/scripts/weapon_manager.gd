extends Node

var weapons = {
	"laser": { "scene": preload("res://scenes/weapons/laser.tscn"), "damage": 100, "fire_rate": 0.01 },
	"missile": { "scene": preload("res://scenes/weapons/missile_small.tscn"), "damage": 20 },
	"homing": { "scene": preload("res://scenes/weapons/homing_missile.tscn"), "damage": 10 },
	"laser_beam": { "scene": preload("res://scenes/weapons/laser_beam.tscn"), "damage": 1 },
	"lightning": { "scene": preload("res://scenes/weapons/lightning_beam.tscn"), "damage": 50 }
}

var current_weapon = "laser"
var can_shoot = true

func get_current_weapon_data() -> Dictionary:
	return weapons.get(current_weapon, {})

func start_cooldown():
	var data = get_current_weapon_data()
	if data.has("fire_rate"):
		can_shoot = false
		get_tree().create_timer(data["fire_rate"]).timeout.connect(func(): can_shoot = true)
