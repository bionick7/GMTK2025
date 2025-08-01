@tool
class_name PixelateGD
extends CompositorEffect

var flag_for_shader_recompile := false

@export_tool_button("recompile shader") var initiate_shader_recompile = func(): flag_for_shader_recompile = true
@export var color_resolution: Vector3i
@export_file var shader_sourcecode: String = ""
@export var pixelation_size: int = 3

var rd: RenderingDevice
var shader: RID
var pipeline: RID

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()

# System notifications, we want to react on the notification that
# alerts us we are about to be destroyed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			# Freeing our shader will also free any dependents such as the pipeline!
			rd.free_rid(shader)


#region Code in this region runs on the rendering thread.
# Check if our shader has changed and needs to be recompiled.
func _check_shader() -> bool:

	if not rd:
		return false

	# Read file.
	# TODO: reload on file change
	if not FileAccess.file_exists(shader_sourcecode):
		return false
		
	var shader_file := FileAccess.open(shader_sourcecode, FileAccess.READ)
	var new_shader_code := shader_file.get_as_text()

	# Out with the old.
	if shader.is_valid():
		rd.free_rid(shader)
		shader = RID()
		pipeline = RID()

	# In with the new.
	var shader_source := RDShaderSource.new()
	shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	shader_source.source_compute = new_shader_code
	var shader_spirv : RDShaderSPIRV = rd.shader_compile_spirv_from_source(shader_source)

	if shader_spirv.compile_error_compute != "":
		push_error(shader_spirv.compile_error_compute)
		push_error("In: " + new_shader_code)
		return false

	shader = rd.shader_create_from_spirv(shader_spirv)
	if not shader.is_valid():
		return false

	pipeline = rd.compute_pipeline_create(shader)

	return pipeline.is_valid()


# Called by the rendering thread every frame.
func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if not flag_for_shader_recompile:
		if not _check_shader():
			return
	flag_for_shader_recompile = false
	
	if not rd or p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return
	# Get our render scene buffers object, this gives us access to our render buffers.
	# Note that implementation differs per renderer hence the need for the cast.
	var render_scene_buffers := p_render_data.get_render_scene_buffers()
	if not render_scene_buffers:
		return
	# Get our render size, this is the 3D render resolution!
	var size: Vector2i = render_scene_buffers.get_internal_size()
	if size.x == 0 and size.y == 0:
		return

	# We can use a compute shader here.
	@warning_ignore("integer_division")
	var x_groups := (size.x - 1) / 8 + 1
	@warning_ignore("integer_division")
	var y_groups := (size.y - 1) / 8 + 1
	var z_groups := 1

	# Create push constant.
	var push_constant_i := PackedInt32Array([
		size.x, size.y,
		0, 0,  # Why does this need to be padded? Invisible inside the
		color_resolution.x, color_resolution.y, color_resolution.z,
		pixelation_size,
	])
	var push_constant := push_constant_i.to_byte_array()

	# Loop through views just in case we're doing stereo rendering. No extra cost if this is mono.
	var view_count: int = render_scene_buffers.get_view_count()
	for view in view_count:
		# Get the RID for our color image, we will be reading from and writing to it.
		var input_image: RID = render_scene_buffers.get_color_layer(view)

		# Create a uniform set, this will be cached, the cache will be cleared if our viewports configuration is changed.
		var uniform1 := RDUniform.new()
		uniform1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform1.binding = 0
		uniform1.add_id(input_image)
		
		var uniform_set := UniformSetCacheRD.get_cache(shader, 0, [uniform1])

		# Run our compute shader.
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
		rd.compute_list_end()
#endregion
