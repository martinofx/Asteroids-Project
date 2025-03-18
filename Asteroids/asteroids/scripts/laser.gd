extends Area2D

@export var speed: float = 1700.0  # Velocidad del láser
@export var laser_explosion_scene: PackedScene  # Asigna aquí la escena de la explosión
var direction: Vector2 = Vector2.ZERO  # Dirección del disparo

func _process(delta: float) -> void:
	if direction != Vector2.ZERO:
		global_position += direction * speed * delta

func _on_body_entered(body):
	if body.is_in_group("enemy") or body.is_in_group("asteroid"):  # Verifica si colisiona con un enemigo
		body.take_damage(body.global_position )  # Llamar a la función de daño del enemigo
		
	if laser_explosion_scene:
		var explosion = laser_explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position  # La explosión aparece en el punto de impacto
	
	queue_free()  # Destruir el láser

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()

func _on_area_entered(area):
	if area.is_in_group("enemy") or area.is_in_group("asteroid"):
		area.take_damage()
	if laser_explosion_scene:
		var explosion = laser_explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position  # La explosión aparece en el punto de impacto

	queue_free()  # Eliminar el láser tras el impacto
