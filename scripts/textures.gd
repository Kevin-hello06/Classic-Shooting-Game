class_name Tex
extends RefCounted
## Builds all of the game's pixel art in code, so the project ships with no
## image files at all. Each texture is made once and then cached.
##
## To swap in your own art later, replace a call to Tex.get_texture("brick")
## with preload("res://art/brick.png") and keep the same size.

static var _cache: Dictionary = {}


static func get_texture(id: String) -> ImageTexture:
	if not _cache.has(id):
		_cache[id] = ImageTexture.create_from_image(make_image(id))
	return _cache[id]


static func make_image(id: String) -> Image:
	match id:
		"brick":
			return _brick()
		"metal":
			return _metal()
		"floor":
			return _floor()
		"ceiling":
			return _ceiling()
		"exit_floor":
			return _exit_floor()
		"enemy_walk0":
			return _enemy(0)
		"enemy_walk1":
			return _enemy(1)
		"enemy_attack":
			return _enemy(2)
		"enemy_hurt":
			return _enemy(3)
		"enemy_dead":
			return _enemy(4)
		"health":
			return _health()
		"ammo":
			return _ammo()
		"gun":
			return _gun()
		"flash":
			return _flash()
		"fireball":
			return _fireball()
		"teleporter":
			return _teleporter()
	push_error("Unknown texture id: " + id)
	return _new(8, 8, Color.MAGENTA)


# --- drawing helpers -------------------------------------------------------

static func _new(w: int, h: int, c: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0), c.a)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var r := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.has_area():
		img.fill_rect(r, c)


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)


## Adds a one-pixel dark border around everything opaque, so sprites read
## clearly against the walls.
static func _outline(img: Image, c: Color) -> void:
	var src := img.duplicate() as Image
	var w := img.get_width()
	var h := img.get_height()
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in dirs:
				var nx := x + d.x
				var ny := y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.5:
					img.set_pixel(x, y, c)
					break


# --- walls, floors, ceilings (64 x 64, one per map cell) -------------------

static func _brick() -> Image:
	var rng := _rng(11)
	var img := _new(64, 64, Color(0.22, 0.2, 0.19))
	for row in 8:
		var off := 0 if row % 2 == 0 else 8
		for b in range(-1, 4):
			var x0 := b * 16 + off
			var base := Color(0.56, 0.23, 0.15).lerp(Color(0.46, 0.29, 0.21), rng.randf())
			for y in range(row * 8 + 1, row * 8 + 8):
				for x in range(x0 + 1, x0 + 16):
					if x < 0 or x >= 64:
						continue
					var f := 1.0 + rng.randf_range(-0.08, 0.08)
					if y == row * 8 + 1:
						f += 0.15
					elif y == row * 8 + 7:
						f -= 0.2
					img.set_pixel(x, y, _shade(base, f))
	return img


static func _metal() -> Image:
	var rng := _rng(22)
	var base := Color(0.33, 0.37, 0.42)
	var img := _new(64, 64, base)
	for y in 64:
		for x in 64:
			var f := 1.0 + rng.randf_range(-0.06, 0.06)
			var px := x % 32
			var py := y % 32
			if px == 0 or py == 0:
				f = 0.45
			elif px == 1 or py == 1:
				f += 0.25
			elif px == 31 or py == 31:
				f -= 0.25
			img.set_pixel(x, y, _shade(base, f))
	for ox in [0, 32]:
		for oy in [0, 32]:
			for cx in [4, 27]:
				for cy in [4, 27]:
					_rect(img, cx + ox, cy + oy, 2, 2, _shade(base, 1.6))
	for x in range(38, 60, 4):
		_rect(img, x, 42, 2, 14, _shade(base, 0.45))
	return img


static func _floor() -> Image:
	var rng := _rng(33)
	var img := _new(64, 64, Color(0.12, 0.11, 0.1))
	for ty in 4:
		for tx in 4:
			var base := Color(0.31, 0.27, 0.22).lerp(Color(0.26, 0.25, 0.24), rng.randf())
			for y in range(ty * 16 + 1, ty * 16 + 16):
				for x in range(tx * 16 + 1, tx * 16 + 16):
					img.set_pixel(x, y, _shade(base, 1.0 + rng.randf_range(-0.07, 0.07)))
	return img


static func _ceiling() -> Image:
	var rng := _rng(44)
	var base := Color(0.21, 0.21, 0.23)
	var img := _new(64, 64, base)
	for y in 64:
		for x in 64:
			var f := 1.0 + rng.randf_range(-0.08, 0.08)
			if x % 32 == 0 or y % 32 == 0:
				f = 0.55
			img.set_pixel(x, y, _shade(base, f))
	return img


static func _exit_floor() -> Image:
	var img := _new(64, 64, Color.BLACK)
	var base := Color(0.04, 0.18, 0.07)
	var bright := Color(0.35, 1.0, 0.45)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			var c := base.lerp(bright, clampf(1.0 - d, 0.0, 1.0) * 0.45)
			if x % 16 == 0 or y % 16 == 0:
				c = bright
			img.set_pixel(x, y, c)
	return img


# --- sprites ----------------------------------------------------------------

## The enemy: a horned, original "grunt" creature, 32 x 40 pixels.
## Frames: 0/1 walk, 2 attack, 3 hurt, 4 dead.
static func _enemy(frame: int) -> Image:
	var img := _new(32, 40, Color(0, 0, 0, 0))
	var skin := Color(0.62, 0.33, 0.2)
	var dark := Color(0.38, 0.17, 0.1)
	var eye := Color(1.0, 0.9, 0.2)
	var horn := Color(0.86, 0.82, 0.7)
	var outline := Color(0.08, 0.04, 0.03)
	if frame == 4:
		_ellipse(img, 16, 35, 13, 4.5, dark)
		_ellipse(img, 11, 33, 6, 3.5, skin)
		_ellipse(img, 21, 34, 5, 3, _shade(skin, 0.85))
		_rect(img, 6, 31, 2, 2, horn)
		_outline(img, outline)
		return img

	var step := 1 if frame == 1 else 0
	_rect(img, 10 - step * 2, 29, 4, 10, dark)
	_rect(img, 18 + step * 2, 29, 4, 10, dark)
	_ellipse(img, 16, 22, 9, 9.5, skin)
	_ellipse(img, 16, 24, 5, 5, _shade(skin, 1.18))
	if frame == 2:
		_rect(img, 4, 8, 4, 13, skin)
		_rect(img, 24, 8, 4, 13, skin)
		_ellipse(img, 6, 7, 3.5, 3.5, Color(1.0, 0.6, 0.1))
		_ellipse(img, 26, 7, 3.5, 3.5, Color(1.0, 0.6, 0.1))
		_ellipse(img, 6, 7, 1.8, 1.8, Color(1.0, 0.95, 0.6))
		_ellipse(img, 26, 7, 1.8, 1.8, Color(1.0, 0.95, 0.6))
	else:
		_rect(img, 5, 16 + step, 4, 11, skin)
		_rect(img, 23, 17 - step, 4, 11, skin)
	_ellipse(img, 16, 10, 6.5, 6, skin)
	_rect(img, 10, 2, 2, 4, horn)
	_rect(img, 20, 2, 2, 4, horn)
	_rect(img, 12, 9, 3, 2, eye)
	_rect(img, 17, 9, 3, 2, eye)
	_rect(img, 13, 13, 6, 1, Color(0.2, 0.05, 0.03))
	if frame == 3:
		for y in img.get_height():
			for x in img.get_width():
				var p := img.get_pixel(x, y)
				if p.a > 0.5:
					img.set_pixel(x, y, p.lerp(Color(1.0, 0.85, 0.8), 0.6))
	_outline(img, outline)
	return img


static func _health() -> Image:
	var img := _new(16, 16, Color(0, 0, 0, 0))
	_rect(img, 5, 2, 6, 2, Color(0.5, 0.5, 0.5))
	_rect(img, 1, 4, 14, 11, Color(0.84, 0.84, 0.8))
	_rect(img, 1, 4, 14, 2, Color(0.96, 0.96, 0.94))
	_rect(img, 7, 6, 2, 8, Color(0.85, 0.1, 0.1))
	_rect(img, 4, 9, 8, 2, Color(0.85, 0.1, 0.1))
	_outline(img, Color(0.1, 0.1, 0.1))
	return img


static func _ammo() -> Image:
	var img := _new(16, 16, Color(0, 0, 0, 0))
	var brass := Color(0.86, 0.7, 0.3)
	for x in [3, 7, 11]:
		_rect(img, x, 2, 2, 7, brass)
		_rect(img, x, 2, 2, 2, Color(0.7, 0.4, 0.2))
	_rect(img, 1, 8, 14, 7, Color(0.36, 0.39, 0.2))
	_rect(img, 1, 8, 14, 1, Color(0.5, 0.54, 0.3))
	_rect(img, 5, 10, 6, 3, Color(0.22, 0.24, 0.12))
	_outline(img, Color(0.08, 0.08, 0.05))
	return img


## The first-person weapon, seen from behind, 64 x 48.
static func _gun() -> Image:
	var img := _new(64, 48, Color(0, 0, 0, 0))
	var steel := Color(0.42, 0.44, 0.48)
	_rect(img, 27, 2, 10, 28, steel)
	_rect(img, 28, 2, 2, 28, _shade(steel, 1.45))
	_rect(img, 35, 2, 2, 28, _shade(steel, 0.75))
	_rect(img, 29, 2, 6, 2, Color(0.08, 0.08, 0.09))
	_rect(img, 21, 22, 22, 14, _shade(steel, 0.7))
	_rect(img, 23, 24, 18, 2, _shade(steel, 1.1))
	var skin := Color(0.86, 0.63, 0.46)
	_ellipse(img, 22, 41, 10, 7, skin)
	_ellipse(img, 42, 41, 10, 7, _shade(skin, 0.92))
	_rect(img, 8, 45, 48, 3, Color(0.2, 0.3, 0.18))
	_outline(img, Color(0.05, 0.05, 0.06))
	return img


static func _flash() -> Image:
	var img := _new(32, 24, Color(0, 0, 0, 0))
	var orange := Color(1.0, 0.55, 0.1)
	_rect(img, 15, 1, 2, 22, orange)
	_rect(img, 4, 11, 24, 2, orange)
	_ellipse(img, 16, 12, 10, 8, orange)
	_ellipse(img, 16, 12, 6.5, 5, Color(1.0, 0.85, 0.3))
	_ellipse(img, 16, 12, 3, 2.5, Color(1.0, 1.0, 0.9))
	return img


static func _fireball() -> Image:
	var img := _new(12, 12, Color(0, 0, 0, 0))
	for y in 12:
		for x in 12:
			var d := Vector2(x + 0.5 - 6.0, y + 0.5 - 6.0).length() / 6.0
			if d >= 1.0:
				continue
			var c := Color(1.0, 1.0, 0.85).lerp(Color(1.0, 0.75, 0.2), clampf(d * 1.6, 0.0, 1.0))
			c = c.lerp(Color(0.9, 0.25, 0.05), clampf(d * 1.6 - 0.8, 0.0, 1.0))
			c.a = clampf((1.0 - d) * 3.0, 0.0, 1.0)
			img.set_pixel(x, y, c)
	return img


static func _teleporter() -> Image:
	var img := _new(32, 48, Color(0, 0, 0, 0))
	for y in 48:
		for x in 32:
			var dx := absf(x + 0.5 - 16.0) / 16.0
			var a := clampf(1.0 - dx * 1.3, 0.0, 1.0)
			a *= 0.35 + 0.3 * absf(sin(y * 0.45 + x * 0.2))
			a *= 1.0 - float(y) / 48.0 * 0.5
			if a > 0.04:
				img.set_pixel(x, y, Color(0.45, 1.0, 0.55, a))
	return img
