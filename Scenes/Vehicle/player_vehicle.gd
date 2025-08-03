class_name PlayerCharacter
extends VehicleBody

@export var autopilot := false

static var instance: PlayerCharacter = null

const LAPS_TEXTURES: Array[Resource] = [
	preload("res://Art/Sprites/lap_1.png"),
	preload("res://Art/Sprites/lap_2.png"),
	preload("res://Art/Sprites/lap_3.png"),
	preload("res://Art/Sprites/ended_all_laps.png"),
]

func _enter_tree() -> void:
	if is_instance_valid(instance):
		queue_free()
	else:
		instance = self

func _process(delta: float) -> void:
	super(delta)
	$UI/Speedometer.value = linear_velocity.length()
	$UI/Place.text = "%d" % (level_root.get_placement(self) + 1)
	assert(level_root.rounds <= 3)
	if tracker.round < level_root.rounds:
		$UI/Rounds.texture = LAPS_TEXTURES[tracker.round]
	else:
		$UI/Rounds.texture = LAPS_TEXTURES[-1]
	_is_accelerating = (
		   Input.is_action_pressed("accelerate")
		or PersistentUi.in_end_race_screen
		or autopilot
	)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("respawn"):
		print("reset")
		reset()

func _get_pitch() -> float:
	if PersistentUi.in_end_race_screen or autopilot:
		return calc_pitch
	var controller_pitch := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var kb_pittch := Input.get_action_strength("pitch_up") - Input.get_action_strength("pitch_down")
	var res := controller_pitch + kb_pittch
	if not PersistentUi.plane_pitch:
		res *= -1
	return res


func _get_roll() -> float:
	if PersistentUi.in_end_race_screen or autopilot:
		return calc_yaw
	var controller_roll := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var kb_roll = Input.get_action_strength("roll_right") - Input.get_action_strength("roll_left")
	return controller_roll + kb_roll
