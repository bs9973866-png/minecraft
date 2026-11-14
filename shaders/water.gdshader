shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.18, 0.52, 0.67, 0.72);
uniform vec4 deep_color : source_color = vec4(0.035, 0.20, 0.32, 0.82);
uniform float wave_strength = 0.035;

void vertex() {
	float wave_a = sin(VERTEX.x * 0.34 + TIME * 1.25);
	float wave_b = cos(VERTEX.z * 0.29 - TIME * 0.9);
	VERTEX.y += (wave_a + wave_b) * wave_strength;
}

void fragment() {
	float wave = sin(UV.x * 34.0 + TIME * 1.3) * cos(UV.y * 28.0 - TIME);
	float shimmer = clamp(0.5 + wave * 0.18, 0.0, 1.0);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, shimmer);
	ROUGHNESS = 0.24;
	METALLIC = 0.08;
	ALPHA = mix(deep_color.a, shallow_color.a, shimmer);
}
