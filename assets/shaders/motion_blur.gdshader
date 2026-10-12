shader_type canvas_item;
render_mode unshaded;

// Camera motion blur: the picture is smeared along the way the view turned this
// frame (blur_vector, in screen units) and, a little, outward from the middle while
// moving forward (radial_strength). Godot has no motion blur of its own.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform vec2 blur_vector = vec2(0.0);
uniform float radial_strength = 0.0;

const int SAMPLES = 9;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - vec2(0.5);
	// The edges of the picture are smeared more than the middle by a radial blur.
	vec2 smear = blur_vector + from_center * radial_strength;

	vec3 color = vec3(0.0);
	for (int i = 0; i < SAMPLES; i++) {
		float t = float(i) / float(SAMPLES - 1) - 0.5;
		color += texture(screen_texture, uv + smear * t).rgb;
	}

	COLOR = vec4(color / float(SAMPLES), 1.0);
}
