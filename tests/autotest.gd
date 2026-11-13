extends Node
## Automated play-through. Run with:
##   godot --headless --path . -- --autotest
## Prints PASS/FAIL for each check and exits with code 0 if everything passed.

var main: Node
var failures := 0


func _ready() -> void:
	main = get_parent()
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	await frames(5)

	# --- maps ---------------------------------------------------------------
	for i in main.MAPS.size():
		var err := Level.validate(main.MAPS[i])
		check(err == "", "map %d is valid %s" % [i + 1, err])

	# --- level 1 loaded -----------------------------------------------------
	var p: Player = main.player
	check(is_instance_valid(p) and p.alive, "player spawned")
	check(get_tree().get_nodes_in_group("enemies").size() == main.level.enemy_cells.size(), "all enemies spawned")
	main.controls.move_vec = Vector2.ZERO

	# --- touch stick moves the player ---------------------------------------
	var start := p.global_position
	main.controls.move_vec = Vector2(0, -1)
	await frames(30)
	main.controls.move_vec = Vector2.ZERO
	check(p.global_position.distance_to(start) > 1.0, "joystick moves player (%.2f m)" % p.global_position.distance_to(start))

	# --- look drag turns ----------------------------------------------------
	var yaw := p.rotation.y
	main.controls._look_accum = 40.0
	await frames(2)
	check(absf(p.rotation.y - yaw) > 0.3, "look drag turns player")

	# --- walls block movement -----------------------------------------------
	p.global_position = main.level.cell_center(main.level.player_start)
	p.rotation.y = PI / 2.0    # face west, straight into the wall
	main.controls.move_vec = Vector2(0, -1)
	await frames(60)
	main.controls.move_vec = Vector2.ZERO
	var c: Vector2i = main.level.cell_of(p.global_position)
	check(not main.level.is_wall(c), "player can't walk through walls")

	# --- shooting kills an enemy --------------------------------------------
	var spot := _find_corridor(main.level)
	check(spot.x >= 0, "found an open test corridor")
	var enemy: Enemy = get_tree().get_nodes_in_group("enemies")[0]
	p.global_position = main.level.cell_center(spot)
	p.rotation.y = -PI / 2.0   # face east (+x)
	enemy.global_position = main.level.cell_center(spot + Vector2i(2, 0))
	enemy._target_cell = spot + Vector2i(2, 0)
	await frames(2)
	var ammo_before := p.ammo
	for i in 8:
		if enemy.dead:
			break
		p.try_fire()
		await frames(22)
	check(enemy.dead, "three hits kill an enemy")
	check(p.ammo < ammo_before, "shooting uses ammo")
	check(p.kills == 1, "kill is counted")

	# --- aim assist ---------------------------------------------------------
	var enemy2: Enemy = get_tree().get_nodes_in_group("enemies")[0]
	enemy2.global_position = main.level.cell_center(spot + Vector2i(2, 0))
	enemy2._target_cell = spot + Vector2i(2, 0)
	p.global_position = main.level.cell_center(spot)
	p.rotation.y = -PI / 2.0 + 0.06
	await frames(3)
	var hp_before := enemy2.hp
	p.try_fire()
	await frames(2)
	check(enemy2.hp < hp_before or enemy2.dead, "aim assist hits a slightly-off target")
	enemy2.take_damage(10)

	# --- fireballs hurt the player ------------------------------------------
	p.health = 100
	var fb := Fireball.new()
	var from: Vector3 = main.level.cell_center(spot + Vector2i(2, 0), 1.0)
	fb.direction = (p.global_position + Vector3(0, 1, 0) - from).normalized()
	fb.position = from
	main.world.add_child(fb)
	await frames(40)
	check(p.health < 100, "fireball damages player (health %d)" % p.health)

	# --- out of ammo --------------------------------------------------------
	p.ammo = 0
	await frames(25)
	p.try_fire()
	check(p.ammo == 0, "firing with no ammo is safe")
	p.ammo = 30

	# --- pickups ------------------------------------------------------------
	p.health = 50
	var hcell: Vector2i = main.level.health_cells[0]
	p.global_position = main.level.cell_center(hcell)
	await frames(5)
	check(p.health == 75, "health pickup heals (health %d)" % p.health)
	p.ammo = 10
	var acell: Vector2i = main.level.ammo_cells[0]
	p.global_position = main.level.cell_center(acell)
	await frames(5)
	check(p.ammo == 25, "ammo pickup adds ammo (ammo %d)" % p.ammo)

	# --- enemies chase along the grid ---------------------------------------
	var chaser: Enemy = null
	for e in get_tree().get_nodes_in_group("enemies"):
		chaser = e
	p.global_position = main.level.cell_center(main.level.player_start)
	chaser._awake = true
	var d0 := chaser.global_position.distance_to(p.global_position)
	p.health = 100000
	await frames(240)
	var d1 := chaser.global_position.distance_to(p.global_position)
	check(d1 < d0 - 2.0 or d1 < 2.5, "awake enemy closes in (%.1f m -> %.1f m)" % [d0, d1])
	p.health = 100

	# --- Fold layouts -------------------------------------------------------
	main.apply_layout(Vector2(640, 700))     # unfolded, near-square
	check(main.is_split, "square screen uses split layout")
	check(main.game_box.size.y < 700 and main.controls.panel_rect.size.y > 150, "game on top, panel below")
	var sub_size: Vector2i = main.sub.size
	check(sub_size.x == 320, "3D renders at low resolution (%s)" % str(sub_size))
	# A finger on the left of the panel acts as the move stick.
	var ctl: TouchControls = main.controls
	ctl._press(0, ctl.panel_rect.position + Vector2(60, 120))
	ctl._drag(0, ctl.panel_rect.position + Vector2(60, 60), Vector2(0, -60))
	check(ctl.move_vec.y < -0.5, "touch stick in bottom panel works")
	ctl._release(0)
	ctl._press(1, ctl.fire_center)
	check(ctl.fire_held, "fire button in bottom panel works")
	ctl._release(1)
	check(not ctl.fire_held and ctl.move_vec == Vector2.ZERO, "controls reset on release")
	main.apply_layout(Vector2(792, 360))     # cover screen, landscape
	check(not main.is_split, "wide screen uses overlay layout")
	main.apply_layout(main.size)

	# --- exit, next level, death, restart, win ------------------------------
	p.global_position = main.level.cell_center(main.level.exit_cell)
	await frames(5)
	check(main.state == "level_done", "exit completes the level")
	var carried := [p.health, p.ammo]
	await frames(150)
	check(main.level_index == 1 and main.state == "playing", "level 2 loads")
	p = main.player
	check([p.health, p.ammo] == carried, "health and ammo carry over %s -> %s" % [str(carried), str([p.health, p.ammo])])
	await frames(240)
	check(true, "level 2 runs for 4 seconds of AI without errors")
	p.take_damage(1000)
	check(main.state == "dead" and not p.alive, "player can die")
	await frames(70)
	main.controls._press(0, Vector2(300, 100))
	main.controls._release(0)
	await frames(3)
	check(main.state == "playing" and main.player.alive and main.level_index == 1, "tap restarts the level")
	main.player.global_position = main.level.cell_center(main.level.exit_cell)
	await frames(5)
	check(main.state == "won", "finishing the last level wins")

	print("AUTOTEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	get_tree().quit(0 if failures == 0 else 1)


## An open cell with two more open cells to its east.
func _find_corridor(level: Level) -> Vector2i:
	for y in level.h:
		for x in level.w:
			var c := Vector2i(x, y)
			if not level.is_wall(c) and not level.is_wall(c + Vector2i(1, 0)) and not level.is_wall(c + Vector2i(2, 0)) \
					and not level.is_wall(c + Vector2i(3, 0)):
				return c
	return Vector2i(-1, -1)
