extends Node3D
@export var speed: float = 15.0
@export var gravity_strength: float = 9.8
@export var explosion_radius: float = 5.0
@export var explosion_damage: float = 50.0
@export var explosion_force: float = 500.0
@export var lifetime: float = 5.0

# Explosion effect settings
@export var explosion_duration: float = 0.8
@export var explosion_particle_count: int = 30
@export var explosion_color: Color = Color.ORANGE
@export var explosion_sections: int = 8 
@export var section_delay: float = 0.05 

@onready var area: Area3D = $Area3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var direction: Vector3 = Vector3.FORWARD
var velocity: Vector3 = Vector3.ZERO
var time_alive: float = 0.0

func _ready():
	# Connect to collision signal if Area3D exists
	if area:
		area.body_entered.connect(_on_body_entered)
	else:
		print("WARNING: Area3D not found as child of Fireball!")
	
	# Set initial velocity
	velocity = direction * speed

func _physics_process(delta):
	time_alive += delta
	
	# Check lifetime
	if time_alive >= lifetime:
		explode()
		return
	
	# Apply gravity, could make it lob if needed.
	velocity.y -= gravity_strength * delta
	
	# Move fireball
	global_position += velocity * delta

func set_direction(dir: Vector3):
	direction = dir.normalized()
	velocity = direction * speed

func _on_body_entered(body):
	# Collided with something, explode
	explode()

func explode():
	print("Fireball exploded at: ", global_position)
	
	# Create explosion visual effect
	create_explosion_effect()
	
	# Deal damage to nearby objects
	deal_explosion_damage()
	
	# Hide the fireball mesh immediately
	if mesh_instance:
		mesh_instance.visible = false
	
	# Disable collision
	if area:
		area.monitoring = false
	
	# Wait for explosion effect to finish before removing
	await get_tree().create_timer(explosion_duration).timeout
	queue_free()

func create_explosion_effect():
	# Create expanding sections that propagate outward
	create_expanding_sections()
	
	# Create particle burst
	for i in range(explosion_particle_count):
		create_explosion_particle()
	
	# Create initial flash
	create_explosion_flash()

func create_expanding_sections():
	# Create multiple expanding ring/sphere sections
	for i in range(explosion_sections):
		# Delay each section slightly for wave effect
		var delay = i * section_delay
		await get_tree().create_timer(delay).timeout
		
		# Calculate size for this section
		var section_start_scale = (float(i) / explosion_sections) * 0.3
		var section_end_scale = (float(i + 1) / explosion_sections) * explosion_radius * 2
		
		create_explosion_section(section_start_scale, section_end_scale, i)

func create_explosion_section(start_scale: float, end_scale: float, section_index: int):
	# Create a sphere section
	var section = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	section.mesh = sphere_mesh
	
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var color_variation = 1.0 - (float(section_index) / explosion_sections) * 0.3
	var section_color = Color(
		explosion_color.r * color_variation,
		explosion_color.g * color_variation,
		explosion_color.b * color_variation
	)
	
	var start_alpha = 0.8 - (float(section_index) / explosion_sections) * 0.4
	material.albedo_color = Color(section_color.r, section_color.g, section_color.b, start_alpha)
	material.emission_enabled = true
	material.emission = section_color
	material.emission_energy_multiplier = 6.0 - (float(section_index) / explosion_sections) * 3.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	section.material_override = material
	
	# Add to scene
	get_tree().root.add_child(section)
	section.global_position = global_position
	section.scale = Vector3.ONE * start_scale
	
	# Animate this section
	var section_duration = explosion_duration * (1.0 - float(section_index) / explosion_sections * 0.5)
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Expand
	tween.tween_property(section, "scale", Vector3.ONE * end_scale, section_duration)
	
	# Fade out
	tween.tween_property(material, "albedo_color:a", 0.0, section_duration)
	
	# Clean up
	tween.finished.connect(func(): section.queue_free())

func create_explosion_flash():
	# Create bright initial flash
	var flash = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	flash.mesh = sphere_mesh
	
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(explosion_color.r, explosion_color.g, explosion_color.b, 1.0)
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_energy_multiplier = 10.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash.material_override = material
	
	get_tree().root.add_child(flash)
	flash.global_position = global_position
	flash.scale = Vector3.ONE * 0.5
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 3.0, 0.2)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.2)
	tween.finished.connect(func(): flash.queue_free())

func create_explosion_particle() -> MeshInstance3D:
	# Create a small sphere particle
	var particle = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.15
	sphere_mesh.height = 0.3
	particle.mesh = sphere_mesh
	
	# Create material with emission
	var material = StandardMaterial3D.new()
	material.albedo_color = explosion_color
	material.emission_enabled = true
	material.emission = explosion_color
	material.emission_energy_multiplier = 4.0
	particle.material_override = material
	
	# Add to scene at explosion position
	get_tree().root.add_child(particle)
	particle.global_position = global_position
	
	# Random direction for particle
	var random_dir = Vector3(
		randf_range(-1, 1),
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized()
	
	var particle_speed = randf_range(4, 10)
	
	# Animate the particle
	animate_particle(particle, random_dir * particle_speed)
	
	return particle

func animate_particle(particle: MeshInstance3D, vel: Vector3):
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Move particle outward
	var end_pos = particle.global_position + vel * explosion_duration
	tween.tween_property(particle, "global_position", end_pos, explosion_duration)
	
	# Fade out and shrink
	tween.tween_property(particle, "scale", Vector3.ZERO, explosion_duration)
	
	# Clean up when done
	tween.finished.connect(func(): particle.queue_free())

func deal_explosion_damage():
	# Get all bodies in explosion radius
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# Create a sphere shape for explosion
	var shape = SphereShape3D.new()
	shape.radius = explosion_radius
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result["collider"]
		
		# Calculate direction from explosion center to body
		var explosion_dir = (body.global_position - global_position).normalized()
		var distance = global_position.distance_to(body.global_position)
		
		# Calculate force falloff (closer = stronger force)
		var force_multiplier = 1.0 - (distance / explosion_radius)
		force_multiplier = clamp(force_multiplier, 0.0, 1.0)
		var final_force = explosion_force * force_multiplier
		
		# Apply force
		if body is RigidBody3D:
			body.apply_central_impulse(explosion_dir * final_force)
		elif body is CharacterBody3D and body.has_method("apply_knockback"):
			body.apply_knockback(explosion_dir * final_force)
		
		# Check if body has a take_damage method
		if body.has_method("take_damage"):
			body.take_damage(explosion_damage)
			print("Dealt ", explosion_damage, " damage to ", body.name)
		
		print("Applied force of ", final_force, " to ", body.name)
