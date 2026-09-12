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


/*
Late-1990s/early-2000s consumer-video character.

The reference is imperfect recorded footage rather than damaged tape: stable
softness, gently washed color, restrained grain, chroma bleed, and a subtle
barrel lens. There are no tracking bars, scratches, or moving image warps.
*/
uniform float camcorder_strength
	: hint_range(0.0, 1.0) = 0.65;

uniform float capture_frame_rate
	: hint_range(1.0, 60.0) = 29.97;

uniform float chroma_separation_pixels
	: hint_range(0.0, 4.0) = 1.25;

uniform float scanline_strength
	: hint_range(0.0, 0.30) = 0.10;

uniform float chroma_noise_strength
	: hint_range(0.0, 0.10) = 0.022;

uniform float lens_distortion
	: hint_range(0.0, 0.08) = 0.014;

uniform float lens_frame_softness
	: hint_range(0.001, 0.04) = 0.012;

uniform float video_desaturation
	: hint_range(0.0, 0.50) = 0.12;

uniform float video_contrast_wash
	: hint_range(0.0, 0.30) = 0.08;

uniform float video_black_lift
	: hint_range(0.0, 0.08) = 0.012;

uniform float brightness_compensation
	: hint_range(0.0, 0.20) = 0.06;

/*
0.0 = one screen sample, 0.5 = chroma separation, 1.0 = full soft focus.
The filter controller selects this from the graphics quality preset.
*/
uniform float screen_sample_quality
	: hint_range(0.0, 1.0) = 1.0;


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
	vec2 screen_uv = SCREEN_UV;
	float video_strength = camcorder_strength;
	float video_frame = floor(
		TIME * max(capture_frame_rate, 1.0)
	);
	/*
	A stable barrel curve gives the wide consumer-camera lens a little shape.
	The soft frame mask only appears at the extreme distorted edges.
	*/
	vec2 lens_position = screen_uv * 2.0 - 1.0;
	float lens_radius_squared = dot(
		lens_position,
		lens_position
	);
	vec2 distorted_position = lens_position * (
		1.0 + lens_distortion * lens_radius_squared
	);
	vec2 uv = distorted_position * 0.5 + 0.5;
	vec2 distance_to_frame = min(
		uv,
		vec2(1.0) - uv
	);
	float frame_distance = min(
		distance_to_frame.x,
		distance_to_frame.y
	);
	float lens_frame = smoothstep(
		-lens_frame_softness,
		lens_frame_softness * 0.35,
		frame_distance
	);
	uv = safe_screen_uv(uv);

	vec2 blur_offset = (
		SCREEN_PIXEL_SIZE
		* soft_focus_radius
	);

	vec3 original_color = sample_screen(uv);

	/*
	Consumer video stored less color detail than luminance detail. A tiny
	horizontal red/blue separation recreates that softness, especially near
	the lens edges.
	*/
	if (
		screen_sample_quality > 0.25
		&& chroma_separation_pixels > 0.0
	) {
		float lens_edge = clamp(
			length(screen_uv * 2.0 - 1.0),
			0.0,
			1.0
		);
		vec2 chroma_offset = vec2(
			SCREEN_PIXEL_SIZE.x
			* chroma_separation_pixels
			* mix(0.35, 1.0, lens_edge),
			0.0
		);
		vec3 separated_color = vec3(
			sample_screen(uv + chroma_offset).r,
			original_color.g,
			sample_screen(uv - chroma_offset).b
		);
		original_color = mix(
			original_color,
			separated_color,
			video_strength
		);
	}

	/*
	Five-sample soft blur.

	This is intentionally smaller and cheaper than a large
	blur kernel, making it suitable for lower-end computers.
	*/
	vec3 blur_color = original_color;

	if (screen_sample_quality > 0.75) {
		blur_color = original_color * 0.40;

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
	}

	vec3 final_color = mix(
		original_color,
		blur_color,
		soft_focus
		* max(intensity, video_strength * 0.65)
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
		* vec3(1.0, 0.94, 0.88)
		* highlight_glow
		* max(intensity, video_strength * 0.5)
		* 1.5
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
		* video_strength
	);

	/*
	Low-resolution color noise changes at the capture frame rate, while the
	regular grain above remains fine enough to prevent visible banding.
	*/
	vec2 chroma_cell = floor(
		screen_uv * vec2(320.0, 240.0)
	);
	float red_noise = random_value(
		chroma_cell + vec2(video_frame, 17.0)
	) - 0.5;
	float blue_noise = random_value(
		chroma_cell + vec2(43.0, video_frame)
	) - 0.5;

	final_color += (
		vec3(
			red_noise,
			-(red_noise + blue_noise) * 0.16,
			blue_noise
		)
		* chroma_noise_strength
		* video_strength
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
		* video_strength
	);

	/*
	Stable, barely visible line structure at a virtual 480-line resolution.
	*/
	float scanline = 0.5 + 0.5 * sin(
		screen_uv.y * 480.0 * 3.14159265
	);
	final_color *= (
		1.0
		+ (scanline - 0.5)
		* scanline_strength
		* video_strength
	);

	/*
	Consumer-video tone response: slightly muted color, softer contrast, and
	lifted blacks. This hides overly sharp asset differences without dimming
	the scene.
	*/
	float video_luminance = dot(
		final_color,
		vec3(0.299, 0.587, 0.114)
	);
	final_color = mix(
		final_color,
		vec3(video_luminance),
		video_desaturation * video_strength
	);
	final_color = (
		(final_color - vec3(0.5))
		* (1.0 - video_contrast_wash * video_strength)
		+ vec3(0.5)
	);
	final_color += vec3(
		video_black_lift * video_strength
	);
	final_color *= (
		1.0 + brightness_compensation * video_strength
	);

	/*
	Smooth cinematic vignette.
	*/
	vec2 centered_uv = (
		screen_uv * 2.0 - 1.0
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
	final_color *= lens_frame;

	COLOR = vec4(
		clamp(
			final_color,
			vec3(0.0),
			vec3(1.0)
		),
		1.0
	);
}
