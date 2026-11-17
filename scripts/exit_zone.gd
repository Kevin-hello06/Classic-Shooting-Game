class_name ExitZone
extends Area3D
## The glowing teleporter that ends the level. While `locked` it glows red
## and stepping on it only reports `blocked`.

signal reached
signal blocked

const OPEN_COLOR := Color(1, 1, 1)
const LOCKED_COLOR := Color(1.0, 0.25, 0.2)

var locked := false

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
	_sprite.modulate = LOCKED_COLOR if locked else OPEN_COLOR
	_sprite.modulate.a = (0.5 if locked else 0.75) + sin(_t * 5.0) * 0.25
	if _done:
		return
	for body in get_overlapping_bodies():
		if body is Player and (body as Player).alive:
			if locked:
				blocked.emit()
			else:
				_done = true
				reached.emit()
			return
