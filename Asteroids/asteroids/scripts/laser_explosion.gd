extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready():
	animation_player.play("small_explosion")
	animation_player.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(_anim_name):
	queue_free()  # Eliminar la explosión tras la animación
