shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley,
	specular_schlick_ggx;

uniform vec3 water_tint : source_color = vec3(0.018, 0.028, 0.041);
uniform float shape_seed = 0.0;
uniform float ripple_phase = 0.0;
uniform float wetness : hint_range(0.0, 1.0, 0.01) = 1.0;


float hash_2d(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);

	float a = hash_2d(cell);
	float b = hash_2d(cell + vec2(1.0, 0.0));
	float c = hash_2d(cell + vec2(0.0, 1.0));
	float d = hash_2d(cell + vec2(1.0, 1.0));

	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


void fragment() {
	vec2 centered_uv = (UV - vec2(0.5)) * 2.0;
	centered_uv.x *= 0.78;

	float edge_noise = value_noise(
		UV * 5.2 + vec2(shape_seed, -shape_seed * 0.73)
	);
	float edge_radius = 0.69 + (edge_noise - 0.5) * 0.34;
	float puddle_mask = 1.0 - smoothstep(
		edge_radius - 0.07,
		edge_radius + 0.035,
		length(centered_uv)
	);

	if (puddle_mask < 0.34 || wetness < 0.01) {
		discard;
	}

	vec2 ripple_uv = centered_uv * 5.0;
	float ripple_a = sin(
		length(ripple_uv + vec2(1.7, -0.8)) * 5.4
		- TIME * 0.72
		+ ripple_phase
	);
	float ripple_b = sin(
		length(ripple_uv - vec2(1.2, 1.5)) * 4.1
		- TIME * 0.46
		- ripple_phase
	);
	vec2 ripple_normal = vec2(ripple_a, ripple_b) * 0.018 * wetness;

	ALBEDO = water_tint;
	METALLIC = 0.08;
	ROUGHNESS = mix(0.32, 0.055, wetness);
	SPECULAR = 0.92;
	NORMAL_MAP = vec3(
		0.5 + ripple_normal.x,
		0.5 + ripple_normal.y,
		1.0
	);
	NORMAL_MAP_DEPTH = 0.42;
}
