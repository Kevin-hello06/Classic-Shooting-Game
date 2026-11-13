class_name Player
extends CharacterBody3D
## First-person player: Doom-style fast movement, no jumping, turning only
## left and right, and a hitscan blaster with a little aim assist for touch.

signal stats_changed
signal fired
signal hurt
signal died

const SPEED := 6.0
const TURN_SPEED := 2.6          # keyboard turning, radians per second
const TOUCH_TURN := 0.011        # radians per screen unit dragged
const MOUSE_TURN := 0.0025
const FIRE_DELAY := 0.32
const EYE := 1.0
const AIM_ASSIST := 0.09         # radians either side of the crosshair

var health := 100
var ammo := 40
var kills := 0
var alive := true
var bob_time := 0.0
var controls: TouchControls
var camera: Camera3D
var _cooldown := 0.0


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1 | 4
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.4
	shape.shape = cap
	shape.position.y = 0.7
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = EYE
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 80.0
	add_child(camera)
	camera.make_current()
	add_to_group("player")


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not alive:
		velocity = Vector3.ZERO
		return

	var fwd := Input.get_axis("move_back", "move_forward")
	var strafe := Input.get_axis("strafe_left", "strafe_right")
	var turn := Input.get_axis("turn_right", "turn_left")
	if controls:
		fwd -= controls.move_vec.y
		strafe += controls.move_vec.x
		rotation.y -= controls.take_look() * TOUCH_TURN
	rotation.y += turn * TURN_SPEED * delta

	var dir := -global_transform.basis.z * fwd + global_transform.basis.x * strafe
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity = dir * SPEED
	move_and_slide()
	position.y = 0.0

	bob_time += delta * velocity.length()
	camera.position.y = EYE + sin(bob_time * 1.7) * 0.035

	if Input.is_action_pressed("fire") or (controls and controls.fire_held):
		try_fire()


func try_fire() -> void:
	if _cooldown > 0.0 or not alive:
		return
	_cooldown = FIRE_DELAY
	if ammo <= 0:
		Sfx.play("click")
		return
	ammo -= 1
	fired.emit()
	Sfx.play("shot")
	var target := _find_target()
	if target:
		target.take_damage(1)
	stats_changed.emit()


## Straight down the crosshair first; if that misses, the nearest visible
## enemy within a narrow cone. Makes thumb aiming forgiving.
func _find_target() -> Enemy:
	var from := camera.global_position
	var forward := -global_transform.basis.z
	var hit := _ray(from, from + forward * 60.0, 1 | 4)
	if hit and hit.collider is Enemy:
		return hit.collider
	var best: Enemy = null
	var best_angle := AIM_ASSIST
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		var to := enemy.global_position - global_position
		to.y = 0.0
		var angle := absf(forward.signed_angle_to(to, Vector3.UP))
		if angle >= best_angle or to.length() > 40.0:
			continue
		var check := _ray(from, enemy.global_position + Vector3(0, EYE, 0), 1 | 4)
		if check and check.collider == enemy:
			best = enemy
			best_angle = angle
	return best


func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


func take_damage(amount: int) -> void:
	if not alive:
		return
	health = maxi(health - amount, 0)
	hurt.emit()
	stats_changed.emit()
	if health == 0:
		alive = false
		Sfx.play("die")
		var t := create_tween()
		t.tween_property(camera, "position:y", 0.25, 0.6).set_ease(Tween.EASE_OUT)
		died.emit()
	else:
		Sfx.play("hurt")


func heal(amount: int) -> bool:
	if health >= 100:
		return false
	health = mini(health + amount, 100)
	stats_changed.emit()
	return true


func add_ammo(amount: int) -> bool:
	if ammo >= 99:
		return false
	ammo = mini(ammo + amount, 99)
	stats_changed.emit()
	return true
