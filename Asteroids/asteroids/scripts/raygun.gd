extends Area2D

@export var max_length: float = 1000.0
@export var damage_per_second: float = 50.0
@export var duration: float = 1.5  # 🔹 Duración del rayo
@export var explosion_small_scene: PackedScene  # 🔹 Escena de la explosión

@onready var beam_start: Sprite2D = $BeamStart
@onready var beam_segment: Sprite2D = $BeamSegment
@onready var beam_ray: RayCast2D = $BeamRay
@onready var timer: Timer = $Timer  # 🔹 Asegúrate de agregar un Timer en la escena

var active: bool = false
var can_fire: bool = true  # 🔹 Controla si se puede disparar
var damaged_targets = {}  # 🔹 Control de daño continuo

func _ready():
	timer.wait_time = duration
	timer.one_shot = true
	

func _process(delta):
	if get_parent():
		global_position = get_parent().global_position  # 🔹 Mantener la posición sin rotar
	position.y -= 50
	
	if active:
		apply_continuous_damage(delta)  # 🔹 Aplica daño constante

func activate():
	if active or not can_fire:
		return  # 🔹 Evita disparos repetidos
	active = true
	can_fire = false  # 🔹 Bloquea el disparo hasta que termine la animación
	beam_ray.add_exception(get_parent())  # Ignorar la nave
	timer.start()  # 🔹 Comienza la cuenta regresiva
	visible = true  # 🔹 Asegura que el rayo se vea
	
	
func deactivate():
	active = false
	visible = false
	damaged_targets.clear()  # 🔹 Limpiar la lista al apagar el rayo
	queue_free()  # 🔹 Elimina el rayo al desactivarse

func _on_timer_timeout():
	deactivate()  # 🔹 Apaga el rayo cuando el tiempo se acaba
	await get_tree().create_timer(1.0).timeout  # 🔹 Tiempo de espera antes de volver a disparar
	can_fire = true  # 🔹 Permite volver a disparar

### 🚀 🔥 Aplicar daño continuo en objetos tocados por el rayo
func apply_continuous_damage(delta):
	if beam_ray.is_colliding():
		var target = beam_ray.get_collider()
		if target:
			if target.is_in_group("enemy") or target.is_in_group("asteroid"):
				if target.has_method("take_damage"):
					# 🔹 Solo aplicar daño si ya pasó 0.2s desde el último golpe
					if not damaged_targets.has(target):
						damaged_targets[target] = 0.0  # Iniciar temporizador
					
					damaged_targets[target] += delta  # Aumentar tiempo de contacto
					
					if damaged_targets[target] >= 0.2:  # 🔹 Cada 0.2s, aplicar daño
						target.take_damage(damage_per_second * 0.2)  # 🔹 Aplica daño gradual
						spawn_explosion(target.global_position)
						damaged_targets[target] = 0.0  # 🔹 Reiniciar contador de daño

### 🎯 Eventos de colisión con cuerpos (RigidBody2D - Asteroides)
func _on_body_entered(body):
	if body.is_in_group("asteroid"):  # 🔹 Solo aplica a asteroides (RigidBody2D)
		if body.has_method("take_damage"):
			body.take_damage(damage_per_second * 0.2)  # 🔹 Aplica daño al entrar
			spawn_explosion(body.global_position)

### 🛸 Eventos de colisión con áreas (Area2D - Enemigos)
func _on_area_entered(area):
	if area.is_in_group("enemy"):  # 🔹 Solo aplica a enemigos (Area2D)
		if area.has_method("take_damage"):
			area.take_damage(Vector2.ZERO, damage_per_second * 0.2)    # 🔹 Aplica daño al entrar
			spawn_explosion(area.global_position)

func spawn_explosion(position):
	if explosion_small_scene:
		var explosion = explosion_small_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = position  # 🔹 Explosión en el punto exacto del impacto
