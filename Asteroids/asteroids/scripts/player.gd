extends CharacterBody2D

@export var max_speed: float = 300.0
@export var acceleration: float = 200.0
@export var angular_speed: float = 2.0
@export var friction: float = 0.98
@export var explosion_scene: PackedScene
@export var laser_scene: PackedScene
@export var missile_scene: PackedScene
@export var homing_missile_scene: PackedScene
@export var fire_rate: float = 0.3
@export var fade_duration: float = 0.5
@export var raygun_scene: PackedScene
@export var lightning_beam_scene: PackedScene
@export var impact_explosion_scene: PackedScene

var screen_size: Vector2
var can_shoot: bool = true
var fading: bool = false
var fade_timer: float = 0.0
var fade_target_position: Vector2
var health: float = 100
var controls_disabled = false
var current_weapon_index: int = 0
var current_weapon: Node
var weapon_ui: Control
var energy_beam: Area2D
var beam_active = false
var raygun_instance = null
var beam_cooldown := false
var damage_cooldown := 1.0
var time_since_last_damage := 0.0
var is_invulnerable := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var flame_center: Node2D = $Flame_Center
@onready var flame_left: Node2D = $Flame_Left
@onready var flame_right: Node2D = $Flame_Right
@onready var beam_timer := $BeamTimer
@onready var laser_beam = $LaserBeam2D
@onready var lightning_beam = $LightningBeam
@onready var weapon_manager = get_tree().root.get_node("Game/WeaponManager")
@onready var shot_point = $ShotPoint
@onready var flame_animator: AnimationPlayer = $Flame_Center/AnimationPlayer

func _ready() -> void:
	update_screen_size()
	get_viewport().connect("size_changed", Callable(self, "update_screen_size"))
	flame_center.visible = false
	flame_left.visible = false
	flame_right.visible = false	

	beam_timer = Timer.new()
	beam_timer.wait_time = 1.5
	beam_timer.one_shot = true
	beam_timer.timeout.connect(_on_beam_timeout)
	add_child(beam_timer)

	add_to_group("player")

func update_screen_size() -> void:
	screen_size = get_viewport_rect().size

func _physics_process(delta: float) -> void:
	var moving = false
	var rotating_left = false
	var rotating_right = false

	if Input.is_action_pressed("rotate_left"):
		rotation -= angular_speed * delta
		rotating_left = true
	if Input.is_action_pressed("rotate_right"):
		rotation += angular_speed * delta
		rotating_right = true

	if Input.is_action_pressed("move_forward"):
		velocity += Vector2.UP.rotated(rotation) * acceleration * delta
		velocity = velocity.limit_length(max_speed)
		moving = true
	else:
		velocity *= friction

	time_since_last_damage += delta

	move_and_slide()
	handle_flames(moving, rotating_left, rotating_right)

	if fading:
		fade_timer += delta
		sprite.modulate.a = 1.0 - (fade_timer / fade_duration)
		if fade_timer >= fade_duration:
			complete_fade_transition()

func handle_flames(moving: bool, rotating_left: bool, rotating_right: bool):
	flame_center.visible = moving
	flame_left.visible = rotating_right
	flame_right.visible = rotating_left
	check_screen_wrap()

func receive_impact(force: float, collision_direction: Vector2, source: Node):
	var rebound_force = -collision_direction * force * 2
	velocity += rebound_force

	if velocity.length() < 50:
		velocity = -collision_direction * 100

	if source.has_method("take_damage"):
		source.take_damage(5, global_position)  # opcional

	disable_controls(0.3)


func _input(event):
	if event.is_action_pressed("shoot") and can_shoot:
		shoot()
	if event.is_action_pressed("missile_small") and can_shoot:
		fire_missile()
	if event.is_action_pressed("homing_missile") and can_shoot:
		fire_homing_missile()
	if event.is_action_pressed("shoot_raygun") and not beam_active and not beam_cooldown:
		toggle_beam(true)
	elif event.is_action_released("shoot_raygun"):
		toggle_beam(false)
		beam_cooldown = false
		beam_timer.stop()
	if laser_beam == null:
		return
	if event.is_action_pressed("laser_beam"):
		laser_beam.is_casting = true
	elif event.is_action_released("laser_beam"):
		laser_beam.is_casting = false
	if event.is_action_pressed("lightning_beam") and lightning_beam:
		lightning_beam.shoot()

func toggle_beam(active: bool):
	if active and not beam_active:
		beam_active = true
		beam_cooldown = true
		energy_beam = raygun_scene.instantiate()
		add_child(energy_beam)
		energy_beam.activate()
		beam_timer.start()
	elif not active and beam_active:
		beam_active = false
		energy_beam.deactivate()
		energy_beam.queue_free()

func _on_beam_timeout():
	toggle_beam(false)

func shoot():
	if not weapon_manager.can_shoot:
		return
	var weapon_data = weapon_manager.get_current_weapon_data()
	if weapon_data.is_empty():
		return
	var laser = weapon_data["scene"].instantiate() as Area2D
	get_parent().add_child(laser)
	var offset_distance = 60
	var shoot_position = global_position + Vector2.UP.rotated(rotation) * offset_distance
	laser.global_position = shoot_position
	laser.direction = Vector2.UP.rotated(rotation)
	laser.rotation = rotation
	laser.damage = weapon_data["damage"]
	weapon_manager.start_cooldown()

func fire_missile():
	if missile_scene:
		var missile = missile_scene.instantiate()
		get_parent().add_child(missile)
		var offset_distance = -30
		var shoot_position = global_position + Vector2.UP.rotated(rotation) * offset_distance
		missile.global_position = shoot_position
		missile.direction = Vector2.UP.rotated(rotation)
		missile.rotation = rotation

func fire_homing_missile():
	if homing_missile_scene:
		var num_missiles = 5
		var spread_angle = deg_to_rad(100)
		var start_angle = -spread_angle / 2
		for i in range(num_missiles):
			await get_tree().create_timer(i * 0.05).timeout
			var missile = homing_missile_scene.instantiate()
			get_parent().add_child(missile)
			var angle = rotation + start_angle + (spread_angle / (num_missiles - 1)) * i + randf_range(-0.1, 0.1)
			var shoot_position = global_position + Vector2.UP.rotated(angle) * -50
			missile.global_position = shoot_position
			missile.direction = Vector2.UP.rotated(angle)
			missile.rotation = angle

func take_damage(damage: int = 10, impact_position: Vector2 = Vector2.ZERO):
	if is_invulnerable:
		print("Daño ignorado por invulnerabilidad")
		return
	print("Recibiendo daño: ", damage)
	health -= damage
	print("Vida actual: ", health)
	if impact_position != Vector2.ZERO:
		var knockback_direction = (global_position - impact_position).normalized()
		velocity += knockback_direction * 150
	var impact = impact_explosion_scene.instantiate()
	get_parent().add_child(impact)
	impact.global_position = global_position
	get_viewport().get_camera_2d().shake_camera(13.0, 0.2, 5)
	activate_invulnerability()
	if health <= 0:
		die()

func activate_invulnerability():
	is_invulnerable = true
	sprite.modulate = Color(1, 1, 1, 0.5)
	$TimerInvulnerability.start()

func _on_timer_invulnerability_timeout():
	is_invulnerable = false
	sprite.modulate = Color(1, 1, 1, 1)

func die():
	get_viewport().get_camera_2d().shake_camera(50.0, 0.7, 6)
	if explosion_scene:
		for i in range(randi_range(5, 10)):
			var explosion = explosion_scene.instantiate()
			get_parent().add_child(explosion)
			explosion.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
			explosion.scale = Vector2(randf_range(1.5, 2.5), randf_range(1.5, 2.5))
			await get_tree().create_timer(randf_range(0.05, 0.1)).timeout
	queue_free()

func check_screen_wrap():
	if fading:
		return
	var new_position = global_position
	var crossed = false
	if global_position.x < 0:
		new_position.x = screen_size.x
		crossed = true
	elif global_position.x > screen_size.x:
		new_position.x = 0
		crossed = true
	if global_position.y < 0:
		new_position.y = screen_size.y
		crossed = true
	elif global_position.y > screen_size.y:
		new_position.y = 0
		crossed = true
	if crossed:
		start_fade_out(new_position)

func start_fade_out(new_position: Vector2):
	fading = true
	fade_timer = 0.0
	fade_target_position = new_position

func complete_fade_transition():
	global_position = fade_target_position
	start_fade_in()

func start_fade_in():
	fading = false
	fade_timer = 0.0
	sprite.modulate.a = 1.0

func disable_controls(duration):
	controls_disabled = true
	await get_tree().create_timer(duration).timeout
	controls_disabled = false

func apply_impulse(force: Vector2):
	velocity += force
