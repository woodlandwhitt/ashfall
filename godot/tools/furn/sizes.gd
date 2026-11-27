extends SceneTree
# prints every catalogued piece's bounds (metres): width x height x depth, and the bottom and top
func _init() -> void:
	for id in Furniture.CAT:
		var ab := Furniture.aabb(id)
		print("FS %-28s %5.2f x %5.2f x %5.2f  y %5.2f..%5.2f" % [id, ab.size.x, ab.size.y, ab.size.z, ab.position.y, ab.end.y])
	quit()
