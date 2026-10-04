shader_type spatial;
render_mode cull_back;

// Forest floor for the main-menu scenery chunks, which cannot use Terrain3D
// because they loop. The mesh's vertex colour holds the blend weights:
//   R = moss, G = humus, B = pine needles, A = dirt (track bed).
// Whatever weight is left is leaf litter. UV is the ring coordinate in metres
// (x, distance along the 128 m loop), so textures continue across chunks.

uniform sampler2D tex_leaves : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_moss : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_humus : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_mulch : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_dirt : source_color, repeat_enable, filter_linear_mipmap_anisotropic;

uniform sampler2D nrm_leaves : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D nrm_moss : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D nrm_humus : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D nrm_mulch : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D nrm_dirt : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;

uniform vec3 tint_leaves : source_color = vec3(0.72, 0.7, 0.66);
uniform vec3 tint_moss : source_color = vec3(0.75, 0.78, 0.7);
uniform vec3 tint_humus : source_color = vec3(0.8, 0.8, 0.8);
uniform vec3 tint_mulch : source_color = vec3(0.72, 0.66, 0.6);
uniform vec3 tint_dirt : source_color = vec3(0.55, 0.52, 0.5);

uniform float uv_scale = 0.4;
uniform float normal_depth = 0.6;

vec3 mix_albedo(vec2 uv, vec4 weights, float leaves_weight) {
	return (
		texture(tex_leaves, uv).rgb * tint_leaves * leaves_weight
		+ texture(tex_moss, uv).rgb * tint_moss * weights.r
		+ texture(tex_humus, uv).rgb * tint_humus * weights.g
		+ texture(tex_mulch, uv).rgb * tint_mulch * weights.b
		+ texture(tex_dirt, uv).rgb * tint_dirt * weights.a
	);
}

void fragment() {
	vec4 w = COLOR;
	float total = w.r + w.g + w.b + w.a;
	if (total > 1.0) {
		w /= total;
		total = 1.0;
	}
	float leaves_weight = 1.0 - total;

	vec2 uv = UV * uv_scale;
	// A second, rotated and rescaled sample, cross-faded, hides the repeat.
	vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.71 + vec2(0.37, 0.19);
	float blend = 0.5 + 0.5 * sin(uv.x * 0.9) * sin(uv.y * 0.9);

	vec3 a = mix_albedo(uv, w, leaves_weight);
	vec3 b = mix_albedo(uv2, w, leaves_weight);
	ALBEDO = mix(a, b, blend);

	vec3 n = (
		texture(nrm_leaves, uv).rgb * leaves_weight
		+ texture(nrm_moss, uv).rgb * w.r
		+ texture(nrm_humus, uv).rgb * w.g
		+ texture(nrm_mulch, uv).rgb * w.b
		+ texture(nrm_dirt, uv).rgb * w.a
	);
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
