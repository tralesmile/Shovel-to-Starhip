shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Soft cartoon coat for animals: two-tone patches fixed to the body, fine tufty
// streaks and a warm rim of backlit fluff, on the shared cartoon lighting.

#include "res://scripts/shaders/toon_light.gdshaderinc"

uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 patch_color : source_color = vec4(1.0);
uniform float patch_amount : hint_range(0.0, 1.0) = 0.0;   // 0 = plain coat
uniform float patch_scale = 4.0;
uniform float patch_seed = 0.0;
uniform float tuft = 0.07;      // strength of the fine streaks
uniform float fluff = 0.22;     // strength of the soft edge glow

varying vec3 local_pos;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	// Position in the part's own space, scaled by its transform so patches keep their size.
	local_pos = VERTEX * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
}

void fragment() {
	vec3 c = base_color.rgb;
	if (patch_amount > 0.0) {
		float n = vnoise(local_pos * patch_scale + vec3(patch_seed)) * 0.75 + vnoise(local_pos * patch_scale * 2.7) * 0.25;
		c = mix(c, patch_color.rgb, smoothstep(1.0 - patch_amount - 0.02, 1.0 - patch_amount + 0.02, n));
	}
	float streak = vnoise(local_pos * vec3(55.0, 22.0, 55.0));
	c *= 1.0 + (streak - 0.5) * 2.0 * tuft;
	// Bellies sit a little warmer and darker so the round shapes read.
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	c *= mix(vec3(0.86, 0.8, 0.76), vec3(1.0), smoothstep(-0.7, 0.35, wn.y));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = c * edge * fluff * 0.45;
}
