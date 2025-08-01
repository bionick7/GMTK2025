shader_type spatial;
render_mode unshaded, skip_vertex_transform;

uniform sampler2D screen_texture: hint_screen_texture;
uniform ivec3 postarization = ivec3(10, 10, 10);
uniform int pixel_size = 1;

vec3 linear_srgb_to_oklab(vec3 c) {
	float l = 0.4122214708f * c.r + 0.5363325363f * c.g + 0.0514459929f * c.b;
	float m = 0.2119034982f * c.r + 0.6806995451f * c.g + 0.1073969566f * c.b;
	float s = 0.0883024619f * c.r + 0.2817188376f * c.g + 0.6299787005f * c.b;

	float l_ = pow(l, 1./3.);
	float m_ = pow(m, 1./3.);
	float s_ = pow(s, 1./3.);

	return vec3(
		0.2104542553f * l_ + 0.7936177850f * m_ - 0.0040720468f * s_,
		1.9779984951f * l_ - 2.4285922050f * m_ + 0.4505937099f * s_,
		0.0259040371f * l_ + 0.7827717662f * m_ - 0.8086757660f * s_
	);
}

vec3 oklab_to_linear_srgb(vec3 c) {
	float l_ = c.x + 0.3963377774f * c.y + 0.2158037573f * c.z;
	float m_ = c.x - 0.1055613458f * c.y - 0.0638541728f * c.z;
	float s_ = c.x - 0.0894841775f * c.y - 1.2914855480f * c.z;
	float l = l_*l_*l_;
	float m = m_*m_*m_;
	float s = s_*s_*s_;

	return vec3(
		+4.0767416621f * l - 3.3077115913f * m + 0.2309699292f * s,
		-1.2684380046f * l + 2.6097574011f * m - 0.3413193965f * s,
		-0.0041960863f * l - 0.7034186147f * m + 1.7076147010f * s
	);
}

vec3 posterize(vec3 c, ivec3 color_resolution) {
	vec3 oklab = linear_srgb_to_oklab(c);
	oklab = round(oklab * vec3(color_resolution)) / vec3(color_resolution);
	//oklab *= vec3(0,0,1);
	return oklab_to_linear_srgb(oklab);
}

void vertex() {
	POSITION = vec4(VERTEX.yx, 1.0, 1.0);
}

void fragment() {
	vec2 in_uv = SCREEN_UV;
	vec2 screen_size = vec2(textureSize(screen_texture, 0)) / float(pixel_size);

	// ---- UV Manipulation ----
	vec2 uv = in_uv;
	uv = floor(uv * screen_size) / screen_size;

	vec3 col = texture(screen_texture, uv).rgb;
	col = posterize(col, postarization);
	ALBEDO = col;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
