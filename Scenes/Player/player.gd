extends CharacterBody3D

# HEALTH SETTINGS
@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var invincibility_duration: float = 1.0
@export var damage_flash_duration: float = 0.2
@export var health_regen_rate: float = 0. # Not sure if health regening will be good or not
@export var health_regen_delay: float = 5.0 

var is_invincible: bool = false
var invincibility_timer: float = 0.0
var damage_flash_timer: float = 0.0
var time_since_last_damage: float = 0.0

# MOVEMENT SETTINGS
@export var forward_speed: float = 5.0
@export var rotation_speed: float = 2.0
@export var mouse_sensitivity: float = 0.002
@export var jump_velocity: float = 8.0
@export var dash_speed: float = 15.0
@export var dash_duration: float = 0.3

# REFERENCES
@onready var camera: Camera3D = $Camera3D
@onready var audio: AudioStreamPlayer3D = $PlayerSounds

# Sword hitbox
@onready var sword_area: Area3D = $Camera3D/Colossal_Blade_1213003617_texture/Mesh1/Area3D
@onready var sword_collision: CollisionShape3D = $Camera3D/Colossal_Blade_1213003617_texture/Mesh1/Area3D/CollisionShape3D

@export var animation_player: AnimationPlayer
@export var object_to_disable: Node3D

@export var player_mesh: MeshInstance3D

@export var fireball_scene: PackedScene
@export var attack_spawn_point: Node3D

enum AttackType { Q_FIREBALL, W_PLACEHOLDER, E_PLACEHOLDER, R_PLACEHOLDER }
var selected_attack: AttackType = AttackType.Q_FIREBALL
var queued_attack: AttackType = AttackType.Q_FIREBALL

var rotation_y := 0.0
var rotation_x := 0.0

var is_dashing := false
var dash_timer := 0.0

var is_swinging := false
var current_swing := 1
var combo_window := 0.0
var combo_window_duration := 1.0

var is_using_hand := false
var hand_cooldown_timer := 0.0
var hand_cooldown_duration := 5.0
var can_use_hand := true

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Add to player group so enemies can find us
	add_to_group("player")

	# Sword hitbox OFF by default
	sword_collision.disabled = true
	sword_area.monitoring = false
	sword_area.monitorable = false

	if not animation_player:
		push_warning("AnimationPlayer not assigned!")
	
	# Initialize health
	current_health = max_health

# INPUT
func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_y -= event.relative.x * mouse_sensitivity
		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_x = clamp(rotation_x, -PI / 2.0, PI / 2.0)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not is_swinging:
			play_swing_animation()

		if event.button_index == MOUSE_BUTTON_RIGHT and not is_using_hand and can_use_hand:
			queued_attack = selected_attack
			play_hand_use_animation()

		if event.button_index == MOUSE_BUTTON_MIDDLE:
			flip_180()

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Q: selected_attack = AttackType.Q_FIREBALL
			KEY_W: selected_attack = AttackType.W_PLACEHOLDER
			KEY_E: selected_attack = AttackType.E_PLACEHOLDER
			KEY_R: selected_attack = AttackType.R_PLACEHOLDER

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)

# PHYSICS
func _physics_process(delta):
	rotation.y = rotation_y
	camera.rotation.x = rotation_x

	# Handle invincibility timer
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
	
	# Handle damage flash
	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		if damage_flash_timer <= 0 and player_mesh:
			# Reset material to normal
			reset_damage_flash()
	
	# Handle health regeneration
	if health_regen_rate > 0 and current_health < max_health:
		time_since_last_damage += delta
		if time_since_last_damage >= health_regen_delay:
			heal(health_regen_rate * delta)

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false

	if combo_window > 0:
		combo_window -= delta
		if combo_window <= 0:
			current_swing = 1

	if hand_cooldown_timer > 0:
		hand_cooldown_timer -= delta
		if hand_cooldown_timer <= 0:
			can_use_hand = true

	var speed = dash_speed if is_dashing else forward_speed
	var forward_dir = -transform.basis.z
	velocity.x = forward_dir.x * speed
	velocity.z = forward_dir.z * speed

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		audio.stream = preload("res://Assets/Audio/Sounds/click.wav")
		audio.play()
		velocity.y = jump_velocity

	if Input.is_action_just_pressed("ui_shift") and not is_dashing:
		is_dashing = true
		dash_timer = dash_duration

	if not is_on_floor():
		velocity.y -= 9.8 * delta

	move_and_slide()

# HEALTH SYSTEM
func take_damage(amount: float):
	if is_invincible:
		return
	
	current_health -= amount
	time_since_last_damage = 0.0
	
	print("Player took ", amount, " damage. Health: ", current_health, "/", max_health)
	
	# Trigger damage effects
	apply_damage_flash()
	play_damage_sound()
	
	# Start invincibility frames
	is_invincible = true
	invincibility_timer = invincibility_duration
	
	# Check if dead
	if current_health <= 0:
		die()

func heal(amount: float):
	current_health = min(current_health + amount, max_health)

func apply_damage_flash():
	if not player_mesh:
		return
	
	damage_flash_timer = damage_flash_duration
	
	# Flash red by modulating the mesh
	var material = player_mesh.get_active_material(0)
	if material and material is StandardMaterial3D:
		material = material.duplicate()
		material.albedo_color = Color.RED
		player_mesh.set_surface_override_material(0, material)

func reset_damage_flash():
	if not player_mesh:
		return
	
	# Reset to original material
	player_mesh.set_surface_override_material(0, null)

func play_damage_sound():
	pass

func die():
	print("Player died!")
	current_health = 0
	
	# Disable player controls
	set_physics_process(false)
	set_process_input(false)
	
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://Scenes/Levels/TitleScreen.tscn")

func respawn():
	current_health = max_health
	is_invincible = false
	invincibility_timer = 0.0
	time_since_last_damage = 0.0
	
	# Re-enable controls
	set_physics_process(true)
	set_process_input(true)
	
	print("Player respawned!")

# KNOCKBACK
func apply_knockback(force: Vector3):
	# Apply knockback force to the player
	velocity += force

func get_health_percentage() -> float:
	return current_health / max_health

func is_alive() -> bool:
	return current_health > 0

# SWING
func play_swing_animation():
	if not animation_player:
		return

	var anim_name = "swing" if current_swing == 1 else "swing_2"
	if not animation_player.has_animation(anim_name):
		return

	is_swinging = true

	# ENABLE HITBOX
	enable_hitbox()

	if object_to_disable:
		object_to_disable.visible = false

	animation_player.play(anim_name)
	audio.stream = preload("res://Assets/Audio/Sounds/swing.mp3")
	audio.play()

	if not animation_player.animation_finished.is_connected(_on_swing_animation_finished):
		animation_player.animation_finished.connect(_on_swing_animation_finished)

func _on_swing_animation_finished(anim_name: String):
	if anim_name != "swing" and anim_name != "swing_2":
		return

	is_swinging = false

	# DISABLE HITBOX
	disable_hitbox()

	if object_to_disable:
		object_to_disable.visible = true

	combo_window = combo_window_duration
	current_swing = 2 if anim_name == "swing" else 1

# HAND ATTACK
func play_hand_use_animation():
	if not animation_player or not animation_player.has_animation("hand_use"):
		return

	can_use_hand = false
	hand_cooldown_timer = hand_cooldown_duration
	is_using_hand = true

	animation_player.play("hand_use")

	if not animation_player.animation_finished.is_connected(_on_hand_use_animation_finished):
		animation_player.animation_finished.connect(_on_hand_use_animation_finished)

func _on_hand_use_animation_finished(anim_name: String):
	if anim_name == "hand_use":
		is_using_hand = false
		shoot_attack(queued_attack)

# ATTACKS
func shoot_attack(attack: AttackType):
	match attack:
		AttackType.Q_FIREBALL:
			shoot_fireball()

func shoot_fireball():
	if not fireball_scene:
		return

	var fireball = fireball_scene.instantiate()
	get_tree().root.add_child(fireball)

	var spawn_pos = (
		attack_spawn_point.global_position
		if attack_spawn_point
		else global_position + -transform.basis.z + Vector3.UP * 1.5
	)
	fireball.global_position = spawn_pos

	var dir = -camera.global_transform.basis.z
	if fireball.has_method("set_direction"):
		fireball.set_direction(dir.normalized())

# HITBOX CONTROL
func enable_hitbox():
	sword_collision.disabled = false
	sword_area.monitoring = true
	sword_area.monitorable = true

func disable_hitbox():
	sword_collision.disabled = true
	sword_area.monitoring = false
	sword_area.monitorable = false

# UTILS
func flip_180():
	rotation_y = fmod(rotation_y + PI, TAU)
