extends TextureRect

@export var target: Node3D

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var cam := target.get_viewport().get_camera_3d()
	var cam_distance := cam.global_position.distance_to(target.global_position)
	scale = Vector2.ONE * floor(5.0 / cam_distance)
	position = cam.unproject_position(target.global_position) - size * scale / 2.0
