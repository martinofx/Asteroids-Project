extends Camera2D

func shake_camera(intensity := 40.0, duration := 0.6, pulses := 4):
	var original_offset = offset
	var tween = get_tree().create_tween()
	
	for i in pulses:
		var random_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(self, "offset", random_offset, duration / (pulses * 2)).set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "offset", original_offset, duration / (pulses * 2)).set_trans(Tween.TRANS_SINE)
