// Leaf and grass cards: an alpha cut-out texture, drawn on both sides, swaying in the wind.
// Looks like the StandardMaterial3D it replaces (see VegetationWind).
shader_type spatial;
render_mode cull_disabled;

#include "res://assets/shaders/vegetation_wind.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	VERTEX += wind_local_offset(VERTEX, MODEL_MATRIX, CAMERA_POSITION_WORLD, TIME);
}

void fragment() {
	vec4 color = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = color.rgb;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = roughness;
}
