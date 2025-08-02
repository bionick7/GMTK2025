class_name  CourseTracker
extends Area3D

var track_pieces: Array
var current_track_piece: TrackPiece
var ticks : int = 0
var round: int = 0

@export var is_player := false

func _ready() -> void:
	track_pieces = get_tree().get_nodes_in_group("TrackPiece")
	current_track_piece = null
	for tp in track_pieces:
		if tp.beginning:
			current_track_piece = tp
			break
	if not is_instance_valid(current_track_piece):
		push_error("No valid inital track piece found")


func register_gate_cleared() -> void:
	#print("%s progressed through track" % get_path())
	if not is_instance_valid(current_track_piece.next):
		push_error("TrackPiece (%s) has no parent" % current_track_piece.get_path())
	if is_player:
		$AudioStreamPlayer.play()
	ticks += 1
	round = ticks / len(track_pieces)
	

func _on_area_entered(area: Area3D) -> void:
	if area.get_parent() is not TrackPiece:
		push_error("Entered through gate without a parent TrackPiece (%s)" %
				area.get_path()
		)
		return
	var tp := area.get_parent() as TrackPiece
	if tp == current_track_piece.next:
		current_track_piece = tp
		register_gate_cleared()
	#else:
	#	print("Expected: %s, Got: %s" % [current_track_piece.next, tp])
