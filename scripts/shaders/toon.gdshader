shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Cartoon material used for every model. Keeps the model's own texture/colour.

#include "res://scripts/shaders/wind.gdshaderinc"
#include "res://scripts/shaders/toon_light.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform bool use_vertex_color = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float window_glow = 0.0;   // >0 at night: bluish window panes glow warm

void vertex() {
	VERTEX = apply_wind(VERTEX, MODEL_MATRIX, TIME);
}

void fragment() {
	vec4 c = albedo_color;
	if (use_tex) {
		c *= texture(albedo_tex, UV);
	}
	if (use_vertex_color) {
		c *= COLOR;
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
	vec3 em = emission_color * emission_energy;
	if (window_glow > 0.0) {
		float is_window = step(c.r + 0.12, c.b) * step(0.55, c.b) * step(c.g, c.b + 0.05);
		em += vec3(1.0, 0.78, 0.38) * is_window * window_glow * 1.6;
	}
	EMISSION = em;
}
