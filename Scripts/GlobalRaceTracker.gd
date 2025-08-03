extends Node

@onready var racers = get_tree().get_nodes_in_group("Racer")
@export var next_level: PackedScene = null
@export var rounds: int = 1
@export var place_to_win: int = 3

var is_race_finished := false

var progresses := {}

"""
func _ready() -> void:
	race_restarted.emit()
	
	var track_pieces := get_tree().get_nodes_in_group("TrackPiece")
	var start_track_piece = null
	for tp in track_pieces:
		if tp.beginning:
			if start_track_piece == null:
				start_track_piece = tp
			else:
				push_error("Multiple start peices")
	if not is_instance_valid(start_track_piece):
		push_error("No valid start piece")
		return
	
	await get_tree().process_frame
	
	# Spawn racers
	
	var racer_count := len(racers)
	for i in range(racer_count):
		var racer = racers[i]
		racer.global_position = start_track_piece.get_spawn_position(
			i, racer_count
		)
		racer.global_basis = (start_track_piece.get_track_orientation(0)
		 * Basis.from_euler(Vector3(0, -PI/2, 0))
		)
		racer.linear_velocity = Vector3.ZERO
"""

func _ready() -> void:
	PersistentUi.next_race.connect(next_race)

func _process(delta: float) -> void:
	for racer in racers:
		progresses[racer] = racer.get_total_progress()
		if racer.tracker.round + 1 > rounds:
			finsih_race()
	
	if Input.is_action_just_pressed("debug_skiprace"):
		finsih_race()
	
	# update ranking
	racers.sort_custom(func(a, b): 
		return progresses[a] > progresses[b]
	)

func get_placement(racer: VehicleBody) -> int:
	return racers.find(racer)
	
func next_race(progress: bool) -> void:
	if is_instance_valid(next_level) and progress:
		get_tree().change_scene_to_packed(next_level)
	else:
		get_tree().reload_current_scene()
	
func finsih_race() -> void:
	if is_race_finished:
		return
	is_race_finished = true
	var player_index := racers.find_custom(
		func(x): return is_instance_of(x, PlayerCharacter)
	)
	PersistentUi.race_finished(
		racers.duplicate(), player_index, player_index <= place_to_win
	)
