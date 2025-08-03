class_name VehicleBody
extends RigidBody3D

const DEBUG_DRAWING := false

enum ControlScheme {
	PitchYaw,
	PitchRoll,
}

var control_scheme: ControlScheme = ControlScheme.PitchYaw

@export var lookahead_value: float = 6.0
@export var target_altitude: float = 2.0

@export_group("Dynamics")
@export var turn_responsiveness := 100.0
@export var thrust_responsiveness := 1.0
@export var normal_speed := 10.0
@export var acc_speed := 20.0
@export var turn_speed := 3.0
@export_range(0, 90, 0.001, "radians_as_degrees", "degrees")
var stall_angle := 1.0
@export var lift_coeff := 4.0
@export var side_coeff := 1.0
@export var pitch_resp := 2.0
@export var pitch_authority := 10.0
@export var roll_resp := 2.0
@export var roll_authority := 10.0

@onready var level_root = get_tree().get_first_node_in_group("LevelRoot")
@onready var tracker: CourseTracker = $CourseTracker
@onready var splash: Splash = get_node_or_null("Splash")

var target_speed := 10.0
var local_vel: Vector3
var _schedule_reset := false
var _current_track_segment: TrackPiece
var _track_progress: float
var _track_orientation: Basis

var _ground_ray_result := {}

var _is_accelerating := false
var ground_effect := 0.0

var calc_pitch := 0.0
var calc_yaw := 0.0

func _ready() -> void:
	if not is_instance_valid(tracker):
		push_error("tracker must be set for each vehicle")
	linear_velocity = global_basis * Vector3(0, 0, 0)
	
	freeze = true
	level_root.get_node("StartGate/Countdown").go.connect(start_race)
	# get_tree().create_timer(3.6).timeout.connect(start_race)
	$NameTag.text = name

func _process(delta: float) -> void:
	_current_track_segment = tracker.current_track_piece
	_track_progress = _current_track_segment.get_track_progress(global_position)
	_track_orientation = _current_track_segment.get_track_orientation(_track_progress)
	
	local_vel = global_basis.inverse() * linear_velocity
	
	
	if _is_accelerating:
		ground_effect = clampf(1.0 - 0.5 * _get_ground_proximity(), 0, 1)
		
		var player_advantage = (
			PlayerCharacter.instance.get_total_progress()
			 - get_total_progress()
		)
		
		#var spread_negative_feedback: float = 0.0
		#if not is_instance_of(self, PlayerCharacter):
		#	var total_npcs = len(level_root.racers) - 1
		#	spread_negative_feedback = level_root.get_placement(self) / total_npcs - 0.5
		
		target_speed = (
			  lerp(acc_speed, acc_speed + 10, ground_effect)
			+ clampf(player_advantage * 5, -11, 11)
		#	+ clampf(-spread_negative_feedback, -3, 3)
		)
	else:
		ground_effect = 0.0
		target_speed = normal_speed
		
	if is_instance_valid(splash) and not _ground_ray_result.is_empty():
		var _track_position = _current_track_segment.sample_track_guide(_track_progress)
		splash.global_position = _ground_ray_result["position"]
		#splash.global_basis = _track_orientation
	if is_instance_valid(splash):
		splash.set_strength(ground_effect * 1.5)
		
	# Down raycast
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position, global_position - global_basis.y * 100, 1
	)
	query.collide_with_bodies = true
	_ground_ray_result = space_state.intersect_ray(query)
	
	_calc_ideal_inputs()
	


func start_race():
	freeze = false
	linear_velocity = global_basis * Vector3(20, 0, 0)

func _get_pitch() -> float:
	return calc_pitch

func _get_roll() -> float:
	return calc_yaw
	
func reset() -> void:
	_schedule_reset = true
	
func _get_ground_proximity() -> float:
	if _ground_ray_result.is_empty():
		return 100
	else:
		return _ground_ray_result["position"].distance_to(global_position)

func _calc_ideal_inputs() -> void:
	_is_accelerating = true
	if not is_instance_valid(_current_track_segment):
		calc_pitch = 0
		calc_yaw = 0
		return
		
	var track_position: Vector3 = _current_track_segment.sample_track_guide(_track_progress)
	var track_position_plus: Vector3 = _current_track_segment.sample_track_guide(_track_progress + 1e-3)
	var track_direction: Vector3 = (track_position_plus - track_position).normalized()
	var target_pt = track_position + track_direction * lookahead_value + _track_orientation.y * target_altitude
	#target_pt += _track_orientation.x * randf_range(-2, 2)
	var goal_body_fixed = global_transform.inverse() * target_pt
	var goal_direction := goal_body_fixed.normalized()

	# For now only pitch/yaw
	var target_p_angle := -asin(goal_direction.y)
	if goal_direction.x < 0: target_p_angle = PI - target_p_angle
	if target_p_angle > PI: target_p_angle -= TAU
	var target_y_angle := atan2(goal_direction.z, goal_direction.x)
	
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
		
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	local_vel = global_basis.inverse() * linear_velocity
	var pitch := _get_pitch()
	var roll := _get_roll()
	
	var local_angvel := global_basis.inverse() * state.angular_velocity
	#local_vel = global_basis.inverse() * Vector3(10, 0, 0)
	var aoa := 0.0
	var sideslip := 0.0
	if local_vel.length_squared() > 0.01:
		var local_vel_norm := local_vel.normalized()
		aoa = -asin(local_vel_norm.y)
		if local_vel_norm.x < 0: aoa = PI - aoa
		if aoa > PI: aoa -= TAU
		sideslip = atan2(local_vel_norm.z, local_vel_norm.x)
	
	# virtual dynamic pressure * surface area
	var qS = turn_responsiveness * clampf(local_vel.length(), 0.5, 1)
	
	var Cl = lift_coeff * aoa
	var C_thrust = (target_speed - local_vel.length()) * thrust_responsiveness
	var Cx = -side_coeff * sideslip
	var aero_force = Vector3(C_thrust, Cl, Cx) * qS
	
	var stall = clampf(pow(aoa / stall_angle, 10), 0.0, 1.0)
	pitch = lerp(pitch, 0.0, stall)
	var Cm = (
		-aoa * pitch_authority
		 + (pitch * pitch_authority - local_angvel.z * 5) * pitch_resp
	)
	var aero_torque := Vector3.ZERO
	if control_scheme == ControlScheme.PitchRoll:
		var C_roll = (roll * roll_authority - local_angvel.x) * roll_resp
		var C_yaw = -sideslip - local_angvel.y
		aero_torque = Vector3(C_roll, C_yaw, Cm) * qS
	elif control_scheme == ControlScheme.PitchYaw:
		# Roll correction
		var C_roll = -local_angvel.x
		var ground_normal_body_fixed: Vector3 = global_basis.inverse() * _track_orientation.y
		C_roll += ground_normal_body_fixed.z * 10
		
		var C_yaw = -sideslip * roll_authority + (-roll * roll_authority - local_angvel.y) * roll_resp
		aero_torque = Vector3(C_roll, C_yaw, Cm) * qS
		
	state.apply_impulse(global_basis * aero_force * state.step)
	state.apply_torque_impulse(global_basis * aero_torque * state.step)
	
	if _schedule_reset:
		var gate := tracker.current_track_piece.get_gate()
		global_position = gate.global_position + gate.global_basis.y * 1
		global_basis = gate.global_basis * Basis.from_euler(Vector3(0, -PI/2, 0))
		linear_velocity = global_basis * Vector3(1,0,0) * 10
		angular_velocity = Vector3.ZERO
		_schedule_reset = false
		
func get_total_progress() -> float:
	return tracker.ticks + _track_progress
