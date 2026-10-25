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


// With mipmaps: the soft focus and the bloom read the screen at a coarser level (one sample that is already a
// blur) instead of taking many samples at full size.
uniform sampler2D screen_texture
	: hint_screen_texture, repeat_disable, filter_linear_mipmap;


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

/*
A little fisheye: the picture bulges toward the middle and bends toward the corners, as if it were shot through a wide
angle lens (a barrel curve that adds to the camcorder's own `lens_distortion`). The middle of each edge of the frame stays
on the edge; only the corners are drawn in, and they fade out softly. 0 is none, 0.05 to 0.08 is a little.
*/
uniform float fisheye_strength
	: hint_range(0.0, 0.3) = 0.0;

uniform float video_desaturation
	: hint_range(0.0, 0.50) = 0.12;

uniform float video_contrast_wash
	: hint_range(0.0, 0.30) = 0.08;

uniform float video_black_lift
	: hint_range(0.0, 0.08) = 0.012;

uniform float brightness_compensation
	: hint_range(0.0, 0.20) = 0.06;


/*
Worn VHS tape on top of the camcorder look (all of it scaled by `camcorder_strength` and gone as `darkness`
goes to 1): colour that bleeds to the right of its edges, and lines that wobble sideways. (There are no dropout
dashes and no torn band along the bottom: they were tried and taken out.)
*/
uniform float vhs_chroma_bleed_pixels
	: hint_range(0.0, 16.0) = 5.0;

uniform float vhs_line_jitter
	: hint_range(0.0, 0.01) = 0.0018;

/*
An unstable picture, like a tape that is worn out or a deck that cannot hold it. `vhs_instability` scales all of
it. The picture drifts sideways in slow waves down the frame (`vhs_wobble_amount`, in screen widths); now and
then, every `vhs_tracking_interval` seconds or so, a band the height of a hand wanders through the picture for
a moment, tearing it sideways and smearing its colour (`vhs_tracking_strength`); and now and then a field jumps
a hair up or down (`vhs_vertical_twitch`) or a single frame dips in brightness (`vhs_flicker`). None of it adds
white lines or noise: the picture only moves.
*/
uniform float vhs_instability
	: hint_range(0.0, 2.0) = 1.0;

uniform float vhs_wobble_amount
	: hint_range(0.0, 0.01) = 0.0022;

uniform float vhs_tracking_strength
	: hint_range(0.0, 1.0) = 0.7;

uniform float vhs_tracking_interval
	: hint_range(3.0, 30.0) = 8.0;

uniform float vhs_vertical_twitch
	: hint_range(0.0, 0.01) = 0.0025;

uniform float vhs_flicker
	: hint_range(0.0, 0.3) = 0.09;

/*
A darker, colder tape: the mid tones and shadows are pressed down (`vhs_dark_gamma`, 0 leaves them alone) and
the picture is darker toward the frame's edges (`vhs_edge_darkening`), along the frame, not in a circle.
*/
uniform float vhs_dark_gamma
	: hint_range(0.0, 0.5) = 0.14;

uniform float vhs_edge_darkening
	: hint_range(0.0, 1.0) = 0.4;


/*
Overexposed light, like a camera that cannot cope with a torch on a wall: bright parts of the picture
spill a wide, warm halo (`bloom_*`) and the brightest of them are pushed toward white (`highlight_gain`).
*/
uniform float bloom_strength
	: hint_range(0.0, 2.0) = 0.55;

uniform float bloom_radius_pixels
	: hint_range(2.0, 80.0) = 26.0;

uniform float bloom_threshold
	: hint_range(0.0, 1.0) = 0.38;

uniform float highlight_gain
	: hint_range(0.0, 1.5) = 0.6;


/*
Takes the camcorder look out of the picture (grain, colour noise, lifted blacks, washed contrast) as it goes to
1, so that a black picture is truly black and a scene can fade to the black of a plain black screen without a
jump. Only the finale drives it.
*/
uniform float darkness
	: hint_range(0.0, 1.0) = 0.0;

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
	return textureLod(
		screen_texture,
		safe_screen_uv(uv),
		0.0
	).rgb;
}


// The screen, already blurred: `lod` 1 averages 2 by 2 pixels, 2 averages 4 by 4, and so on.
vec3 sample_screen_blurred(vec2 uv, float lod) {
	return textureLod(
		screen_texture,
		safe_screen_uv(uv),
		lod
	).rgb;
}


void fragment() {
	vec2 screen_uv = SCREEN_UV;
	float video_strength = camcorder_strength * (1.0 - darkness);
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
		(1.0 + (lens_distortion + fisheye_strength) * lens_radius_squared)
		/ (1.0 + fisheye_strength)
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
	// A fisheye draws the corners in past the frame: they fade out softly (along the diagonal) instead of showing
	// stretched edge pixels. With no fisheye this is 1 everywhere.
	float fisheye_corner = (abs(distorted_position.x) + abs(distorted_position.y)) * 0.5;
	float fisheye_fade = 1.0 - smoothstep(0.84, 1.0, fisheye_corner) * step(0.0001, fisheye_strength);
	/*
	Tape wobble: every picture line is shifted a little sideways, and slow waves of drift run down the frame.
	*/
	float tape_line = floor(screen_uv.y * 240.0);
	float jitter = (random_value(vec2(tape_line, video_frame)) - 0.5) * vhs_line_jitter
		+ (
			sin(screen_uv.y * 7.0 + TIME * 0.9) * 0.6
			+ sin(screen_uv.y * 19.0 - TIME * 1.7) * 0.4
		) * vhs_wobble_amount * vhs_instability;

	/*
	Tracking disturbance: once in a while a band wanders through the picture for a fraction of a second. Inside
	it the lines are torn sideways (more at its middle) and the colour smears. `tracking_disturbance` is how
	much of it there is at this pixel (0 to 1).
	*/
	float tracking_cycle = floor(TIME / vhs_tracking_interval);
	float tracking_seconds = (TIME - tracking_cycle * vhs_tracking_interval);
	float tracking_start = 1.0 + random_value(vec2(tracking_cycle, 3.0)) * max(vhs_tracking_interval - 3.0, 0.5);
	float tracking_length = 0.35 + random_value(vec2(tracking_cycle, 9.0)) * 0.5;
	float tracking_progress = (tracking_seconds - tracking_start) / tracking_length;
	float tracking_envelope = (
		step(0.0, tracking_progress)
		* (1.0 - step(1.0, tracking_progress))
		* sin(clamp(tracking_progress, 0.0, 1.0) * 3.14159265)
	);
	float tracking_center = fract(random_value(vec2(tracking_cycle, 5.0)) + tracking_progress * 0.3);
	float tracking_band = 1.0 - smoothstep(0.0, 0.09, abs(screen_uv.y - tracking_center));
	float tracking_disturbance = tracking_envelope * tracking_band * vhs_tracking_strength * vhs_instability;
	float tracking_tear = (
		random_value(vec2(tape_line, video_frame + tracking_cycle)) - 0.5
		+ sin(screen_uv.y * 90.0 + TIME * 40.0) * 0.5
	);
	jitter += tracking_disturbance * tracking_tear * 0.035;

	uv.x += jitter * video_strength;

	/*
	A field that jumps: now and then, for a frame, the whole picture sits a hair higher or lower.
	*/
	float twitch_roll = random_value(vec2(video_frame, 22.0));
	uv.y += (
		(random_value(vec2(video_frame, 21.0)) - 0.5)
		* step(0.965, twitch_roll)
		* vhs_vertical_twitch
		* vhs_instability
		* video_strength
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
	Colour bleeds to the right of its edges while the brightness stays sharp: the tape stores far less colour
	than brightness.
	*/
	if (
		screen_sample_quality > 0.25
		&& vhs_chroma_bleed_pixels > 0.0
	) {
		vec2 bleed_step = vec2(
			SCREEN_PIXEL_SIZE.x * vhs_chroma_bleed_pixels * (1.0 + 5.0 * tracking_disturbance) * 0.33,
			0.0
		);
		vec3 smear = original_color * 0.34
			+ sample_screen(uv - bleed_step) * 0.30
			+ sample_screen(uv - bleed_step * 2.0) * 0.22
			+ sample_screen(uv - bleed_step * 3.0) * 0.14;
		float sharp_luma = dot(original_color, vec3(0.299, 0.587, 0.114));
		float smear_luma = dot(smear, vec3(0.299, 0.587, 0.114));
		original_color = mix(
			original_color,
			vec3(sharp_luma) + (smear - vec3(smear_luma)),
			video_strength
		);
	}

	/*
	Soft focus: one sample of the screen at a coarser level (about the size of the old five-sample blur).
	*/
	vec3 blur_color = original_color;

	if (screen_sample_quality > 0.75) {
		blur_color = sample_screen_blurred(
			uv,
			log2(max(soft_focus_radius, 1.0)) + 0.6
		);
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
	Wide bloom: a ring of samples around the pixel, turned by a different amount at each pixel so that the
	pattern dissolves into the grain instead of showing as a star, adds the bright parts of the picture back
	as a warm halo. This is what makes a torch beam on a wall glare.
	*/
	if (
		screen_sample_quality > 0.25
		&& bloom_strength > 0.0
	) {
		// A wide blur of the screen (a coarse level, plus four samples round it at a finer one), kept only where it
		// is bright. The sample points are turned by a different amount at each pixel, so no pattern shows.
		float turn = random_value(floor(SCREEN_UV / SCREEN_PIXEL_SIZE)) * 1.5707963;
		float reach = bloom_radius_pixels * 0.6;
		float wide_lod = log2(max(bloom_radius_pixels, 2.0)) - 0.5;
		vec3 wide = sample_screen_blurred(uv, wide_lod) * 0.4;
		for (int tap = 0; tap < 4; tap++) {
			float angle = 1.5707963 * float(tap) + turn;
			vec2 offset = vec2(cos(angle), sin(angle)) * reach * SCREEN_PIXEL_SIZE;
			wide += sample_screen_blurred(uv + offset, wide_lod - 1.5) * 0.15;
		}
		// By brightness, not by channel (a red brick wall must not glow red), and drawn toward white: light is white.
		float wide_luma = dot(wide, vec3(0.299, 0.587, 0.114));
		vec3 bloom = mix(wide / max(wide_luma, 0.001), vec3(1.0), 0.65) * max(wide_luma - bloom_threshold, 0.0) * 2.0;
		final_color += (
			bloom
			* vec3(1.0, 0.92, 0.80)
			* bloom_strength
			* 3.0
			* max(intensity, 0.5)
		);
	}

	/*
	The brightest parts are pushed on toward white, like an overexposed frame.
	*/
	float bright_luminance = dot(
		final_color,
		vec3(0.299, 0.587, 0.114)
	);
	final_color *= (
		1.0
		+ highlight_gain
		* smoothstep(0.35, 0.90, bright_luminance)
		* max(intensity, 0.5)
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

	// A rounded square, not a circle: the corners of the frame, not a ring round the middle.
	vec2 centered_squared = centered_uv * centered_uv;
	float edge_distance = pow(
		centered_squared.x * centered_squared.x + centered_squared.y * centered_squared.y,
		0.25
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
	final_color *= lens_frame * fisheye_fade;

	/*
	A colder, darker tape: mid tones and shadows pressed down, the edges of the frame dimmer, and now and then a
	single frame that dips (a tape that cannot hold its level).
	*/
	final_color = pow(
		max(final_color, vec3(0.0)),
		vec3(1.0 + vhs_dark_gamma * video_strength)
	);
	float frame_edge = smoothstep(0.78, 1.25, edge_distance);
	final_color *= 1.0 - frame_edge * vhs_edge_darkening * video_strength;
	float flicker_roll = random_value(vec2(video_frame, 31.0));
	final_color *= 1.0 - step(0.985, flicker_roll) * vhs_flicker * vhs_instability * video_strength;

	COLOR = vec4(
		clamp(
			final_color,
			vec3(0.0),
			vec3(1.0)
		),
		1.0
	);
}
