extends RigidBody3D

@export var turn_responsiveness := 100.0
@export var thrust_responsiveness := 1.0
@export var target_speed := 10.0
@export_range(0, 90, 0.001, "radians_as_degrees", "degrees") var stall_angle := 1.0
@export var lift_coeff := 4.0
@export var side_coeff := 1.0
@export var pitch_resp := 2.0
@export var pitch_authority := 10.0
@export var roll_resp := 2.0
@export var roll_authority := 10.0

var local_vel: Vector3

func _get_pittch() -> float:
	var controller_pitch := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var kb_pittch = Input.get_action_strength("pitch_up") - Input.get_action_strength("pitch_down")
	return controller_pitch + kb_pittch

func _get_roll() -> float:
	var controller_roll := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var kb_roll = Input.get_action_strength("roll_right") - Input.get_action_strength("roll_left")
	return controller_roll + kb_roll

func _process(delta: float) -> void:
	local_vel = global_basis.inverse() * linear_velocity
	$Pivot.basis = Basis.looking_at(local_vel, Vector3.UP)
	$CanvasLayer/HSlider.value = linear_velocity.length()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var pitch := _get_pittch()
	var roll = _get_roll()
	
	var local_angvel := global_basis.inverse() * state.angular_velocity
	#local_vel = global_basis.inverse() * Vector3(10, 0, 0)
	var local_vel_norm := local_vel.normalized()
	var aoa := -asin(local_vel_norm.y)
	if local_vel_norm.x < 0: aoa = PI - aoa
	if aoa > PI: aoa -= TAU
	var sideslip := atan2(local_vel_norm.z, local_vel_norm.x)
	
	var Cl = lift_coeff * aoa
	var C_thrust = (target_speed - local_vel.length()) * thrust_responsiveness
	var Cx = side_coeff * sideslip
	var aero_force = Vector3(C_thrust, Cl, Cx) * turn_responsiveness
	
	var stall = clampf(pow(aoa / stall_angle, 10), 0.0, 1.0)
	pitch = lerp(pitch, 0.0, stall)
	var Cm = -aoa * pitch_authority + (pitch * pitch_authority - local_angvel.z * 5) * pitch_resp
	var C_roll = (roll * roll_authority - local_angvel.x) * roll_resp
	var C_yaw = -sideslip - local_angvel.y
	var aero_torque = Vector3(C_roll, C_yaw, Cm) * turn_responsiveness
		
	state.apply_impulse(global_basis * aero_force * state.step)
	state.apply_torque_impulse(global_basis * aero_torque * state.step)
