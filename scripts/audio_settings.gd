extends Node
## Music and sound on/off switches. Creates the "Music" and "SFX" audio buses,
## mutes them as needed and remembers the choice in user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"
const MUSIC_VOLUME_DB := -4.0

var music_on := true
var sound_on := true


func _enter_tree() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), MUSIC_VOLUME_DB)
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		music_on = cfg.get_value("audio", "music_on", true)
		sound_on = cfg.get_value("audio", "sound_on", true)
	_apply()


func toggle_music() -> void:
	set_music(not music_on)


func toggle_sound() -> void:
	set_sound(not sound_on)


func set_music(on: bool) -> void:
	music_on = on
	_apply()
	_save()


func set_sound(on: bool) -> void:
	sound_on = on
	_apply()
	_save()


func _apply() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sound_on)
	changed.emit()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "sound_on", sound_on)
	cfg.save(PATH)
