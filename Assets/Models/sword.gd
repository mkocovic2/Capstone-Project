extends Node3D

# Idle breathing motion
@export var idle_amount := 0.02
@export var idle_speed := 1.5

# Mouse movement sway
@export var sway_amount := 0.015
@export var sway_smoothness := 10.0
@export var max_sway := 0.06

# Walking bob
@export var walk_amount := 0.05
@export var walk_speed := 10.0
@export var walk_bob_vertical := 0.03

# Tilt when strafing
@export var tilt_amount := 2.0

# Attack detection
@export var attack_damage := 1

@onready var hit_area: Area3D = $Mesh1/Area3D

var time := 0.0
var mouse_delta := Vector2.ZERO
var target_rotation := Vector3.ZERO
var target_position := Vector3.ZERO
var original_position := Vector3.ZERO
var original_rotation := Vector3.ZERO
var is_moving := false
var hit_enemies := []  # Track enemies already hit this swing

func _ready():
	original_position = position
	original_rotation = rotation
	
	# Connect to collision detection
	if hit_area:
		hit_area.body_entered.connect(_on_body_entered)
		hit_area.body_exited.connect(_on_body_exited)
	else:
		print("WARNING: HitArea not found! Add an Area3D as child of sword mesh")

func _input(event):
	if event is InputEventMouseMotion:
		mouse_delta = event.relative

func _process(delta):
	time += delta
	
	# Check if player is moving
	is_moving = false
	if InputMap.has_action("move_forward"):
		is_moving = is_moving or Input.is_action_pressed("move_forward")
	if InputMap.has_action("move_back"):
		is_moving = is_moving or Input.is_action_pressed("move_back")
	if InputMap.has_action("move_left"):
		is_moving = is_moving or Input.is_action_pressed("move_left")
	if InputMap.has_action("move_right"):
		is_moving = is_moving or Input.is_action_pressed("move_right")
	
	#IDLE BREATHING MOTION
	var idle_x = sin(time * idle_speed) * idle_amount
	var idle_y = cos(time * idle_speed * 0.5) * idle_amount
	
	# MOUSE MOVEMENT SWAY
	target_rotation.y = original_rotation.y + clamp(-mouse_delta.x * sway_amount, -max_sway, max_sway)
	target_rotation.x = original_rotation.x + clamp(-mouse_delta.y * sway_amount, -max_sway, max_sway)
	
	mouse_delta = mouse_delta.lerp(Vector2.ZERO, delta * 5.0)
	
	# WALKING BOB
	var walk_x := 0.0
	var walk_y := 0.0
	var walk_z := 0.0
	
	if is_moving:
		walk_x = cos(time * walk_speed) * walk_amount
		walk_y = sin(time * walk_speed * 2.0) * walk_bob_vertical
		walk_z = sin(time * walk_speed) * walk_amount * 0.5
	
	# STRAFE TILT
	var tilt_z := 0.0
	if InputMap.has_action("move_left") and Input.is_action_pressed("move_left"):
		tilt_z = deg_to_rad(tilt_amount)
	elif InputMap.has_action("move_right") and Input.is_action_pressed("move_right"):
		tilt_z = deg_to_rad(-tilt_amount)
	
	target_rotation.z = original_rotation.z + tilt_z
	
	# COMBINE ALL POSITION OFFSETS
	target_position = original_position + Vector3(
		idle_x + walk_x,
		idle_y + walk_y,
		walk_z
	)
	
	# SMOOTH INTERPOLATION
	rotation.x = lerp(rotation.x, target_rotation.x, delta * sway_smoothness)
	rotation.y = lerp(rotation.y, target_rotation.y, delta * sway_smoothness)
	rotation.z = lerp(rotation.z, target_rotation.z, delta * sway_smoothness * 0.5)
	
	position = position.lerp(target_position, delta * sway_smoothness)

func _on_body_entered(body):
	if body.is_in_group("player"):
		return
	# When sword touches an enemy
	if body.has_method("take_damage") and body not in hit_enemies:
		body.take_damage(attack_damage)
		hit_enemies.append(body)
		print("Sword hit: ", body.name)

func _on_body_exited(body):
	# Remove from hit list when they leave the sword area
	if body in hit_enemies:
		hit_enemies.erase(body)

func clear_hit_list():
	# Call this when swing animation ends to reset for next swing
	hit_enemies.clear()

func set_sprint_multiplier(multiplier: float):
	walk_speed = 10.0 * multiplier
	walk_amount = 0.05 * multiplier
	walk_bob_vertical = 0.03 * multiplier
