class_name Fireball
extends Area3D
## A slow, dodgeable projectile thrown by enemies.

const SPEED := 8.0
const DAMAGE := 12

var direction := Vector3.FORWARD
var _life := 5.0
var _sprite: Sprite3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	shape.shape = sphere
	add_child(shape)
	_sprite = Sprite3D.new()
	_sprite.texture = Tex.get_texture("fireball")
	_sprite.pixel_size = 0.045
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta
	_life -= delta
	_sprite.rotation.z += delta * 8.0
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		(body as Player).take_damage(DAMAGE)
	queue_free()
