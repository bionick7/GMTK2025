extends CanvasLayer

var in_end_race_screen: 
	get(): return end_race_screen.visible

@onready var end_race_screen = $EndRaceScreen

signal restart_race

func race_finished(ranking: Array, player_place: int) -> void:
	end_race_screen.show()
	for i in range(3):
		end_race_screen.get_node("Ranking/Place%d" % (i+1)).visible = len(ranking) > i
		if len(ranking) > i:
			end_race_screen.get_node("Ranking/Place%d/Label" % (i+1)).text = (
				"%d - %s" % [i+1, ranking[i].name]
			)
	end_race_screen.get_node("Ranking/PlayerPlace").visible = player_place > 3
	if player_place > 3:
		end_race_screen.get_node("Ranking/PlayerPlace/Label").text = (
			"%d - %s" % [player_place+1, ranking[player_place].name]
		)	

func _on_retry_race_pressed() -> void:
	end_race_screen.hide()
	restart_race.emit()
	# Reset racers
