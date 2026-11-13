class_name Pickup
extends Area3D
## Health or ammo lying on the floor. Walk over it to collect it; it stays
## put if you're already full.

const HEALTH_AMOUNT := 25
const AMMO_AMOUNT := 15

var kind := "health"
var _sprite: Sprite3D
var _t := 0.0


func _init(pickup_kind := "health") -> void:
	kind = pickup_kind


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	shape.position.y = 0.5
	add_child(shape)
	_sprite = Sprite3D.new()
	_sprite.texture = Tex.get_texture(kind)
	_sprite.pixel_size = 0.04
	_sprite.position.y = 0.35
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.shaded = false
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(_sprite)
	_t = randf() * TAU


func _physics_process(delta: float) -> void:
	_t += delta
	_sprite.position.y = 0.35 + sin(_t * 3.0) * 0.05
	for body in get_overlapping_bodies():
		if body is Player:
			var p := body as Player
			var used := p.heal(HEALTH_AMOUNT) if kind == "health" else p.add_ammo(AMMO_AMOUNT)
			if used:
				Sfx.play("pickup")
				queue_free()
				return
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var d := (players[0] as Node3D).global_position.distance_to(global_position)
		_sprite.modulate = Color.WHITE * Level.light_at(d)
		_sprite.modulate.a = 1.0
