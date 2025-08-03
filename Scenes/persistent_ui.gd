extends CanvasLayer

var in_end_race_screen: 
	get(): return end_race_screen.visible

var plane_pitch: bool = true

@onready var end_race_screen = $EndRaceScreen

signal next_race(progress)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$PauseMenu/H/PlaneControls.button_pressed = plane_pitch
	$EndRaceScreen.hide()
	$PauseMenu.hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		$PauseMenu.visible = get_tree().paused


func race_finished(ranking: Array, player_place: int, won: bool) -> void:
	end_race_screen.show()
	for i in range(3):
		end_race_screen.get_node("Ranking/Place%d" % (i+1)).visible = len(ranking) > i
		if len(ranking) > i:
			end_race_screen.get_node("Ranking/Place%d/Label" % (i+1)).text = (
				ranking[i].name
			)
	end_race_screen.get_node("Ranking/PlayerPlace").visible = player_place > 3
	if player_place > 3:
		end_race_screen.get_node("Ranking/PlayerPlace/Label").text = (
			"%d : %s" % [player_place+1, ranking[player_place].name]
		)
	end_race_screen.get_node("NextRace").visible = won
	
	if won:
		$WinSound.play()

func _on_retry_race_pressed() -> void:
	end_race_screen.hide()
	next_race.emit(false)
	# Reset racers

func _on_next_race_pressed() -> void:
	end_race_screen.hide()
	next_race.emit(true)
 

func _on_music_volume_value_changed(value: float) -> void:    
	AudioServer.set_bus_volume_db(1, value)


func _on_sfx_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(2, value)


func _on_plane_controls_toggled(toggled_on: bool) -> void:
	plane_pitch = toggled_on


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func play() -> void:
	pass # Replace with function body.
