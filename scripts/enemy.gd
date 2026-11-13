class_name Enemy
extends CharacterBody3D
## A sprite enemy. It waits until it sees the player, then follows the grid
## toward them and throws fireballs whenever it has a clear line of sight.

signal killed

const SPEED := 2.6
const SIGHT := 18.0
const ATTACK_RANGE := 14.0
const SPRITE_PX := 0.0375   # 40 px tall sprite -> 1.5 m

var level: Level
var player: Player
var hp := 3
var dead := false
var sprite: Sprite3D
var _awake := false
var _attack_cd := 0.0
var _attack_pose := 0.0
var _hurt := 0.0
var _anim := 0.0
var _target_cell := Vector2i.ZERO


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.5
	shape.shape = cap
	shape.position.y = 0.75
	add_child(shape)

	sprite = Sprite3D.new()
	sprite.texture = Tex.get_texture("enemy_walk0")
	sprite.pixel_size = SPRITE_PX
	sprite.position.y = 0.75
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(sprite)

	add_to_group("enemies")
	_attack_cd = randf_range(1.0, 2.5)
	_target_cell = level.cell_of(position)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	sprite.modulate = Color.WHITE * Level.light_at(dist)
	sprite.modulate.a = 1.0
	if dead:
		return

	_hurt -= delta
	_attack_pose -= delta
	_anim += delta
	var sees := dist < SIGHT and _can_see_player()
	if sees:
		_awake = true
	if not _awake or not player.alive:
		_update_sprite(false)
		return

	_attack_cd -= delta
	if sees and _attack_cd <= 0.0 and dist < ATTACK_RANGE:
		_shoot()
		_attack_cd = randf_range(1.6, 2.8)
		_attack_pose = 0.45

	var moving := false
	velocity = Vector3.ZERO
	if _attack_pose <= 0.0 and _hurt <= 0.0 and dist > 1.8:
		var my_cell := level.cell_of(global_position)
		var player_cell := level.cell_of(player.global_position)
		var dir := Vector3.ZERO
		if my_cell == player_cell:
			dir = to_player.normalized()
		else:
			# Walk cell centre to cell centre, picking the next cell on the
			# shortest route each time one is reached.
			var to_target := level.cell_center(_target_cell) - global_position
			to_target.y = 0.0
			var lost := _target_cell != my_cell and not _is_neighbour(my_cell, _target_cell)
			if to_target.length() < 0.2 or lost:
				_target_cell = level.next_step(my_cell, player_cell)
				to_target = level.cell_center(_target_cell) - global_position
				to_target.y = 0.0
			dir = to_target.normalized() if to_target.length() > 0.01 else Vector3.ZERO
		velocity = dir * SPEED
		moving = true
	move_and_slide()
	position.y = 0.0
	_update_sprite(moving)


func _is_neighbour(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _can_see_player() -> bool:
	var from := global_position + Vector3(0, 1.0, 0)
	var to := player.global_position + Vector3(0, Player.EYE, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider == player


func _shoot() -> void:
	var from := global_position + Vector3(0, 1.0, 0)
	var target := player.global_position + Vector3(0, Player.EYE, 0)
	var dir := (target - from).normalized()
	var fb := Fireball.new()
	fb.direction = dir
	fb.position = from + dir * 0.55
	get_parent().add_child(fb)
	Sfx.play("fireball")


func take_damage(amount: int) -> void:
	if dead:
		return
	hp -= amount
	_hurt = 0.2
	_awake = true
	if hp <= 0:
		dead = true
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		sprite.texture = Tex.get_texture("enemy_dead")
		remove_from_group("enemies")
		Sfx.play("enemy_die")
		killed.emit()
	else:
		Sfx.play("enemy_hurt")
		_update_sprite(false)


func _update_sprite(moving: bool) -> void:
	var id := "enemy_walk0"
	if _hurt > 0.0:
		id = "enemy_hurt"
	elif _attack_pose > 0.0:
		id = "enemy_attack"
	elif moving and int(_anim / 0.22) % 2 == 1:
		id = "enemy_walk1"
	sprite.texture = Tex.get_texture(id)
