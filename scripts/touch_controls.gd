class_name TouchControls
extends Control
## Multi-touch controls plus the Fold's bottom panel.
##
## Split layout (unfolded / Flex mode, the screen is tall or square):
##   the game sits on top, and the bottom panel holds the move stick (left),
##   the automap (middle) and the fire button (right). Drag anywhere else on
##   the panel or the game view to turn.
## Overlay layout (cover screen held sideways, or a laptop window):
##   the controls float over the game - left side moves, right side turns.

signal tapped

const DEADZONE := 0.12

var split := false
var panel_rect := Rect2()
var game_rect := Rect2()
var show_touch := false
var level: Level
var player: Player

var move_vec := Vector2.ZERO
var fire_held := false
var stick_radius := 50.0
var fire_center := Vector2.ZERO
var fire_radius := 40.0

var _look_accum := 0.0
var _touches := {}             # finger index -> "move" / "look" / "fire"
var _stick_home := Vector2.ZERO
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	show_touch = DisplayServer.is_touchscreen_available()


func set_layout(is_split: bool, panel: Rect2, game: Rect2) -> void:
	split = is_split
	panel_rect = panel
	game_rect = game
	if split:
		stick_radius = clampf(minf(panel.size.y * 0.28, panel.size.x * 0.13), 30.0, 110.0)
		_stick_home = Vector2(panel.position.x + stick_radius * 1.6, panel.position.y + panel.size.y * 0.55)
		fire_radius = stick_radius * 0.9
		fire_center = Vector2(panel.end.x - stick_radius * 1.6, panel.position.y + panel.size.y * 0.55)
	else:
		stick_radius = clampf(game.size.y * 0.15, 28.0, 80.0)
		_stick_home = Vector2(game.position.x + stick_radius * 1.7, game.end.y - stick_radius * 1.7)
		fire_radius = stick_radius * 0.8
		fire_center = Vector2(game.end.x - fire_radius * 1.8, game.end.y - fire_radius * 2.0)
	if not _touches.values().has("move"):
		_stick_origin = _stick_home
		_stick_pos = _stick_home
	queue_redraw()


## Turning input gathered since the last physics frame.
func take_look() -> float:
	var v := _look_accum
	_look_accum = 0.0
	return v


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		show_touch = true
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			_release(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_drag(drag.index, drag.position, drag.relative)


func _press(index: int, pos: Vector2) -> void:
	var role := "look"
	if pos.distance_to(fire_center) <= fire_radius * 1.3:
		role = "fire"
		fire_held = true
	elif _in_move_zone(pos) and not _touches.values().has("move"):
		role = "move"
		_stick_origin = pos
		_stick_pos = pos
		move_vec = Vector2.ZERO
	_touches[index] = role
	tapped.emit()
	queue_redraw()


func _in_move_zone(pos: Vector2) -> bool:
	if split:
		return panel_rect.has_point(pos) and pos.x < panel_rect.position.x + panel_rect.size.x * 0.4
	return pos.x < game_rect.position.x + game_rect.size.x * 0.4


func _drag(index: int, pos: Vector2, relative: Vector2) -> void:
	var role: String = _touches.get(index, "")
	match role:
		"move":
			var off := pos - _stick_origin
			if off.length() > stick_radius:
				off = off.normalized() * stick_radius
			_stick_pos = _stick_origin + off
			move_vec = off / stick_radius
			if move_vec.length() < DEADZONE:
				move_vec = Vector2.ZERO
		"look", "fire":
			# Sliding off the fire button keeps shooting and turns you,
			# so you can aim and fire with one thumb.
			_look_accum += relative.x
	queue_redraw()


func _release(index: int) -> void:
	var role: String = _touches.get(index, "")
	_touches.erase(index)
	if role == "move":
		move_vec = Vector2.ZERO
		_stick_origin = _stick_home
		_stick_pos = _stick_home
	elif role == "fire":
		fire_held = false
	queue_redraw()


func _process(_delta: float) -> void:
	if split:
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if split:
		draw_rect(panel_rect, Color(0.08, 0.08, 0.09))
		draw_rect(Rect2(panel_rect.position, Vector2(panel_rect.size.x, 3)), Color(0.35, 0.3, 0.25))
		var map_area := panel_rect.grow(-10.0)
		if show_touch:
			var left := _stick_home.x + stick_radius * 1.5
			var right := fire_center.x - fire_radius * 1.6
			map_area = Rect2(left, panel_rect.position.y + 12.0, right - left, panel_rect.size.y - 24.0)
		_draw_map(map_area)
	if not show_touch:
		return
	var a := 0.55 if split else 0.3
	draw_circle(_stick_origin, stick_radius, Color(1, 1, 1, a * 0.35))
	draw_arc(_stick_origin, stick_radius, 0.0, TAU, 40, Color(1, 1, 1, a), 2.0)
	draw_circle(_stick_pos, stick_radius * 0.45, Color(1, 1, 1, a + 0.15))
	var fire_col := Color(1.0, 0.35, 0.2, (a + 0.25) if fire_held else a)
	draw_circle(fire_center, fire_radius, fire_col)
	draw_arc(fire_center, fire_radius, 0.0, TAU, 40, Color(1, 0.8, 0.6, a + 0.2), 2.0)
	var fs := int(clampf(fire_radius * 0.38, 10.0, 28.0))
	draw_string(font, fire_center + Vector2(-fire_radius, fs * 0.35), "FIRE", HORIZONTAL_ALIGNMENT_CENTER, fire_radius * 2.0, fs, Color(1, 1, 1, 0.9))


## The Doom-style automap: walls, the exit, enemies and an arrow for you.
func _draw_map(area: Rect2) -> void:
	if level == null or area.size.x < 20.0 or area.size.y < 20.0:
		return
	var cs := minf(area.size.x / level.w, area.size.y / level.h)
	var map_size := Vector2(level.w, level.h) * cs
	var origin := area.position + (area.size - map_size) * 0.5
	draw_rect(Rect2(origin, map_size), Color(0.02, 0.03, 0.02))
	for y in level.h:
		for x in level.w:
			var c := Vector2i(x, y)
			if level.is_wall(c):
				var edge := false
				for d in Level.DIRS:
					edge = edge or not level.is_wall(c + d)
				if edge:
					draw_rect(Rect2(origin + Vector2(x, y) * cs, Vector2(cs, cs)), Color(0.25, 0.55, 0.3))
	if level.exit_cell.x >= 0:
		draw_rect(Rect2(origin + Vector2(level.exit_cell) * cs, Vector2(cs, cs)), Color(0.5, 1.0, 0.6))
	var k := cs / Level.CELL
	for e in get_tree().get_nodes_in_group("enemies"):
		var ep := (e as Node3D).global_position
		draw_circle(origin + Vector2(ep.x, ep.z) * k, maxf(cs * 0.3, 2.0), Color(1.0, 0.3, 0.2))
	if is_instance_valid(player):
		var p := player.global_position
		var centre := origin + Vector2(p.x, p.z) * k
		var yaw := player.rotation.y
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var side := Vector2(-fwd.y, fwd.x)
		var r := maxf(cs * 0.7, 4.0)
		draw_colored_polygon(PackedVector2Array([
			centre + fwd * r, centre - fwd * r * 0.6 + side * r * 0.6, centre - fwd * r * 0.6 - side * r * 0.6
		]), Color(1.0, 0.9, 0.3))
