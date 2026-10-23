// Vapour of a breath in the cold, for the particles of ColdBreath. Each particle is a billboard that is not a
// disc but a patch of drifting noise: its texture flows while it ages, and a rising threshold eats it into
// wisps and then into nothing, so the plume thins out and vanishes in the air instead of fading as a whole.
// INSTANCE_CUSTOM of the particle: x = its angle, y = its age from 0 to 1.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.82, 0.9, 0.97, 0.3);
// The vapour is lit like anything else (the flashlight shows it plainly); this much of its colour it has by itself,
// so that in the dark of a night it is only just there.
uniform float glow : hint_range(0.0, 1.0) = 0.12;
// How soon the puff starts to be eaten away (1 = it is only gone at the end of its life).
uniform float dissolve_speed : hint_range(0.2, 1.5) = 1.2;

varying float life;
varying float seed;
varying vec4 particle_color;

void vertex() {
	life = INSTANCE_CUSTOM.y;
	seed = fract(sin(dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	particle_color = COLOR;

	// A billboard that keeps the particle's own angle and size.
	float angle = INSTANCE_CUSTOM.x;
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	facing = facing * mat4(
		vec4(cos(angle), -sin(angle), 0.0, 0.0),
		vec4(sin(angle), cos(angle), 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	// Thin air at the rim, thicker toward the middle: no hard edge anywhere.
	float edge = 1.0 - smoothstep(0.0, 1.0, length(p) * 2.0);

	// Two soft layers of noise (read blurred), one bending the other, flowing with the puff's age.
	vec2 flow = vec2(life * 0.3 + seed, -life * 0.45 + seed * 1.7);
	float warp = textureLod(noise_texture, UV * 1.0 + flow * 0.5, 1.0).r - 0.5;
	float body = textureLod(noise_texture, UV * 1.6 + warp * 0.7 + flow, 1.0).r;
	float detail = textureLod(noise_texture, UV * 3.0 - warp * 0.5 - flow * 1.4, 1.0).r;
	float cloud = clamp((body * 0.65 + detail * 0.35 - 0.36) * 2.4, 0.0, 1.0);
	float density = edge * (0.25 + 0.75 * cloud);

	// The puff is worn thin from the edges in as it ages, until nothing is left.
	float threshold = life * dissolve_speed * 0.85;
	float visible = smoothstep(0.0, 1.0, clamp((density - threshold) / 0.7, 0.0, 1.0));

	ALBEDO = tint.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = tint.rgb * glow;
	ALPHA = visible * tint.a * particle_color.a;
}
