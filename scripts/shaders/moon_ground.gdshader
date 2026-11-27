shader_type spatial;
// Moon dust: crater shading comes from vertex colours; this adds grit, pits and sparkle.
#include "toon_light.gdshaderinc"

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float grain = vnoise(p * 9.0) * 0.6 + vnoise(p * 27.0) * 0.4;
	float patches = vnoise(p * 0.23) * 0.65 + vnoise(p * 0.9) * 0.35;
	vec2 cell = floor(p * 1.6);
	vec2 off = vec2(hash(cell), hash(cell + 3.7)) * 0.5 + 0.25;
	float d = length(fract(p * 1.6) - off);
	float pit = step(0.8, hash(cell + 9.1)) * (1.0 - smoothstep(0.1, 0.2, d));
	float lip = step(0.8, hash(cell + 9.1)) * (1.0 - smoothstep(0.02, 0.06, abs(d - 0.2)));
	vec3 col = COLOR.rgb * (0.84 + 0.2 * grain + 0.16 * patches);
	col *= 1.0 - 0.3 * pit;
	col += lip * 0.07;
	// A few glinting grains.
	float glint = step(0.996, hash(floor(p * 14.0)));
	EMISSION = vec3(glint) * (0.12 + 0.12 * sin(TIME * 2.0 + hash(floor(p * 14.0)) * 40.0));
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
