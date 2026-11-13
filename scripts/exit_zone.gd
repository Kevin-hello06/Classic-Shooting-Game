class_name ExitZone
extends Area3D
## The glowing teleporter that ends the level.

signal reached

var _sprite: Sprite3D
var _t := 0.0
var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(Level.CELL * 0.8, 1.5, Level.CELL * 0.8)
	shape.shape = box
	shape.position.y = 0.75
	add_child(shape)
	_sprite = Sprite3D.new()
	_sprite.texture = Tex.get_texture("teleporter")
	_sprite.pixel_size = 0.042
	_sprite.position.y = 1.0
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.shaded = false
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_t += delta
	_sprite.modulate.a = 0.75 + sin(_t * 5.0) * 0.25
	if _done:
		return
	for body in get_overlapping_bodies():
		if body is Player and (body as Player).alive:
			_done = true
			reached.emit()
			return
