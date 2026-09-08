shader_type fog;

uniform vec3 mist_color : source_color = vec3(0.66, 0.72, 0.78);
uniform float density : hint_range(0.0, 0.2, 0.001) = 0.038;
uniform float noise_scale : hint_range(0.02, 1.0, 0.01) = 0.16;
uniform float detail_scale : hint_range(0.1, 2.0, 0.01) = 0.47;
uniform vec3 wind_direction = vec3(0.035, 0.0, 0.018);
uniform float phase = 0.0;


float hash_3d(vec3 point) {
	point = fract(point * 0.1031);
	point += dot(point, point.yzx + 33.33);
	return fract((point.x + point.y) * point.z);
}


float value_noise(vec3 point) {
	vec3 cell = floor(point);
	vec3 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);

	float n000 = hash_3d(cell + vec3(0.0, 0.0, 0.0));
	float n100 = hash_3d(cell + vec3(1.0, 0.0, 0.0));
	float n010 = hash_3d(cell + vec3(0.0, 1.0, 0.0));
	float n110 = hash_3d(cell + vec3(1.0, 1.0, 0.0));
	float n001 = hash_3d(cell + vec3(0.0, 0.0, 1.0));
	float n101 = hash_3d(cell + vec3(1.0, 0.0, 1.0));
	float n011 = hash_3d(cell + vec3(0.0, 1.0, 1.0));
	float n111 = hash_3d(cell + vec3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, local.x);
	float nx10 = mix(n010, n110, local.x);
	float nx01 = mix(n001, n101, local.x);
	float nx11 = mix(n011, n111, local.x);
	float nxy0 = mix(nx00, nx10, local.y);
	float nxy1 = mix(nx01, nx11, local.y);

	return mix(nxy0, nxy1, local.z);
}


float mist_noise(vec3 point) {
	float broad = value_noise(point);
	float detail = value_noise(point * 2.37 + vec3(8.1, 2.7, 5.4));
	return broad * 0.72 + detail * 0.28;
}


void fog() {
	vec3 drifted_position = (
		WORLD_POSITION * noise_scale
		+ wind_direction * TIME
		+ vec3(phase, phase * 0.37, -phase * 0.61)
	);

	float broad_noise = mist_noise(drifted_position);
	float fine_noise = value_noise(
		WORLD_POSITION * detail_scale
		- wind_direction * TIME * 1.7
		+ phase
	);
	float billow = broad_noise * 0.82 + fine_noise * 0.18;

	float bottom_fade = smoothstep(0.02, 0.18, UVW.y);
	float top_fade = 1.0 - smoothstep(0.38, 0.96, UVW.y);
	float shape_fade = clamp(-SDF / 0.85, 0.0, 1.0);
	float pockets = smoothstep(0.37, 0.72, billow);

	DENSITY = density * pockets * bottom_fade * top_fade * shape_fade;
	ALBEDO = mist_color;
	EMISSION = mist_color * 0.0025;
}
