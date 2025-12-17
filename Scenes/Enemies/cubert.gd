extends CharacterBody3D

# Missile properties
@export var speed: float = 10.0
@export var rotation_speed: float = 5.0
@export var damage: int = 10
@export var player_path: NodePath
@export var broken_mesh_duration: float = 2.0
@export var explosion_force: float = 5.0 

@onready var normal_mesh: MeshInstance3D = $MeshInstance3D
@onready var broken_mesh: Node3D = $"Mesh Container"

var player: Node3D
var is_active: bool = true
var is_destroyed: bool = false
var destruction_timer: float = 0.0

func _ready():
	# Find the player node
	if player_path:
		player = get_node(player_path)
	else:
		# Try to find player by group
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	# Add the cubert to a group so it can be destroyed by attacks
	add_to_group("enemies")
	add_to_group("missiles")
	
	# Hide broken mesh initially
	if broken_mesh:
		broken_mesh.visible = false
		
		# Disable all children in broken mesh initially
		for child in broken_mesh.get_children():
			if child is RigidBody3D:
				child.freeze = true 
				child.collision_layer = 0
				child.collision_mask = 0

func _physics_process(delta):
	# Handle destroyed state
	if is_destroyed:
		destruction_timer += delta
		if destruction_timer >= broken_mesh_duration:
			queue_free()
		return
	
	if not is_active or not player:
		return
	
	# Calculate direction to player
	var direction = (player.global_position - global_position).normalized()
	
	# Smoothly rotate towards player
	var target_transform = global_transform.looking_at(player.global_position, Vector3.UP)
	global_transform = global_transform.interpolate_with(target_transform, rotation_speed * delta)
	
	# Move forward
	velocity = -global_transform.basis.z * speed
	move_and_slide()
	
	# Check for collisions
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("player"):
			_hit_player(collider)
			break

func _hit_player(player_node):
	# Deal damage to player
	if player_node.has_method("take_damage"):
		player_node.take_damage(damage)
	
	# Destroy the missile
	destroy()

func take_damage(amount: int = 0):
	# Called when hit by player attack
	destroy()

func destroy():
	if is_destroyed:
		return

	is_destroyed = true

	explode_pieces()
	queue_free()

func explode_pieces():
	if not broken_mesh:
		return
	
	var world_root = get_tree().root
	
	for child in broken_mesh.get_children():
		if child is RigidBody3D:
			# Store global transform BEFORE removing from parent
			var global_transform_backup = child.global_transform
			
			# Remove from broken mesh and add to world
			broken_mesh.remove_child(child)
			world_root.add_child(child)
			
			# Restore global transform AFTER adding to world
			child.global_transform = global_transform_backup
			
			# Enable the rigidbody
			child.freeze = false
			child.collision_layer = 1
			child.collision_mask = 1
			
			# Apply explosion force from the center
			var explosion_center = global_position
			var piece_position = child.global_position
			var direction = (piece_position - explosion_center).normalized()
			
			# Add some randomness to the direction
			direction += Vector3(
				randf_range(-0.3, 0.3),
				randf_range(0.1, 0.5),
				randf_range(-0.3, 0.3)
			).normalized() * 0.3
			
			direction = direction.normalized()
			
			var distance = piece_position.distance_to(explosion_center)
			var force_multiplier = clamp(distance * 2.0, 0.5, 2.0)
			
			# Apply impulse
			child.apply_central_impulse(direction * explosion_force * force_multiplier)
			
			# Apply slight rotational force
			child.apply_torque_impulse(Vector3(
				randf_range(-1, 1),
				randf_range(-1, 1),
				randf_range(-1, 1)
			) * 2.0)
			
			# Clean up after duration
			var timer = get_tree().create_timer(broken_mesh_duration)
			timer.timeout.connect(_on_piece_cleanup_timeout.bind(child))

func _on_piece_cleanup_timeout(piece: RigidBody3D):
	if is_instance_valid(piece):
		piece.queue_free()
