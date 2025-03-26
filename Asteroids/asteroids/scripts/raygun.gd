extends Area2D

@export var max_length: float = 1000.0
@export var damage_per_second: float = 50.0

@onready var beam_start: Sprite2D = $BeamStart
@onready var beam_segment: Sprite2D = $BeamSegment
@onready var beam_ray: RayCast2D = $BeamRay
@export var explosion_small_scene: PackedScene  # Asigna aquí la escena de la explosión

var active: bool = false
var direction: Vector2  
var initial_position: Vector2
var initial_offset: Vector2  # 🔹 Guarda la posición relativa a la nave
var initial_rotation: float  # 🔹 Guarda la rotación inicial del rayo

#func _ready():
	
	#rotation = initial_rotation  # 🔹 Fijar la rotación inicial cuando se dispara

func _process(delta):
	# 🔹 Mantener el rayo en la misma posición de la nave, pero sin cambiar la rotación
	if get_parent():
		global_position = get_parent().global_position

func activate():
	active = true
	beam_ray.add_exception(get_parent())  # Ignorar a la nave
	

func deactivate():
	active = false
	

func _on_area_entered(area):
	if area.is_in_group("enemy") or area.is_in_group("asteroid"):
		area.take_damage()
		
	if explosion_small_scene:
		var explosion = explosion_small_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position  # La explosión aparece en el punto de impacto
		
func _on_body_entered(body):
	if body.is_in_group("enemy") or body.is_in_group("asteroid"):  # Verifica si colisiona con un enemigo
		body.take_damage(body.global_position )  # Llamar a la función de daño del enemigo
			
	if explosion_small_scene:
		var explosion = explosion_small_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position  # La explosión aparece en el punto de impacto
	
