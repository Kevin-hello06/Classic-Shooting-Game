extends Control
## Fold Blaster: sets up the screen layout, loads levels and runs the game flow.
##
## Levels are plain text below - edit them, or add more to MAPS.
## See level.gd for what each character means.

const MAPS := [
	[
		"########################",
		"#P....#.......%%%%%....#",
		"#.....#..E....%...%..E.#",
		"#..h..........%.a.%....#",
		"#.....#.......%%.%%....#",
		"###.###..a.............#",
		"#.....###.#######.######",
		"#..E....#.#.....#......#",
		"#.......#.#..E..#..E...#",
		"#.a.....#.#.....#......#",
		"##.######.###.###.##.###",
		"#......................#",
		"#..h......E.......a..X.#",
		"########################",
	],
	[
		"%%%%%%%%%%%%%%%%%%%%%%%%",
		"%P.....%.........%.....%",
		"%......%....E....%..E..%",
		"%..a...%.........%.....%",
		"%......%%%%.%%%%%%..h..%",
		"%%%.%%%%.........%.....%",
		"%.....E.....#....%%.%%%%",
		"%.....###########......%",
		"%..E..#.......E.#...E..%",
		"%.....#..h......#......%",
		"%%.%%%#...a.....#%%.%%%%",
		"%.......E.......E......%",
		"%..a.......E.........X.%",
		"%%%%%%%%%%%%%%%%%%%%%%%%",
	],
]

## The screen counts as "unfolded" when its height is at least this fraction
## of its width. The Fold's inner screen is close to square.
const SPLIT_RATIO := 0.8
## Render the 3D view at 1/N resolution for chunky retro pixels.
const PIXEL_SCALE := 2

var level_index := 0
var state := "playing"          # playing / dead / level_done / won
var is_split := false
var game_box: SubViewportContainer
var sub: SubViewport
var world: Node3D
var level: Level
var player: Player
var hud: Hud
var controls: TouchControls
var total_enemies := 0
var _state_timer := 0.0


func _ready() -> void:
	_setup_input()
	game_box = SubViewportContainer.new()
	game_box.stretch = true
	game_box.stretch_shrink = PIXEL_SCALE
	game_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	game_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_box)
	sub = SubViewport.new()
	game_box.add_child(sub)
	hud = Hud.new()
	add_child(hud)
	controls = TouchControls.new()
	add_child(controls)
	controls.tapped.connect(_on_tap)
	resized.connect(_layout)

	load_level(0)
	_layout()

	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		add_child(load("res://tests/autotest.gd").new())
	elif "--screenshots" in args:
		add_child(load("res://tests/screenshots.gd").new())


## Keyboard and mouse bindings for laptop play. Kept in code so they're easy
## to see and change; you can also move them into Project Settings > Input Map.
func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("strafe_left", [KEY_A])
	_bind("strafe_right", [KEY_D])
	_bind("turn_left", [KEY_LEFT, KEY_Q])
	_bind("turn_right", [KEY_RIGHT, KEY_E])
	_bind("fire", [KEY_SPACE, KEY_CTRL])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", click)


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func load_level(index: int, carry_stats := false) -> void:
	var old_health := 100
	var old_ammo := 40
	if carry_stats and is_instance_valid(player):
		old_health = player.health
		old_ammo = player.ammo
	level_index = index
	if world:
		world.queue_free()
	world = Node3D.new()
	sub.add_child(world)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	world.add_child(env)

	level = Level.new()
	world.add_child(level)
	level.build(MAPS[index])

	player = Player.new()
	player.controls = controls
	player.health = old_health
	player.ammo = old_ammo
	player.position = level.cell_center(level.player_start)
	player.rotation.y = level.best_yaw(level.player_start)
	world.add_child(player)
	player.fired.connect(hud.on_fired)
	player.hurt.connect(hud.on_hurt)
	player.died.connect(_on_player_died)

	for c in level.enemy_cells:
		var e := Enemy.new()
		e.level = level
		e.player = player
		e.position = level.cell_center(c)
		e.killed.connect(_on_enemy_killed)
		world.add_child(e)
	for c in level.health_cells:
		_spawn_pickup("health", c)
	for c in level.ammo_cells:
		_spawn_pickup("ammo", c)
	var exit := ExitZone.new()
	exit.position = level.cell_center(level.exit_cell)
	exit.reached.connect(_on_exit_reached)
	world.add_child(exit)

	total_enemies = level.enemy_cells.size()
	hud.player = player
	hud.total_enemies = total_enemies
	controls.level = level
	controls.player = player
	state = "playing"
	hud.show_message("LEVEL %d" % (index + 1), 1.5)


func _spawn_pickup(kind: String, c: Vector2i) -> void:
	var p := Pickup.new(kind)
	p.position = level.cell_center(c)
	world.add_child(p)


func _layout() -> void:
	apply_layout(size)


func apply_layout(s: Vector2) -> void:
	is_split = s.y >= s.x * SPLIT_RATIO
	var game := Rect2(Vector2.ZERO, s)
	var panel := Rect2(Vector2.ZERO, s)
	if is_split:
		var gh := minf(s.x * 0.75, s.y * 0.62)
		game = Rect2(0, 0, s.x, gh)
		panel = Rect2(0, gh, s.x, s.y - gh)
	game_box.position = game.position
	game_box.size = game.size
	hud.position = game.position
	hud.size = game.size
	controls.set_layout(is_split, panel, game)


func _process(delta: float) -> void:
	_state_timer -= delta
	match state:
		"level_done":
			if _state_timer <= 0.0:
				load_level(level_index + 1, true)
		"dead", "won":
			if _state_timer <= 0.0 and Input.is_action_just_pressed("fire"):
				_restart()


func _on_tap() -> void:
	if state in ["dead", "won"] and _state_timer <= 0.0:
		_restart()


func _restart() -> void:
	load_level(0 if state == "won" else level_index)


func _on_enemy_killed() -> void:
	player.kills += 1


func _on_player_died() -> void:
	state = "dead"
	_state_timer = 1.0
	hud.show_message("YOU DIED\nTap or press fire to try again")


func _on_exit_reached() -> void:
	if state != "playing":
		return
	Sfx.play("exit")
	var kills := "Kills %d/%d" % [player.kills, total_enemies]
	if level_index + 1 < MAPS.size():
		state = "level_done"
		_state_timer = 2.0
		hud.show_message("LEVEL COMPLETE\n" + kills)
	else:
		state = "won"
		_state_timer = 1.0
		hud.show_message("YOU ESCAPED!\n%s\nTap or press fire to play again" % kills)


func _unhandled_input(event: InputEvent) -> void:
	# Laptop: click to capture the mouse and turn with it; Esc releases it.
	if event is InputEventMouseButton and event.pressed and not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if is_instance_valid(player) and player.alive:
			player.rotation.y -= (event as InputEventMouseMotion).relative.x * Player.MOUSE_TURN
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
