# Fetching an update from GitHub. Each build's release carries "patch-bN.pck": everything that changed since build N
# (the build the APK was made from). The title screen asks the releases list whether there's a newer one for this
# APK, and if you say yes, downloads it in the background; it's mounted the next time the game starts (patcher.gd).
class_name Updater
extends Node

const API := "https://api.github.com/repos/woodlandwhitt/ashfall/releases?per_page=20"
signal found(build: int, size_mb: float)
signal progress(frac: float)
signal finished(ok: bool, msg: String)

var newest := {}          # {build, url, size}
var http: HTTPRequest
var busy := false

func check() -> void:
	var P = get_node_or_null("/root/Patcher")
	if P == null or busy:
		return
	busy = true
	http = HTTPRequest.new()
	add_child(http)
	http.timeout = 20.0
	http.request_completed.connect(_listed)
	if http.request(API, ["Accept: application/vnd.github+json", "User-Agent: AshfallMeridian"]) != OK:
		busy = false

func _listed(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var list = JSON.parse_string(body.get_string_from_utf8())
	if not (list is Array):
		return
	var P = get_node("/root/Patcher")
	var want := "patch-b%d.pck" % int(P.base_build)
	for r in list:
		var tag := String(r.get("tag_name", ""))
		if not tag.begins_with("godot-"):
			continue
		var b := int(tag.trim_prefix("godot-"))
		if b <= int(P.build) or b <= int(newest.get("build", 0)):
			continue
		for a in r.get("assets", []):
			if String(a.get("name", "")) == want:
				newest = {"build": b, "url": String(a.browser_download_url), "size": int(a.get("size", 0))}
	if not newest.is_empty():
		found.emit(int(newest.build), float(newest.size) / 1048576.0)

func download() -> void:
	if newest.is_empty() or busy:
		return
	busy = true
	http = HTTPRequest.new()
	add_child(http)
	http.download_file = "user://patch_dl.pck"
	http.use_threads = true
	http.request_completed.connect(_downloaded)
	http.request(String(newest.url), ["User-Agent: AshfallMeridian"])
	_poll()

func _poll() -> void:
	while busy and is_instance_valid(http):
		var total := maxi(1, http.get_body_size() if http.get_body_size() > 0 else int(newest.size))
		progress.emit(clampf(float(http.get_downloaded_bytes()) / total, 0.0, 1.0))
		await get_tree().create_timer(0.25).timeout

func _downloaded(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	busy = false
	http.queue_free()
	var path := ProjectSettings.globalize_path("user://patch_dl.pck")
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(path)
		finished.emit(false, "The download didn't finish (%d). Try again later." % code)
		return
	var f := FileAccess.open("user://patch_dl.pck", FileAccess.READ)
	var size := f.get_length() if f else 0
	f = null
	if int(newest.size) > 0 and size != int(newest.size):
		DirAccess.remove_absolute(path)
		finished.emit(false, "The download was incomplete. Try again.")
		return
	DirAccess.rename_absolute(path, ProjectSettings.globalize_path("user://patch.pck"))
	var P = get_node("/root/Patcher")
	var j := FileAccess.open("user://patch.json", FileAccess.WRITE)
	j.store_string(JSON.stringify({"build": int(newest.build), "base": int(P.base_build)}))
	j = null
	finished.emit(true, "Build %d is ready. Close the game and open it again to play it." % int(newest.build))
