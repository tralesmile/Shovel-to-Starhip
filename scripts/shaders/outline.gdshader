shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, skip_vertex_transform;
// Inverted-hull outline drawn behind each model (second pass).

#include "res://scripts/shaders/wind.gdshaderinc"

uniform float width = 0.025;          // metres in world space
uniform vec4 line_color : source_color = vec4(0.12, 0.1, 0.12, 1.0);

void vertex() {
	vec3 v = apply_wind(VERTEX, MODEL_MATRIX, TIME);
	vec4 view_pos = MODELVIEW_MATRIX * vec4(v, 1.0);
	vec3 view_n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Keep lines readable far away but thin up close.
	float w = width * clamp(-view_pos.z / 12.0, 0.6, 2.5);
	view_pos.xyz += view_n * w;
	VERTEX = view_pos.xyz;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
