class_name NPC
extends VehicleBody

const DEBUG_DRAWING := false

@export var lookahead_value: float = 6.0

var calc_pitch := 0.0
var calc_yaw := 0.0

func _process(delta: float) -> void:
	_is_accelerating = true
	var track := tracker.current_track_piece
	var track_progress := track.get_track_progress(global_position)
	var track_position: Vector3 = track.sample_track_guide(track_progress)
	var track_position_plus: Vector3 = track.sample_track_guide(track_progress + 1e-3)
	var track_direction: Vector3 = (track_position_plus - track_position).normalized()
	var track_orientation: Basis = track.get_track_orientation(track_progress)
	var target_pt = track_position + track_direction * lookahead_value + track_orientation.y
	var goal_body_fixed = global_transform.inverse() * target_pt
	var goal_direction := goal_body_fixed.normalized()
	
	# For now only pitch/yaw
	var target_p_angle := -asin(goal_direction.y)
	if goal_direction.x < 0: target_p_angle = PI - target_p_angle
	if target_p_angle > PI: target_p_angle -= TAU
	var target_y_angle := atan2(goal_direction.z, goal_direction.x)
	
	var proximity = _get_ground_proximity()
	
	calc_pitch = -target_p_angle
	calc_yaw = target_y_angle

	if DEBUG_DRAWING:
		DebugDraw.draw_line_global(
			global_position, 
			target_pt,
			Color.RED
		)
		
		DebugDraw.draw_line_global(
			track_position, 
			target_pt,
			Color.GREEN
		)

func _get_pitch() -> float:
	return calc_pitch

func _get_roll() -> float:
	return calc_yaw
