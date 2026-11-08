shader_type canvas_item;

// The look of the recording in the waiting shed: a worn, copied home-video tape. The picture under this rectangle (the 3D view, already filtered by
// the game's own filters) is drained of most of its colour and tinted a sick yellow-green, thrown down to a coarse low-resolution picture, smeared
// sideways with the colour bleeding off the edges of things, crushed and blown at once, grained, with the lines of the tape shifting, short white
// dropouts, a noisy band along the bottom, and the picture itself updating only `fps` times a second (the grain, the lines and the dropouts too).
// It is local to the recording scene: only on screen while the recording plays, and it never touches the player's own filter settings. `degrade`
// is set to zero from script when the player has the video filter off: then only the colour is drained and nothing moves.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
// The picture's size in screen pixels (set from script): the coarse picture is laid on the picture's own 4:3 frame, not on the window.
uniform vec2 picture_pixels = vec2(1440.0, 1080.0);
uniform float desaturation : hint_range(0.0, 1.0) = 0.86;
uniform float contrast : hint_range(0.5, 1.8) = 1.22;
uniform float brightness : hint_range(-0.2, 0.3) = 0.05;
uniform float grain : hint_range(0.0, 0.4) = 0.16;
uniform float scanlines : hint_range(0.0, 0.3) = 0.05;
uniform float vignette : hint_range(0.0, 1.5) = 0.85;
// 1: the worn tape. 0: only the colour.
uniform float degrade : hint_range(0.0, 1.0) = 1.0;
// The tape's own frame rate: what moves in the picture, and the noise on it, changes this many times a second.
uniform float fps : hint_range(4.0, 30.0) = 12.0;
// The coarse picture's size in "pixels" (the tape's resolution), across and down.
uniform vec2 tape_size = vec2(340.0, 255.0);
// The end of the tape: 1 is nothing but static.
uniform float burst : hint_range(0.0, 1.0) = 0.0;
// The camera failing (the shadow's scene): 0 is nothing, 1 is the worst: whole bands of rows thrown sideways, the picture rolling and jumping, the colours torn apart, snow.
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
// How dark the whole picture is (the light flickering and failing): 0 is as it is, 1 is black.
uniform float dim : hint_range(0.0, 1.0) = 0.0;

// A hash with no sine in it (a sine's pattern shows as diagonal stripes once the numbers are large).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// The screen's colour where the picture's own point `uv` is (`uv0` and `screen_uv0` are this fragment's, in the picture and on the screen).
vec3 tap(vec2 uv, vec2 uv0, vec2 screen_uv0, vec2 pixel) {
	return texture(screen_texture, screen_uv0 + (uv - uv0) * picture_pixels * pixel).rgb;
}

void fragment() {
	float frame = mod(floor(TIME * fps), 4096.0);
	vec2 uv = UV;
	float row = floor(uv.y * tape_size.y);

	// The lines of the tape: each row slips a little sideways, the whole picture shivers by a pixel or two now and then, and along the bottom
	// the head-switching noise tears the rows.
	float slip = (hash(vec2(row, frame)) - 0.5) * 0.0035;
	float foot = smoothstep(0.93, 1.0, uv.y);
	slip += (hash(vec2(row, frame + 5.0)) - 0.5) * 0.05 * foot;
	// Failing (the shadow's scene): whole bands of rows are thrown across the picture, the rows wobble, the picture jumps, loses its vertical hold and rolls, and pulses in size.
	float band = floor(uv.y * 16.0 + hash(vec2(frame, 1.7)) * 16.0);
	slip += (hash(vec2(band, frame + 11.0)) - 0.5) * 0.8 * glitch * step(0.4, hash(vec2(band, frame + 2.0)));
	slip += sin(uv.y * 38.0 + frame * 1.7) * 0.016 * glitch * step(0.5, hash(vec2(frame, 40.0)));
	float jump = (hash(vec2(frame, 6.0)) - 0.5) * 0.6 * glitch * step(0.6, hash(vec2(frame, 5.0)));
	float hold = glitch * step(0.72, hash(vec2(frame, 14.0))) * fract(TIME * 1.7);
	vec2 at = uv + vec2(slip, (hash(vec2(frame, 9.0)) - 0.5) * 0.0025) * degrade;
	at = (at - 0.5) * (1.0 - 0.12 * glitch * hash(vec2(frame, 50.0))) + 0.5;
	at.y = fract(at.y + jump + hold);

	vec3 clean = tap(uv, UV, SCREEN_UV, SCREEN_PIXEL_SIZE);

	// The coarse picture: snapped to the tape's own grid, smeared along the lines (luma), the colour spread wider and off to the side.
	vec2 coarse = (floor(at * tape_size) + 0.5) / tape_size;
	float step_x = 1.0 / tape_size.x;
	vec3 a = tap(coarse, UV, SCREEN_UV, SCREEN_PIXEL_SIZE);
	vec3 b = tap(coarse + vec2(step_x * 1.5, 0.0), UV, SCREEN_UV, SCREEN_PIXEL_SIZE);
	vec3 c0 = tap(coarse - vec2(step_x * 1.5, 0.0), UV, SCREEN_UV, SCREEN_PIXEL_SIZE);
	float luma = dot(a, vec3(0.299, 0.587, 0.114)) * 0.4 + dot(b, vec3(0.299, 0.587, 0.114)) * 0.3 + dot(c0, vec3(0.299, 0.587, 0.114)) * 0.3;
	// The colours are torn apart sideways as the camera fails.
	float split = step_x * (3.0 + 16.0 * glitch);
	vec3 bleed = vec3(tap(coarse + vec2(split, 0.0), UV, SCREEN_UV, SCREEN_PIXEL_SIZE).r, a.g, tap(coarse - vec2(split, 0.0), UV, SCREEN_UV, SCREEN_PIXEL_SIZE).b);
	vec3 worn = vec3(luma) + (bleed - vec3(dot(bleed, vec3(0.299, 0.587, 0.114)))) * 1.2;
	// A second, ghostly image of the picture lags beside it as the camera fails.
	vec3 ghost_image = tap(coarse - vec2(0.05 * glitch, 0.0), UV, SCREEN_UV, SCREEN_PIXEL_SIZE);
	worn = mix(worn, vec3(dot(ghost_image, vec3(0.299, 0.587, 0.114))) + (bleed - vec3(dot(bleed, vec3(0.299, 0.587, 0.114)))) * 0.6, 0.4 * glitch);

	vec3 c = mix(clean, worn, degrade);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * vec3(1.0, 0.97, 0.74), desaturation);

	// The exposure hunts a little, slowly, and never settles; the highlights bloom and the blacks are lifted.
	float expo = 1.0 + degrade * (0.05 * sin(TIME * 0.9) + 0.03 * (hash(vec2(frame, 3.1)) - 0.5));
	c *= expo;
	c = (c - 0.5) * contrast + 0.5 + brightness;
	c += degrade * 0.22 * pow(max(l - 0.5, 0.0), 1.4);
	c = c * (1.0 - 0.1 * degrade) + 0.045 * degrade;

	// The grain, as coarse as the tape's own picture, new every tape frame.
	float n = hash(floor(uv * tape_size * 0.9) + frame * 17.0) - 0.5;
	c += n * grain * (0.35 + 0.65 * degrade);

	// Dropouts: short bright dashes along a line, gone the next frame.
	float dash_row = hash(vec2(row, frame));
	float start = hash(vec2(row, frame + 7.0));
	float dash = step(0.9985, dash_row) * step(start, uv.x) * step(uv.x, start + 0.08 + 0.22 * hash(vec2(row, frame + 3.0)));
	c = mix(c, vec3(0.88), dash * 0.8 * degrade);

	// The noisy band along the bottom edge.
	float band_noise = hash(vec2(floor(uv.x * tape_size.x * 0.5), row + frame * 3.0));
	c = mix(c, vec3(band_noise * 0.9), foot * 0.45 * degrade);

	c -= scanlines * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159)) * mix(1.0, 0.0, 1.0 - degrade);
	vec2 d = UV - 0.5;
	c *= 1.0 - vignette * dot(d, d) * 2.0 * (0.4 + 0.6 * degrade);

	// Failing: whole frames of the picture turned to its negative, frames dropped to black, a red wash, and (below) streaks of snow.
	c = mix(c, vec3(1.0) - c, 0.5 * glitch * step(0.95, hash(vec2(frame, 33.0))));
	c *= 1.0 - 0.75 * glitch * step(0.92, hash(vec2(frame, 44.0)));
	c += vec3(0.3, 0.0, 0.02) * glitch * step(0.9, hash(vec2(frame, 60.0)));
	// Failing: streaks of snow on some rows, and a flash now and then.
	float snow_rows = glitch * 0.5 * step(0.74, hash(vec2(row, frame + 19.0)));
	c = mix(c, vec3(hash(floor(FRAGCOORD.xy * 0.5) + frame * 13.0) * 0.8), snow_rows);
	c += glitch * 0.25 * step(0.9, hash(vec2(frame, 21.0)));

	c *= 1.0 - dim;

	// The end of the tape.
	c = mix(c, vec3(hash(floor(FRAGCOORD.xy * 0.5) + frame * 31.0) * 0.85), burst);
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
