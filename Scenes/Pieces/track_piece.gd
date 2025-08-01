@tool
class_name  TrackPiece
extends Node3D

const debug_line_material = preload("res://Art/Materials/DebugLine.tres")

@export var beginning: bool
@export var next: TrackPiece

var _debug_mesh: ImmediateMesh

@onready var _gate = $InGate

func _ready() -> void:
	if not has_node("DebugLine"):
		var line := MeshInstance3D.new()
		line.top_level = true
		_debug_mesh = ImmediateMesh.new()
		line.mesh = _debug_mesh
		add_child(line)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_debug_mesh.clear_surfaces()
		if is_instance_valid(next):
			_debug_mesh.surface_begin(Mesh.PrimitiveType.PRIMITIVE_LINES, debug_line_material)
			_debug_mesh.surface_set_color(Color.RED)
			_debug_mesh.surface_add_vertex(get_gate().global_position)
			_debug_mesh.surface_add_vertex(next.get_gate().global_position)
			_debug_mesh.surface_end()

func get_gate() -> Node3D:
	return _gate
