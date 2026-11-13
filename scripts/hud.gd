class_name Hud
extends Control
## Everything drawn over the game view: the weapon, muzzle flash, crosshair,
## stats, messages and the red damage flash.

var player: Player
var total_enemies := 0
var status: Label
var message: Label
var gun: TextureRect
var flash: TextureRect
var damage: ColorRect
var _recoil := 0.0
var _flash_t := 0.0
var _message_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

	gun = TextureRect.new()
	gun.texture = Tex.get_texture("gun")
	gun.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gun.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash = TextureRect.new()
	flash.texture = Tex.get_texture("flash")
	flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.visible = false
	add_child(flash)
	add_child(gun)

	status = _label(14, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	status.position = Vector2(8, 6)
	message = _label(22, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	message.set_anchors_preset(Control.PRESET_FULL_RECT)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	damage = ColorRect.new()
	damage.color = Color(0.9, 0.05, 0.0, 0.0)
	damage.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage)


func _label(font_size: int, h: HorizontalAlignment, v: VerticalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = h
	l.vertical_alignment = v
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func show_message(text: String, seconds := 0.0) -> void:
	message.text = text
	_message_t = seconds


func on_fired() -> void:
	_recoil = 1.0
	_flash_t = 0.07


func on_hurt() -> void:
	damage.color.a = 0.45


func _process(delta: float) -> void:
	_recoil = move_toward(_recoil, 0.0, delta * 6.0)
	_flash_t -= delta
	damage.color.a = move_toward(damage.color.a, 0.0, delta * 1.5)
	if _message_t > 0.0:
		_message_t -= delta
		if _message_t <= 0.0:
			message.text = ""

	var gh := size.y * 0.42
	var gw := gh * 64.0 / 48.0
	var bob := Vector2.ZERO
	if is_instance_valid(player):
		bob = Vector2(sin(player.bob_time * 0.85) * gw * 0.06, absf(cos(player.bob_time * 0.85)) * gh * 0.05)
		status.text = "HEALTH %d    AMMO %d    KILLS %d/%d" % [player.health, player.ammo, player.kills, total_enemies]
		gun.visible = player.alive
	gun.size = Vector2(gw, gh)
	gun.position = Vector2((size.x - gw) * 0.5, size.y - gh) + bob + Vector2(0, gh * (0.06 + _recoil * 0.12))
	flash.visible = _flash_t > 0.0 and gun.visible
	flash.size = Vector2(gw * 0.5, gw * 0.375)
	flash.position = gun.position + Vector2((gw - flash.size.x) * 0.5, -flash.size.y * 0.55)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var col := Color(1, 1, 1, 0.7)
	draw_line(c - Vector2(6, 0), c - Vector2(2, 0), col, 1.0)
	draw_line(c + Vector2(2, 0), c + Vector2(6, 0), col, 1.0)
	draw_line(c - Vector2(0, 6), c - Vector2(0, 2), col, 1.0)
	draw_line(c + Vector2(0, 2), c + Vector2(0, 6), col, 1.0)
