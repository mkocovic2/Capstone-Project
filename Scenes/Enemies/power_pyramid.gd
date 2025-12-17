extends CharacterBody3D

@export var float_height: float = 2.0
@export var float_speed: float = 1.0
@export var move_speed: float = 5.0
@export var shoot_interval: float = 2.0
@export var min_distance: float = 8.0
@export var max_distance: float = 15.0
@export var fireball_scene: PackedScene

var player: Node3D
var shoot_timer: float = 0.0
var float_offset: float = 0.0

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	
	add_to_group("enemies")
	
	shoot_timer = randf() * shoot_interval

func _physics_process(delta):
	if not player:
		return
	
	float_offset += delta * float_speed
	var float_bobbing = sin(float_offset) * 0.5
	
	var distance = global_position.distance_to(player.global_position)
	var direction_to_player = (player.global_position - global_position).normalized()
	
	var move_direction = Vector3.ZERO
	
	if distance > max_distance:
		move_direction = direction_to_player
	elif distance < min_distance:
		move_direction = -direction_to_player
	else:
		var right = direction_to_player.cross(Vector3.UP).normalized()
		move_direction = right * sin(float_offset * 0.5)
	
	move_direction.y = 0
	move_direction = move_direction.normalized()
	velocity.x = move_direction.x * move_speed
	velocity.z = move_direction.z * move_speed
	
	var target_y = float_height + float_bobbing
	velocity.y = (target_y - global_position.y) * 2.0
	
	# Always look at player
	var look_target = player.global_position
	look_target.y = global_position.y
	look_at(look_target, Vector3.UP)
	
	shoot_timer += delta
	if shoot_timer >= shoot_interval:
		shoot_fireball()
		shoot_timer = 0.0
	
	move_and_slide()

func shoot_fireball():
	if not fireball_scene:
		return
	
	# Create fireball
	var fireball = fireball_scene.instantiate()
	get_tree().root.add_child(fireball)
	
	fireball.global_position = global_position
	
	var direction = (player.global_position - global_position).normalized()
	fireball.set_direction(direction)

func take_damage(amount: int = 0):
	queue_free()
