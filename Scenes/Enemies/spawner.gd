extends Node3D

# Wave settings
@export var cubert_scene: PackedScene
@export var spawn_radius: float = 20.0
@export var spawn_height_min: float = 5.0
@export var spawn_height_max: float = 15.0
@export var time_between_waves: float = 10.0
@export var start_delay: float = 3.0

# Wave progression
@export var cuberts_per_wave_start: int = 3 
@export var cuberts_increase_per_wave: int = 2 
@export var max_cuberts_per_wave: int = 15

# Player reference
@export var player_path: NodePath

var current_wave: int = 0
var wave_timer: float = 0.0
var is_spawning: bool = true
var active_cuberts: Array = []
var ready_to_spawn: bool = false

func _ready():
	wave_timer = start_delay
	# Wait one frame to ensure we're fully in the tree
	await get_tree().process_frame
	ready_to_spawn = true

func _process(delta):
	if not is_spawning or not ready_to_spawn:
		return
	
	wave_timer -= delta
	
	if wave_timer <= 0:
		spawn_wave()
		wave_timer = time_between_waves

func spawn_wave():
	current_wave += 1
	
	# Calculate how many cuberts to spawn this wave
	var cuberts_to_spawn = min(
		cuberts_per_wave_start + (current_wave - 1) * cuberts_increase_per_wave,
		max_cuberts_per_wave
	)
	
	print("Spawning wave ", current_wave, " with ", cuberts_to_spawn, " cuberts")
	
	# Spawn cuberts in random positions around the spawn point
	for i in range(cuberts_to_spawn):
		spawn_cubert()

func spawn_cubert():
	if not cubert_scene:
		push_error("Cubert scene not set in spawner!")
		return
	
	if not is_inside_tree():
		push_error("Spawner not in scene tree!")
		return
	
	# Create new cubert instance
	var cubert = cubert_scene.instantiate()
	
	# Calculate random position in a circle around spawn point
	var random_angle = randf() * TAU 
	var random_distance = randf_range(spawn_radius * 0.5, spawn_radius)
	var random_height = randf_range(spawn_height_min, spawn_height_max)
	
	var offset = Vector3(
		cos(random_angle) * random_distance,
		random_height,
		sin(random_angle) * random_distance
	)
	
	# Add to scene first
	get_tree().root.add_child(cubert)
	
	cubert.global_position = global_position + offset
	
	if player_path and cubert.has_method("set") and "player_path" in cubert:
		cubert.player_path = player_path
	
	active_cuberts.append(cubert)
	
	# Clean up reference when cubert is destroyed
	cubert.tree_exited.connect(func(): 
		active_cuberts.erase(cubert)
	)

func get_random_spawn_position() -> Vector3:
	# Alternative method: random position in a sphere
	var random_direction = Vector3(
		randf_range(-1, 1),
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized()
	
	var random_distance = randf_range(spawn_radius * 0.5, spawn_radius)
	return global_position + random_direction * random_distance

func stop_spawning():
	is_spawning = false

func start_spawning():
	is_spawning = true
	ready_to_spawn = true

func clear_all_cuberts():
	for cubert in active_cuberts:
		if is_instance_valid(cubert):
			cubert.queue_free()
	active_cuberts.clear()

func get_active_cubert_count() -> int:
	return active_cuberts.size()
