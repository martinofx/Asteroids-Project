extends Node

func spawn_impact_effect(position: Vector2) -> void:
	var impact_effect = preload("res://scenes/electric_impact.tscn").instantiate()
	get_tree().current_scene.add_child(impact_effect)
	impact_effect.global_position = position

func camera_shake():
	var cam = get_viewport().get_camera_2d()
	if cam:
		var tween = cam.create_tween()
		var original_pos = cam.offset
		tween.tween_property(cam, "offset", Vector2(8, -8), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(cam, "offset", original_pos, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func screen_flash():
	# Esto depende de que tengas una pantalla blanca semitransparente (tipo ColorRect)
	# Oculto por defecto y visible solo al llamar esto.
	if has_node("/root/ScreenFlash"):
		var flash = get_node("/root/ScreenFlash")
		flash.flash() # Suponiendo que tenga un método llamado flash()
