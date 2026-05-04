shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 0.60);
uniform float inner_radius = 0.38;
uniform float outer_radius = 0.85;
uniform float intensity = 1.0;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);

	// Keeps the vignette more circular on 16:9 screens.
	centered_uv.x *= 1.777;

	float distance_from_center = length(centered_uv);

	float vignette = smoothstep(inner_radius, outer_radius, distance_from_center);
	vignette *= intensity;

	COLOR = vec4(border_color.rgb, border_color.a * vignette);
}