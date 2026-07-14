shader_type canvas_item;
render_mode unshaded;


/*
A soft violet cinematic filter for psychological horror.

Designed to:
- Unify different assets.
- Hide texture and geometry imperfections.
- Reduce overly clean digital rendering.
- Preserve enough clarity for exploration.
*/


uniform sampler2D screen_texture
	: hint_screen_texture, repeat_disable, filter_linear;


/*
Master filter strength.

Recommended:
0.60 = subtle
0.80 = normal
1.00 = strong
*/
uniform float intensity
	: hint_range(0.0, 1.0) = 0.80;


/*
Softens harsh geometry edges and texture detail.

Keep this restrained or the image will look unfocused.
*/
uniform float soft_focus
	: hint_range(0.0, 0.60) = 0.22;

uniform float soft_focus_radius
	: hint_range(0.5, 3.0) = 1.25;


/*
Strength of the violet color grading.
*/
uniform float purple_strength
	: hint_range(0.0, 1.0) = 0.48;


/*
Removes some modern-looking digital saturation before
applying the violet grading.
*/
uniform float desaturation
	: hint_range(0.0, 1.0) = 0.16;


/*
Adds depth and hides detail in darker areas.
*/
uniform float contrast
	: hint_range(0.0, 0.50) = 0.12;

uniform float black_crush
	: hint_range(0.0, 0.20) = 0.045;


/*
Soft violet glow around bright objects and lights.
*/
uniform float highlight_glow
	: hint_range(0.0, 0.40) = 0.07;

uniform float glow_threshold
	: hint_range(0.20, 1.0) = 0.58;


/*
Fine animated film grain.

This helps hide color banding, flat surfaces, and very
clean-looking digital shadows.
*/
uniform float grain_strength
	: hint_range(0.0, 0.15) = 0.026;

uniform float grain_speed
	: hint_range(1.0, 60.0) = 24.0;


/*
Darkens the edges and focuses attention toward the center.
*/
uniform float vignette_strength
	: hint_range(0.0, 1.0) = 0.44;

uniform float vignette_size
	: hint_range(0.20, 1.20) = 0.64;

uniform float vignette_softness
	: hint_range(0.05, 1.0) = 0.46;


/*
Very subtle brightness instability.

This is not a VHS flicker. It simply prevents the image
from feeling completely static.
*/
uniform float exposure_drift
	: hint_range(0.0, 0.08) = 0.008;


float random_value(vec2 coordinates) {
	return fract(
		sin(
			dot(
				coordinates,
				vec2(12.9898, 78.233)
			)
		) * 43758.5453
	);
}


vec2 safe_screen_uv(vec2 uv) {
	return clamp(
		uv,
		vec2(0.001),
		vec2(0.999)
	);
}


vec3 sample_screen(vec2 uv) {
	return texture(
		screen_texture,
		safe_screen_uv(uv)
	).rgb;
}


void fragment() {
	vec2 uv = SCREEN_UV;

	vec2 blur_offset = (
		SCREEN_PIXEL_SIZE
		* soft_focus_radius
	);

	vec3 original_color = sample_screen(uv);

	/*
	Five-sample soft blur.

	This is intentionally smaller and cheaper than a large
	blur kernel, making it suitable for lower-end computers.
	*/
	vec3 blur_color = original_color * 0.40;

	blur_color += sample_screen(
		uv + vec2(blur_offset.x, 0.0)
	) * 0.15;

	blur_color += sample_screen(
		uv - vec2(blur_offset.x, 0.0)
	) * 0.15;

	blur_color += sample_screen(
		uv + vec2(0.0, blur_offset.y)
	) * 0.15;

	blur_color += sample_screen(
		uv - vec2(0.0, blur_offset.y)
	) * 0.15;

	vec3 final_color = mix(
		original_color,
		blur_color,
		soft_focus * intensity
	);

	float luminance = dot(
		final_color,
		vec3(0.299, 0.587, 0.114)
	);

	/*
	Remove a small amount of saturation first, allowing all
	assets to share a more consistent visual palette.
	*/
	final_color = mix(
		final_color,
		vec3(luminance),
		desaturation * intensity
	);

	/*
	Shadow and middle-tone masks.

	The purple grading is strongest in the shadows and much
	weaker in bright areas, preserving flashlight readability.
	*/
	float shadow_mask = (
		1.0
		- smoothstep(
			0.14,
			0.68,
			luminance
		)
	);

	float middle_distance = abs(
		luminance - 0.44
	);

	float middle_mask = (
		1.0
		- smoothstep(
			0.0,
			0.44,
			middle_distance
		)
	);

	vec3 violet_shadow_grade = vec3(
		0.78,
		0.60,
		1.10
	);

	vec3 violet_middle_grade = vec3(
		1.00,
		0.88,
		1.10
	);

	final_color *= mix(
		vec3(1.0),
		violet_shadow_grade,
		shadow_mask
		* purple_strength
		* intensity
	);

	final_color *= mix(
		vec3(1.0),
		violet_middle_grade,
		middle_mask
		* purple_strength
		* 0.35
		* intensity
	);

	/*
	A tiny violet haze in dark areas prevents pure black
	regions from looking flat or empty.
	*/
	final_color += (
		vec3(0.018, 0.002, 0.030)
		* shadow_mask
		* purple_strength
		* intensity
	);

	/*
	Contrast and dark-detail reduction.
	*/
	final_color = (
		(final_color - vec3(0.5))
		* (1.0 + contrast * intensity)
		+ vec3(0.5)
	);

	final_color -= (
		vec3(black_crush)
		* shadow_mask
		* intensity
	);

	/*
	Soft violet glow from the already blurred image.
	*/
	vec3 glow_source = max(
		blur_color - vec3(glow_threshold),
		vec3(0.0)
	);

	final_color += (
		glow_source
		* vec3(0.72, 0.54, 1.0)
		* highlight_glow
		* intensity
		* 2.0
	);

	/*
	Fine animated grain.

	More grain appears in shadows, where it helps disguise
	banding and low-detail surfaces.
	*/
	vec2 pixel_position = floor(
		SCREEN_UV / SCREEN_PIXEL_SIZE
	);

	float grain_frame = floor(
		TIME * grain_speed
	);

	float grain = random_value(
		pixel_position
		+ vec2(
			grain_frame,
			grain_frame * 0.73
		)
	);

	float shadow_grain_multiplier = mix(
		0.35,
		1.0,
		shadow_mask
	);

	final_color += (
		(grain - 0.5)
		* grain_strength
		* shadow_grain_multiplier
		* intensity
	);

	/*
	Very small, slow exposure variation.
	*/
	float exposure_wave = (
		sin(TIME * 0.83)
		+ sin(TIME * 1.37) * 0.5
	);

	final_color *= (
		1.0
		+ exposure_wave
		* exposure_drift
		* intensity
	);

	/*
	Smooth cinematic vignette.
	*/
	vec2 centered_uv = (
		uv * 2.0 - 1.0
	);

	float edge_distance = length(
		centered_uv
	);

	float vignette = smoothstep(
		vignette_size,
		vignette_size + vignette_softness,
		edge_distance
	);

	final_color *= (
		1.0
		- vignette
		* vignette_strength
		* intensity
	);

	COLOR = vec4(
		clamp(
			final_color,
			vec3(0.0),
			vec3(1.0)
		),
		1.0
	);
}