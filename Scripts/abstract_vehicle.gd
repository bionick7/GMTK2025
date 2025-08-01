class_name VehicleBody
extends RigidBody3D

enum ControlScheme {
	PitchYaw,
	PitchRoll,
}

var control_scheme: ControlScheme = ControlScheme.PitchYaw
var invert_pitch: bool = false

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

@onready var tracker: CourseTracker = $CourseTracker
@onready var splash: Splash = get_node_or_null("Splash")

var target_speed := 10.0
var local_vel: Vector3
var _schedule_reset := false

var _ground_ray_result := {}

var _is_accelerating := false

func _ready() -> void:
	linear_velocity = global_basis * Vector3(20, 0, 0)

func _get_pitch() -> float:
	return 0

func _get_roll() -> float:
	return 0
	
func reset() -> void:
	_schedule_reset = true
	
func _get_ground_proximity() -> float:
	if _ground_ray_result.is_empty():
		return 100
	else:
		return _ground_ray_result["position"].distance_to(global_position)

func _process(delta: float) -> void:
	local_vel = global_basis.inverse() * linear_velocity
	var ground_effect := 0.0
	if _is_accelerating:
		ground_effect = clampf(1.0 - 0.5 * _get_ground_proximity(), 0, 1)
		target_speed = lerp(acc_speed, acc_speed + 10, ground_effect)
	else:
		target_speed = normal_speed
	if is_instance_valid(splash):
		splash.set_strength(ground_effect)
		
	# Down raycast
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position, global_position - global_basis.y * 100, 1
	)
	query.collide_with_bodies = true
	_ground_ray_result = space_state.intersect_ray(query)
	

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	local_vel = global_basis.inverse() * linear_velocity
	var pitch := _get_pitch()
	var roll := _get_roll()
	
	var local_angvel := global_basis.inverse() * state.angular_velocity
	#local_vel = global_basis.inverse() * Vector3(10, 0, 0)
	var local_vel_norm := local_vel.normalized()
	var aoa := -asin(local_vel_norm.y)
	if local_vel_norm.x < 0: aoa = PI - aoa
	if aoa > PI: aoa -= TAU
	var sideslip := atan2(local_vel_norm.z, local_vel_norm.x)
	
	# virtual dynamic pressure * surface area
	var qS = turn_responsiveness * clampf(local_vel.length(), 0.5, 1)
	
	var Cl = lift_coeff * aoa
	var C_thrust = (target_speed - local_vel.length()) * thrust_responsiveness
	var Cx = -side_coeff * sideslip
	var aero_force = Vector3(C_thrust, Cl, Cx) * qS
	
	var stall = clampf(pow(aoa / stall_angle, 10), 0.0, 1.0)
	pitch = lerp(pitch, 0.0, stall)
	if invert_pitch:
		pitch *= -1
	var Cm = -aoa * pitch_authority + (pitch * pitch_authority - local_angvel.z * 5) * pitch_resp
	var aero_torque := Vector3.ZERO
	if control_scheme == ControlScheme.PitchRoll:
		var C_roll = (roll * roll_authority - local_angvel.x) * roll_resp
		var C_yaw = -sideslip - local_angvel.y
		aero_torque = Vector3(C_roll, C_yaw, Cm) * qS
	elif control_scheme == ControlScheme.PitchYaw:
		# Roll correction
		var C_roll = -local_angvel.x
		if not _ground_ray_result.is_empty():
			var ground_normal_body_fixed: Vector3 = global_basis.inverse() * _ground_ray_result["normal"]
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
		
