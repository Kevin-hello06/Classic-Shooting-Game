class_name Level
extends Node3D
## Builds a level from an ASCII map. Every character is one square cell:
##
##   #  brick wall        %  metal wall        .  floor
##   P  player start      E  enemy             X  exit (teleporter)
##   h  health pickup     a  ammo pickup
##
## Only wall faces that touch open floor are turned into geometry, so even a
## big map is a handful of triangles.

const CELL := 2.0
const WALL_H := 2.0
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const WALL_TEXTURES := {"#": "brick", "%": "metal"}

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform float min_light = 0.18;

void fragment() {
	vec4 c = texture(tex, UV);
	// Doom-style lighting: things get darker the further away they are.
	float b = clamp(1.35 - length(VERTEX) / 16.0, min_light, 1.0);
	ALBEDO = c.rgb * COLOR.rgb * b;
}
"""

static var _shader: Shader = null

var rows: Array[String] = []
var w := 0
var h := 0
var player_start := Vector2i.ZERO
var exit_cell := Vector2i(-1, -1)
var enemy_cells: Array[Vector2i] = []
var health_cells: Array[Vector2i] = []
var ammo_cells: Array[Vector2i] = []


## Same distance fade as the wall shader, for sprites.
static func light_at(distance: float) -> float:
	return clampf(1.35 - distance / 16.0, 0.18, 1.0)


static func make_material(tex_id: String, min_light := 0.18) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("tex", Tex.get_texture(tex_id))
	mat.set_shader_parameter("min_light", min_light)
	return mat


## Returns "" if the map is usable, otherwise a description of the problem.
static func validate(map: Array) -> String:
	if map.is_empty():
		return "map is empty"
	var width := String(map[0]).length()
	var starts := 0
	var exits := 0
	for y in map.size():
		var line := String(map[y])
		if line.length() != width:
			return "row %d is %d wide, expected %d" % [y, line.length(), width]
		for x in width:
			var ch := line[x]
			if ch not in ["#", "%", ".", "P", "E", "X", "h", "a"]:
				return "unknown character '%s' at %d,%d" % [ch, x, y]
			var edge := x == 0 or y == 0 or x == width - 1 or y == map.size() - 1
			if edge and ch != "#" and ch != "%":
				return "map edge is open at %d,%d" % [x, y]
			starts += 1 if ch == "P" else 0
			exits += 1 if ch == "X" else 0
	if starts != 1:
		return "map needs exactly one P"
	if exits != 1:
		return "map needs exactly one X"
	var lvl := Level.new()
	lvl._parse(map)
	var ok := lvl.next_step(lvl.player_start, lvl.exit_cell) != lvl.player_start
	lvl.free()
	return "" if ok else "exit can't be reached from the start"


func build(map: Array) -> void:
	_parse(map)
	_build_geometry()
	_build_collision()


func _parse(map: Array) -> void:
	rows.clear()
	for line in map:
		rows.append(String(line))
	h = rows.size()
	w = rows[0].length()
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			match rows[y][x]:
				"P":
					player_start = c
				"X":
					exit_cell = c
				"E":
					enemy_cells.append(c)
				"h":
					health_cells.append(c)
				"a":
					ammo_cells.append(c)


func is_wall(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return true
	var ch := rows[c.y][c.x]
	return ch == "#" or ch == "%"


func cell_center(c: Vector2i, y := 0.0) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, y, (c.y + 0.5) * CELL)


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


## Breadth-first search across the grid. Returns the neighbouring cell to
## step into to get from `from` toward `to`, or `from` if there's no route.
func next_step(from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to:
		return to
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	var i := 0
	while i < queue.size():
		var c := queue[i]
		i += 1
		if c == to:
			break
		for d in DIRS:
			var n := c + d
			if is_wall(n) or prev.has(n):
				continue
			prev[n] = c
			queue.append(n)
	if not prev.has(to):
		return from
	var step: Vector2i = to
	while prev[step] != from:
		step = prev[step]
	return step


## The yaw that faces down the longest open corridor from a cell.
func best_yaw(c: Vector2i) -> float:
	var best := 0
	var best_run := -1
	for i in DIRS.size():
		var run := 0
		var n := c + DIRS[i]
		while not is_wall(n):
			run += 1
			n += DIRS[i]
		if run > best_run:
			best_run = run
			best = i
	return [0.0, PI, PI / 2.0, -PI / 2.0][best]


func _build_geometry() -> void:
	var tools := {}
	for kind in WALL_TEXTURES:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[kind] = st
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not is_wall(c):
				continue
			for d in DIRS:
				if not is_wall(c + d):
					_add_wall_face(tools[rows[y][x]], c, d)
	for kind in tools:
		var mesh := (tools[kind] as SurfaceTool).commit()
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = make_material(WALL_TEXTURES[kind])
		add_child(mi)

	var size := Vector2(w * CELL, h * CELL)
	_add_flat(Rect2(Vector2.ZERO, size), 0.0, Vector2(w, h), "floor", 0.18)
	_add_flat(Rect2(Vector2.ZERO, size), WALL_H, Vector2(w, h), "ceiling", 0.18)
	if exit_cell.x >= 0:
		var r := Rect2(Vector2(exit_cell) * CELL, Vector2(CELL, CELL))
		_add_flat(r, 0.01, Vector2.ONE, "exit_floor", 0.8)


func _add_wall_face(st: SurfaceTool, c: Vector2i, d: Vector2i) -> void:
	var x0 := c.x * CELL
	var z0 := c.y * CELL
	var x1 := x0 + CELL
	var z1 := z0 + CELL
	var a: Vector3
	var b: Vector3
	match d:
		Vector2i(0, -1):
			a = Vector3(x1, 0, z0)
			b = Vector3(x0, 0, z0)
		Vector2i(0, 1):
			a = Vector3(x0, 0, z1)
			b = Vector3(x1, 0, z1)
		Vector2i(-1, 0):
			a = Vector3(x0, 0, z0)
			b = Vector3(x0, 0, z1)
		_:
			a = Vector3(x1, 0, z1)
			b = Vector3(x1, 0, z0)
	# East/west faces are a little darker, like in Wolfenstein and Doom.
	var shade := 1.0 if d.y != 0 else 0.78
	var up := Vector3(0, WALL_H, 0)
	_quad(st, [a, b, b + up, a + up], [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)], Color(shade, shade, shade))


func _add_flat(r: Rect2, y: float, uv_size: Vector2, tex_id: String, min_light: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0 := Vector3(r.position.x, y, r.position.y)
	var p1 := Vector3(r.end.x, y, r.position.y)
	var p2 := Vector3(r.end.x, y, r.end.y)
	var p3 := Vector3(r.position.x, y, r.end.y)
	_quad(st, [p0, p1, p2, p3], [Vector2.ZERO, Vector2(uv_size.x, 0), uv_size, Vector2(0, uv_size.y)], Color.WHITE)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = make_material(tex_id, min_light)
	add_child(mi)


func _quad(st: SurfaceTool, v: Array, uv: Array, col: Color) -> void:
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(col)
		st.set_uv(uv[i])
		st.add_vertex(v[i])


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not is_wall(c):
				continue
			var exposed := false
			for d in DIRS:
				exposed = exposed or not is_wall(c + d)
			if not exposed:
				continue
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(CELL, WALL_H, CELL)
			shape.shape = box
			shape.position = cell_center(c, WALL_H / 2.0)
			body.add_child(shape)
