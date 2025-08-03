shader_type sky;

uniform sampler2D horizon: filter_nearest;

void sky() {
	float long = atan(EYEDIR.x, EYEDIR.z) / PI * 2.0;
	float lat = asin(EYEDIR.y) / PI;
	lat = clamp(10.0*(lat - 0.06), -0.99, 0.99);
	long = long * 5.0;
	vec3 col = texture(horizon, vec2(long, -lat)*0.5 - 0.5).xyz;
	col.x = pow(col.x, 1.0);
	col.y = pow(col.y, 1.0);
	col.z = pow(col.z, 1.0);
	COLOR = col;
}
