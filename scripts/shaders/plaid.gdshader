shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Checked flannel for the scarecrow, with a weave and a hem that flaps in the wind.
// The check is in the mesh's own space; loose ends (lower down) flutter the most.

#include "res://scripts/shaders/toon_light.gdshaderinc"

uniform vec4 base : source_color = vec4(0.78, 0.22, 0.18, 1.0);
uniform vec4 stripe : source_color = vec4(0.98, 0.84, 0.6, 1.0);
uniform float flutter = 0.02;
uniform float half_height = 0.25;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
	vec3 o = MODEL_MATRIX[3].xyz;
	float loose = clamp((half_height - VERTEX.y) / (2.0 * half_height), 0.0, 1.0);
	float gust = 0.65 + 0.35 * sin(TIME * 0.9 + o.x);
	float wave = sin(TIME * 5.5 + VERTEX.x * 9.0 + VERTEX.y * 7.0 + o.x * 2.0 + o.z);
	VERTEX.z += wave * flutter * loose * gust;
}

void fragment() {
	vec2 p = vec2(lpos.x + lpos.z * 0.6, lpos.y) * 8.5;
	float bx = step(0.62, fract(p.x));
	float by = step(0.62, fract(p.y));
	vec3 c = mix(base.rgb, stripe.rgb, (bx + by) * 0.34);
	float thin = max(step(0.93, fract(p.x + 0.2)), step(0.93, fract(p.y + 0.2)));
	c = mix(c, stripe.rgb, thin * 0.5);
	c *= 0.95 + 0.05 * sin(p.x * 38.0) * sin(p.y * 38.0);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
