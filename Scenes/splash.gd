class_name Splash
extends Node3D

@export var is_player := false

func _ready() -> void:
	set_strength(0)

func set_strength(x: float):
	$Splash.visible = x > 0.1
	$Splash.modulate = Color(1.0, 1.0, 1.0, x)
	
	if is_player:
		if x > 0.1:
			Input.start_joy_vibration(0, x, x, 0)
		else:
			Input.stop_joy_vibration(0)
