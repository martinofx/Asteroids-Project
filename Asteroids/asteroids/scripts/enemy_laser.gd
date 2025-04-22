extends Area2D

@export var speed: float = 850.0  # Velocidad del láser enemigo
@export var laser_explosion_scene: PackedScene  # Asigna aquí la escena de la explosión
var direction: Vector2 = Vector2.ZERO  # Dirección del disparo
var shooter: Node = null  # El nodo que disparó este láser



func _process(delta: float) -> void:
	if direction != Vector2.ZERO:
		global_position += direction * speed * delta  # Mover el láser en la dirección correcta

func set_direction(new_direction: Vector2, fired_by: Node = null):
	direction = new_direction.normalized()
	shooter = fired_by

func _on_body_entered(body):
	if body == shooter:
		return  # Evitar que se dañe a sí mismo

	if body.is_in_group("player") or body.is_in_group("enemy") or body.is_in_group("asteroid"):
		if body.has_method("take_damage"):
			body.take_damage(body.global_position)
	
	if laser_explosion_scene:
		var explosion = laser_explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position

	queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()  # Destruir láser si sale de la pantalla
