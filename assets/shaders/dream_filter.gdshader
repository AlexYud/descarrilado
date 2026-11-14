shader_type canvas_item;
render_mode unshaded;

// The dream look (the player's `DreamFilter`, on by default): the picture as if shot through a diffusion filter on an old film stock.
// The pieces are the ones cinema and games use for the soft, dreamy picture, kept gentle so the night stays dark:
//  - diffusion (a Pro-Mist / Glimmerglass filter): every bright thing blooms into its surroundings, the brighter it is the wider its halo. Done as a
//    bright pass blurred at several scales (the screen's mip levels, each a wider blur), summed with the wider scales weighted by how bright the
//    light is, worked in linear light;
//  - the Orton glow (the photographer's "soft dreamy" edit): a blurred, brighter copy of the whole picture screened over the sharp one at a low
//    opacity, and a little of the blur mixed in, so the picture is a touch soft, never smeared;
//  - halation (film): a faint red-orange fringe round the strongest lights, from light scattered back through the film's base;
//  - the grade: blacks lifted a hair (a mist filter's milky shadows), colour a little drained and warmed, highlights rolled off softly;
//  - a soft vignette, a little colour fringing toward the edges, a gentle fisheye bulge, and fine grain.
// It never takes the game away from the player: what is already bright (a wall or a page in the flashlight's beam) gets no glow or blur on top of
// it, only round it (the energy-conserving spread modern engines use instead of a glow added over everything), and the middle of the picture, where the
// player looks and the light points, is kept clearer (a lens is sharpest at its centre).

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

// The whole look, 0 (off) to 1.
uniform float strength : hint_range(0.0, 1.0) = 1.0;

// Diffusion: where the bright pass starts (linear luminance), its soft knee, and how strong the halo is.
uniform float glow_threshold : hint_range(0.0, 2.0) = 0.2;
uniform float glow_knee : hint_range(0.01, 1.0) = 0.35;
uniform float glow_strength : hint_range(0.0, 4.0) = 2.3;
// How much the brightest lights widen their halo (more of the wide scales for them).
uniform float glow_spread : hint_range(0.0, 1.0) = 0.6;

// Orton: the blurred copy screened over the picture, and the share of plain softness.
uniform float orton_opacity : hint_range(0.0, 1.0) = 0.3;
uniform float orton_exposure : hint_range(1.0, 4.0) = 1.8;
uniform float soft_focus : hint_range(0.0, 1.0) = 0.42;

// Halation.
uniform vec3 halation_tint : source_color = vec3(1.0, 0.36, 0.16);
uniform float halation_strength : hint_range(0.0, 2.0) = 0.85;
uniform float halation_threshold : hint_range(0.0, 3.0) = 0.45;

// The grade.
uniform float black_lift : hint_range(0.0, 0.1) = 0.018;
uniform vec3 lift_tint : source_color = vec3(0.55, 0.45, 0.62);
uniform float saturation : hint_range(0.0, 1.5) = 0.9;
uniform vec3 warmth : source_color = vec3(1.0, 0.975, 0.95);
uniform float highlight_rolloff : hint_range(0.0, 1.0) = 0.35;

// Readability: how much of the softness and glow is taken off the middle of the picture (and how wide the middle is, as a share of the
// picture's height), and how much a surface that is already bright is kept free of glow and blur (a wall or a page in the flashlight's beam).
uniform float clear_centre : hint_range(0.0, 1.0) = 0.8;
uniform float clear_radius : hint_range(0.05, 1.0) = 0.32;
uniform float protect_highlights : hint_range(0.0, 1.0) = 0.85;

// The lens: a gentle barrel bulge (0 is none).
uniform float fisheye_strength : hint_range(0.0, 0.3) = 0.04;

// Edges and texture.
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.22;
uniform float fringe_pixels : hint_range(0.0, 4.0) = 1.1;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.018;

// 1 is every tap; 0.5 fewer taps per scale; 0 one tap per scale and no fringing (the Low preset).
uniform float sample_quality : hint_range(0.0, 1.0) = 1.0;


vec3 to_linear(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(2.2));
}


vec3 to_display(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
}


float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}


vec2 clamp_uv(vec2 uv) {
	return clamp(uv, vec2(0.001), vec2(0.999));
}


// The screen blurred at mip level `lod`, smoothed: four taps round the point (half a texel of that level out, turned a little at each level) so the
// coarse levels do not show their blocks. Linear light.
vec3 blurred(vec2 uv, float lod, vec2 pixel) {
	vec2 texel = pixel * exp2(lod);
	if (sample_quality < 0.25) {
		return to_linear(textureLod(screen_texture, clamp_uv(uv), lod).rgb);
	}
	float turn = lod * 0.7;
	vec2 a = vec2(cos(turn), sin(turn)) * texel * 0.75;
	vec2 b = vec2(-a.y, a.x);
	vec3 sum = to_linear(textureLod(screen_texture, clamp_uv(uv + a), lod).rgb);
	sum += to_linear(textureLod(screen_texture, clamp_uv(uv - a), lod).rgb);
	if (sample_quality > 0.75) {
		sum += to_linear(textureLod(screen_texture, clamp_uv(uv + b), lod).rgb);
		sum += to_linear(textureLod(screen_texture, clamp_uv(uv - b), lod).rgb);
		return sum * 0.25;
	}
	return sum * 0.5;
}


// What of a colour is bright enough to bloom (a soft knee, never a hard cut).
vec3 bright_pass(vec3 c, float threshold) {
	float l = luma(c);
	float knee = smoothstep(threshold, threshold + glow_knee, l);
	return c * knee;
}


float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}


// Where the picture is read from for a point shown at `uv`: a gentle barrel (fisheye) bulge, the middle magnified a little and the edges drawn in, as
// a wide old lens does. `DreamFilter.lens_position` is its inverse (for what is laid over the picture from a 3D position).
vec2 lens_uv(vec2 uv) {
	vec2 p = uv * 2.0 - vec2(1.0);
	// Scaled so the corners (|p|^2 = 2) stay the picture's corners: nothing is read from beyond its edges (which would smear the last pixels).
	vec2 drawn = p * (1.0 + fisheye_strength * dot(p, p)) / (1.0 + 2.0 * fisheye_strength);
	return drawn * 0.5 + vec2(0.5);
}


void fragment() {
	vec2 uv = lens_uv(SCREEN_UV);
	vec2 pixel = SCREEN_PIXEL_SIZE;
	vec2 centred = uv - vec2(0.5);
	float edge = dot(centred, centred) * 4.0;
	// The middle of the picture (where the player looks, and where the flashlight points) stays clear: the softness and the glow over it are
	// taken down there, as a lens is sharpest at its centre and a game keeps its point of play readable.
	vec2 from_middle = centred * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float middle = 1.0 - smoothstep(clear_radius * 0.4, clear_radius, length(from_middle));
	float clear_here = clear_centre * middle;

	// The sharp picture, with its colours a pixel apart toward the edges (a lens's lateral fringing).
	vec3 sharp;
	if (sample_quality > 0.25 && fringe_pixels > 0.0) {
		vec2 shift = centred * pixel * fringe_pixels * edge * 2.0;
		sharp.r = textureLod(screen_texture, clamp_uv(uv + shift), 0.0).r;
		sharp.g = textureLod(screen_texture, clamp_uv(uv), 0.0).g;
		sharp.b = textureLod(screen_texture, clamp_uv(uv - shift), 0.0).b;
	} else {
		sharp = textureLod(screen_texture, clamp_uv(uv), 0.0).rgb;
	}
	vec3 picture = to_linear(sharp);

	// The scales: a little blur (the softness), and the wide ones of the halo.
	vec3 s1 = blurred(uv, 1.0, pixel);
	vec3 s2 = blurred(uv, 2.0, pixel);
	vec3 s3 = blurred(uv, 3.0, pixel);
	vec3 s4 = blurred(uv, 4.0, pixel);
	vec3 s5 = blurred(uv, 5.0, pixel);
	vec3 s6 = blurred(uv, 6.0, pixel);

	// A lit surface keeps its detail: what is already bright here (a wall in the beam, a page) gets no glow and no blur on top of it; the glow
	// falls round it, on the darker things near it (an energy-conserving spread: light moved from the bright to its surroundings, not added to it).
	float bright_here = smoothstep(0.3, 0.85, luma(sharp)) * protect_highlights;

	// A touch soft: some of the nearest blur in the picture itself (less in the middle and on lit surfaces).
	vec3 soft = mix(picture, mix(s1, s2, 0.35), soft_focus * (1.0 - clear_here) * (1.0 - bright_here * 0.7));

	// Diffusion: each scale's bright pass; the wide scales count for more where the light is strong (a brighter light, a wider halo).
	vec3 b2 = bright_pass(s2, glow_threshold);
	vec3 b3 = bright_pass(s3, glow_threshold);
	vec3 b4 = bright_pass(s4, glow_threshold);
	vec3 b5 = bright_pass(s5, glow_threshold);
	vec3 b6 = bright_pass(s6, glow_threshold);
	float hot = clamp(luma(s4) / max(glow_threshold * 3.0, 0.001), 0.0, 1.0);
	float wide = mix(0.45, 1.0, hot * glow_spread);
	vec3 halo = b2 * 0.26 + b3 * 0.26 + (b4 * 0.22 + b5 * 0.16 + b6 * 0.12) * wide;
	float glow_here = (1.0 - bright_here) * (1.0 - clear_here * 0.85);
	vec3 lit = soft + halo * glow_strength * glow_here;

	// Halation: the widest scales of the strongest lights only, red-orange (a fringe round them, never over them).
	float hal = luma(bright_pass(s4 * 0.4 + s5 * 0.35 + s6 * 0.25, halation_threshold));
	lit += halation_tint * hal * halation_strength * (1.0 - bright_here);

	// Orton: the blurred copy, brighter, screened over (in display space, as an editor's layer is).
	vec3 shown = to_display(lit);
	vec3 orton = clamp(to_display(mix(s3, s4, 0.5) * orton_exposure), 0.0, 1.0);
	shown = mix(shown, vec3(1.0) - (vec3(1.0) - shown) * (vec3(1.0) - orton), orton_opacity * glow_here);

	// The grade: highlights rolled off, colour drained a little and warmed, the blacks lifted to a milky tint.
	shown = mix(shown, shown / (vec3(1.0) + shown * 0.6), highlight_rolloff);
	shown = mix(vec3(luma(shown)), shown, saturation);
	shown *= warmth;
	shown = shown + lift_tint * black_lift * (vec3(1.0) - shown);

	// A soft vignette and fine grain.
	shown *= 1.0 - vignette_strength * smoothstep(0.35, 1.25, edge);
	float g = hash(uv * vec2(1931.0, 1093.0) + fract(TIME * 23.0)) - 0.5;
	shown += g * grain_strength * (1.0 - luma(shown) * 0.6);

	vec3 original = textureLod(screen_texture, clamp_uv(uv), 0.0).rgb;
	COLOR = vec4(mix(original, clamp(shown, 0.0, 1.0), strength), 1.0);
}
