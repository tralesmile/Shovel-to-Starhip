shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
// Crop leaves (one merged mesh per plant). Vertex colour = leaf colour, UV.y = 0 at the root and
// 1 at the tip, so only the tips flutter in the wind.

#include "res://scripts/shaders/toon_light.gdshaderinc"

uniform float sway = 0.05;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = 0.6 + 0.4 * sin(TIME * 0.7 + w.x * 0.18);
	float t = UV.y * UV.y;
	VERTEX.x += sin(TIME * 2.3 + w.x * 1.7 + w.z * 1.1) * sway * t * gust;
	VERTEX.z += cos(TIME * 1.9 + w.z * 1.5) * sway * 0.6 * t * gust;
	VERTEX.y += sin(TIME * 3.1 + w.x * 4.0 + w.z * 3.0) * sway * 0.35 * t;
}

void fragment() {
	// Pale midrib, darker toward the root.
	float rib = 1.0 - smoothstep(0.02, 0.09, abs(UV.x - 0.5));
	vec3 c = COLOR.rgb * mix(0.72, 1.12, UV.y);
	ALBEDO = mix(c, c * 1.35, rib * 0.6);
	ROUGHNESS = 1.0;
	EMISSION = ALBEDO * 0.06;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
