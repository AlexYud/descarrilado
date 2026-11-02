shader_type canvas_item;

// The look of the recording in the waiting shed: the picture under this rectangle (the 3D view, already filtered by the game's
// own filters) drained of most of its colour, a little harder and brighter, with a little grain, faint scanlines and a soft
// vignette. Local to the recording scene: it is only on screen while the recording plays, and it never touches the player's
// own filter settings. `grain`, `scanlines` and `vignette` are set to zero from script when the player has the video filter off.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float desaturation : hint_range(0.0, 1.0) = 0.88;
uniform float contrast : hint_range(0.5, 1.6) = 1.1;
uniform float brightness : hint_range(-0.2, 0.3) = 0.03;
uniform float grain : hint_range(0.0, 0.3) = 0.05;
uniform float scanlines : hint_range(0.0, 0.3) = 0.035;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(luma) * vec3(1.0, 0.975, 0.92), desaturation);
	c = (c - 0.5) * contrast + 0.5 + brightness;
	float noise = hash(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 18.0) * 17.0) - 0.5;
	c += noise * grain;
	c -= scanlines * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159));
	vec2 d = UV - 0.5;
	c *= 1.0 - vignette * dot(d, d) * 2.0;
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
