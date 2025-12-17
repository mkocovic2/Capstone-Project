extends Node3D

@export var speed: float = 15.0
@export var gravity_strength: float = 9.8
@export var explosion_radius: float = 5.0
@export var explosion_damage: float = 50.0
@export var lifetime: float = 5.0

@onready var area: Area3D = $Area3D

var direction: Vector3 = Vector3.FORWARD
var velocity: Vector3 = Vector3.ZERO
var time_alive: float = 0.0

func _ready():
	if area:
		area.body_entered.connect(_on_body_entered)
	else:
		print("WARNING: Area3D not found as child of Fireball!")
	
	velocity = direction * speed

func _physics_process(delta):
	time_alive += delta
	
	if time_alive >= lifetime:
		explode()
		return
	
	velocity.y -= gravity_strength * delta
	
	global_position += velocity * delta

func set_direction(dir: Vector3):
	direction = dir.normalized()
	velocity = direction * speed

func _on_body_entered(body):
	explode()

func explode():
	print("Fireball exploded at: ", global_position)

	deal_explosion_damage()
	
	queue_free()

func deal_explosion_damage():
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	var shape = SphereShape3D.new()
	shape.radius = explosion_radius
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result["collider"]
		
		if body.has_method("take_damage"):
			body.take_damage(explosion_damage)
			print("Dealt ", explosion_damage, " damage to ", body.name)
