shader_type sky;

uniform sampler2D horizon;

void sky() {
	float long = atan(EYEDIR.x, EYEDIR.z) / PI * 2.0;
	float lat = asin(EYEDIR.y) / PI;
	lat = clamp(7.0*(lat - 0.1), -0.99, 0.99);
	long = long * 3.0;
	vec3 col = texture(horizon, vec2(long, -lat)*0.5 - 0.5).xyz;
	COLOR = col;
}
