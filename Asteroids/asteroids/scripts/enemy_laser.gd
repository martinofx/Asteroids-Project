extends Area2D

@export var speed: float = 850.0  # Velocidad del láser enemigo
@export var laser_explosion_scene: PackedScene  # Asigna aquí la escena de la explosión
var direction: Vector2 = Vector2.ZERO  # Dirección del disparo

func _process(delta: float) -> void:
	if direction != Vector2.ZERO:
		global_position += direction * speed * delta  # Mover el láser en la dirección correcta

func set_direction(new_direction: Vector2):
	direction = new_direction.normalized()  # Asegurar que la dirección está normalizada

func _on_body_entered(body):
	if body.is_in_group("player") or body.is_in_group("enemy") or body.is_in_group("asteroid"):  # Verifica si es jugador o enemigo
		if body.has_method("take_damage"):
			body.take_damage(body.global_position)   # Llamar a la función de daño del objeto impactado
			
	if laser_explosion_scene:
		var explosion = laser_explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position  # La explosión aparece en el punto de impacto
	queue_free()  # Destruir el láser tras impactar

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()  # Destruir láser si sale de la pantalla
