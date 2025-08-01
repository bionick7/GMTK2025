class_name PlayerCharacter
extends VehicleBody

func _process(delta: float) -> void:
	$UI/Speedometer.value = linear_velocity.length()
	
	if Input.is_action_pressed("accelerate"):
		var ground_effect := clampf(1.0 - 0.5 * _get_ground_proximity(), 0, 1)
		target_speed = lerp(acc_speed, acc_speed + 10, ground_effect)
	elif Input.is_action_pressed("turn"):
		target_speed = turn_speed
	else:
		target_speed = normal_speed

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("respawn"):
		print("reset")
		reset()


func _get_pittch() -> float:
	var controller_pitch := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var kb_pittch = Input.get_action_strength("pitch_up") - Input.get_action_strength("pitch_down")
	return controller_pitch + kb_pittch


func _get_roll() -> float:
	var controller_roll := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var kb_roll = Input.get_action_strength("roll_right") - Input.get_action_strength("roll_left")
	return controller_roll + kb_roll
