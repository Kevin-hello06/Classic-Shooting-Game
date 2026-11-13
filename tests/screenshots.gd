extends Node
## Saves preview screenshots of both layouts. Needs a real display:
##   godot --path . -- --screenshots
## Images go to user://screenshots/.

var main: Node


func _ready() -> void:
	main = get_parent()
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	img.save_png("user://screenshots/%s.png" % name)
	print("saved ", ProjectSettings.globalize_path("user://screenshots/%s.png" % name))


func _run() -> void:
	main.controls.show_touch = true
	main.controls.queue_redraw()
	var p: Player = main.player
	# Stand in the long bottom corridor of level 1 looking east toward an enemy.
	p.global_position = main.level.cell_center(Vector2i(3, 11))
	p.rotation.y = -PI / 2.0 + 0.08
	await frames(10)
	main.hud.on_fired()
	await _shot("overlay_landscape")

	get_window().size = Vector2i(1100, 1200)
	await frames(15)
	p.global_position = main.level.cell_center(Vector2i(2, 7))
	p.rotation.y = -PI / 2.0
	await frames(10)
	await _shot("split_unfolded")
	get_tree().quit()
