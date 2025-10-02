# HUD.gd (en el CanvasLayer)
extends CanvasLayer

@onready var bar: TextureProgressBar = $HealthBar

func set_max_health(max_hp: int) -> void:
	bar.max_value = max_hp
	bar.value = max_hp

func set_health(hp: int) -> void:
	bar.value = clamp(hp, 0, bar.max_value)
