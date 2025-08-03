@tool
class_name  TrackPiece
extends Node3D

const debug_line_material = preload("res://Art/Materials/DebugLine.tres")

@export var beginning: bool
@export var next: TrackPiece
@export var path_curvature_weight: float = 15.0

var _debug_mesh: ImmediateMesh

@onready var _gate: Node3D = $InGate
@onready var _start_tf: Node3D = get_node_or_null("StartTf")
@onready var _end_tf: Node3D = get_node_or_null("EndTf")

func _ready() -> void:
	if not is_instance_valid(next):
		var next_index = (get_index() + 1) % get_parent().get_child_count()
		next = get_parent().get_child(next_index)
	if not has_node("DebugLine"):
		var line := MeshInstance3D.new()
		line.top_level = true
		_debug_mesh = ImmediateMesh.new()
		line.mesh = _debug_mesh
		add_child(line)

func _process(delta: float) -> void:
	_debug_draw()
	
func _debug_draw() -> void:
	if not Engine.is_editor_hint():
		return
	_debug_mesh.clear_surfaces()
	if is_instance_valid(next):
		_debug_mesh.surface_begin(Mesh.PrimitiveType.PRIMITIVE_LINES, debug_line_material)
		_debug_mesh.surface_set_color(Color.RED)
		_debug_mesh.surface_add_vertex(get_gate().global_position)
		_debug_mesh.surface_add_vertex(next.get_gate().global_position)
		_debug_mesh.surface_end()
		
	if is_instance_valid(_start_tf) and is_instance_valid(_end_tf):
		_debug_mesh.surface_begin(Mesh.PrimitiveType.PRIMITIVE_LINE_STRIP, debug_line_material)
		_debug_mesh.surface_set_color(Color.BLUE)
		for i in range(100):
			_debug_mesh.surface_add_vertex(
				sample_track_guide(float(i)/99)
			)
		_debug_mesh.surface_end()

func get_track_orientation(at: float) -> Basis:
	if is_instance_valid(_start_tf) and is_instance_valid(_end_tf):
		var basis1 := _start_tf.global_basis
		var basis2 := _end_tf.global_basis
		return basis1.slerp(basis2, at)
	return global_basis
	
func sample_track_guide(at: float) -> Vector3:
	if is_instance_valid(_start_tf) and is_instance_valid(_end_tf):
		return _start_tf.global_position.bezier_interpolate(
			_start_tf.global_position + _start_tf.global_basis.z * path_curvature_weight,
			_end_tf.global_position - _end_tf.global_basis.z * path_curvature_weight,
			_end_tf.global_position,
			 at
		)
	return global_position
	
func get_track_progress(at: Vector3) -> float:
	if is_instance_valid(_start_tf) and is_instance_valid(_end_tf):
		var d1 := at.distance_to(_start_tf.global_position)
		var d2 := at.distance_to(_end_tf.global_position)
		return d1 / (d1+d2)
	return 0.0

func get_gate() -> Node3D:
	return _gate

func get_entry() -> Vector3:
	return _gate.global_position - _gate.global_basis.z * 5

func get_spawn_position(index: int, of: int) -> Vector3:
	var offset := (index / float(of - 1)) - 0.5
	return get_entry() + _gate.global_basis.x * offset
