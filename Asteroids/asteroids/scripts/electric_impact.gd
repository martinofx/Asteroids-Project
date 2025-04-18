extends AnimatedSprite2D

func _ready():
	play("Impact")
	connect("animation_finished", _on_animation_finished)

func _on_animation_finished():
	queue_free()
