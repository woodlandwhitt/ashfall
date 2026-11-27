# First scene on launch (build 17): the Ashfall: Meridian intro plays (Loader) while the game scene loads on a worker
# thread behind it. Under the test hooks (any command-line arguments) it goes straight to the game.
extends Node

const MAIN := "res://main.tscn"
var t := 0.0
var skipped := false
var switching := false

func _ready() -> void:
	if LoadScreen.quiet():
		get_tree().change_scene_to_file.call_deferred(MAIN)
		set_process(false)
		return
	ResourceLoader.load_threaded_request(MAIN)
	LoadScreen.it().play_intro(func(): skipped = true)

func _process(d: float) -> void:
	if switching:
		return
	t += d
	var arr := []
	var st := ResourceLoader.load_threaded_get_status(MAIN, arr)
	if not arr.is_empty():
		LoadScreen.it().progress(float(arr[0]) * 0.55, "Loading")
	var intro_done := skipped or t > 4.6 + 4.4
	if st == ResourceLoader.THREAD_LOAD_LOADED and intro_done and not switching:
		switching = true
		LoadScreen.it().intro = false
		LoadScreen.it().building()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(MAIN))
	elif st == ResourceLoader.THREAD_LOAD_FAILED and not switching:
		switching = true
		get_tree().change_scene_to_file(MAIN)
