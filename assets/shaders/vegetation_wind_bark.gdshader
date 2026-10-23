// Trunks and branches: an opaque textured surface with a normal map and a roughness map, swaying in the
// wind together with the leaves on them (the same sway amount and bend height, so the leaves stay on the
// branches). Looks like the StandardMaterial3D it replaces (see VegetationWind).
shader_type spatial;
render_mode cull_disabled;

#include "res://assets/shaders/vegetation_wind.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;

void vertex() {
	VERTEX += wind_local_offset(VERTEX, MODEL_MATRIX, CAMERA_POSITION_WORLD, TIME);
}

void fragment() {
	ALBEDO = (texture(albedo_texture, UV) * albedo_color).rgb;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	ROUGHNESS = texture(roughness_texture, UV).g * roughness;
}
