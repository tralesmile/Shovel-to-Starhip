shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Hand-made look for built pieces: wood grain with knots, speckled stone, or weathered shingles.
// Pattern is in the mesh's own space so it travels with the board while it is being assembled.

#include "res://scripts/shaders/toon_light.gdshaderinc"

uniform vec4 base : source_color = vec4(0.74, 0.52, 0.32, 1.0);
uniform int surface = 0;      // 0 wood, 1 stone, 2 shingle
uniform int grain_axis = 1;   // 0 x, 1 y, 2 z : the direction the grain runs
uniform bool baked = false;   // welded piece: board position and shade come from CUSTOM0

varying vec3 lpos;
varying float tint;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	if (baked) {
		lpos = CUSTOM0.xyz;
		tint = CUSTOM0.w;
	} else {
		lpos = VERTEX;
		// Every board gets its own shade, from where it ends up in the world.
		tint = hash(floor(MODEL_MATRIX[3].xyz * 3.0 + 0.37));
	}
}

void fragment() {
	vec3 col = base.rgb * mix(0.88, 1.12, tint);
	if (surface == 0) {
		float along = grain_axis == 0 ? lpos.x : (grain_axis == 1 ? lpos.y : lpos.z);
		vec2 across = grain_axis == 0 ? lpos.yz : (grain_axis == 1 ? lpos.xz : lpos.xy);
		float a = across.x + across.y;
		float wobble = noise(vec3(a * 5.0, along * 1.7, tint * 20.0));
		float line = smoothstep(0.62, 0.95, abs(sin(a * 34.0 + wobble * 7.0)));
		col *= 1.0 - 0.17 * line;
		float knot = smoothstep(0.78, 0.9, noise(vec3(a * 9.0, along * 3.2, tint * 31.0)));
		col *= 1.0 - 0.28 * knot;
	} else if (surface == 1) {
		float n = noise(lpos * 7.0 + tint * 40.0);
		float fine = noise(lpos * 24.0);
		col *= 0.86 + 0.24 * n + 0.1 * fine;
		col = mix(col, vec3(0.36, 0.5, 0.27), smoothstep(0.68, 0.86, noise(lpos * 3.1 + tint * 9.0)) * 0.35);
	} else {
		float n2 = noise(lpos * vec3(14.0, 6.0, 3.0) + tint * 17.0);
		col *= 0.9 + 0.2 * n2;
		col = mix(col, col.brg * 0.85, smoothstep(0.74, 0.92, noise(lpos * 2.3 + tint * 5.0)) * 0.18);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
