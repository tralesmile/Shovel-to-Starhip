shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;
// Cartoon rock, drawn entirely from rock-space position (no textures): wavy strata, speckles,
// moss on top, glinting ore veins, pale fresh-broken faces, cracks that spread from where you
// hit, a pulsing gold "sweet spot", and holes for Moon cheese.
// UV.x: 0 weathered skin, 0.5 fresh break, 1 core.

#include "res://scripts/shaders/toon_light.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(0.55, 0.56, 0.6, 1.0);
uniform vec3 vein_color : source_color = vec3(0.95, 0.55, 0.25);
uniform float veins = 0.0;          // 0 plain .. 1 rich
uniform float moss = 0.0;
uniform float cheese = 0.0;
uniform float glint = 0.35;         // how much the veins shine
uniform float crack = 0.0;          // 0 whole .. 1 about to burst
uniform vec3 crack_origin = vec3(0.0, 0.8, 0.8);
uniform vec3 spot_pos = vec3(0.0, 0.8, 0.8);
uniform float spot_on = 0.0;

varying vec3 rock_pos;

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash3(i).x, hash3(i + vec3(1, 0, 0)).x, f.x);
	float b = mix(hash3(i + vec3(0, 1, 0)).x, hash3(i + vec3(1, 1, 0)).x, f.x);
	float c = mix(hash3(i + vec3(0, 0, 1)).x, hash3(i + vec3(1, 0, 1)).x, f.x);
	float d = mix(hash3(i + vec3(0, 1, 1)).x, hash3(i + vec3(1, 1, 1)).x, f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

// distance to the border between two Voronoi cells: thin lines that read as cracks
float cell_edge(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 g = vec3(float(x), float(y), float(z));
				float d = length(g + hash3(i + g) - f);
				if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
			}
		}
	}
	return d2 - d1;
}

void vertex() {
	rock_pos = VERTEX;
}

void fragment() {
	float fresh = step(0.25, UV.x);
	float core = step(0.75, UV.x);
	vec3 base = albedo_color.rgb;
	vec3 em = vec3(0.0);
	float wave = vnoise(rock_pos * 2.2);
	float strata = sin(rock_pos.y * 13.0 + wave * 4.0 + rock_pos.x * 1.5);
	base *= 1.0 - 0.14 * smoothstep(0.35, 0.55, strata) + 0.09 * smoothstep(0.55, 0.75, -strata);
	float speck = vnoise(rock_pos * 17.0);
	base *= 1.0 - 0.2 * step(0.76, speck) + 0.16 * step(speck, 0.2);
	// fresh breaks are paler and warmer, with facets of their own
	base = mix(base, base * 1.12 + vec3(0.035, 0.022, 0.01), fresh * (1.0 - cheese));
	base = mix(base, albedo_color.rgb * 0.72, core * (1.0 - cheese));

	if (moss > 0.0) {
		vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		float m = smoothstep(0.62, 0.74, wn.y + (vnoise(rock_pos * 6.0) - 0.5) * 0.7) * (1.0 - fresh) * moss;
		base = mix(base, mix(vec3(0.07, 0.2, 0.05), vec3(0.16, 0.34, 0.07), vnoise(rock_pos * 14.0)), m);
	}

	if (veins > 0.0) {
		float n = vnoise(rock_pos * 2.6 + vec3(vnoise(rock_pos * 3.7) * 1.4));
		float width = 0.028 + 0.03 * veins + 0.025 * fresh;
		float v = 1.0 - smoothstep(width, width + 0.012, abs(n - 0.5));
		v = max(v, step(0.8 - 0.06 * fresh, vnoise(rock_pos * 7.5 + 3.1)) * step(0.45, vnoise(rock_pos * 2.0 + 9.0)));
		v *= step(0.001, veins);
		base = mix(base, vein_color, v);
		float twinkle = pow(0.5 + 0.5 * sin(TIME * 2.4 + hash3(floor(rock_pos * 9.0)).x * 40.0), 14.0);
		em += vein_color * v * (0.1 + twinkle * 1.1) * glint;
	}

	if (cheese > 0.0) {
		vec3 q = rock_pos * 3.4;
		vec3 i = floor(q);
		float d = length(fract(q) - (0.25 + 0.5 * hash3(i)));
		float hole = 1.0 - smoothstep(0.24, 0.29, d);
		base = mix(base, base * 0.45, hole * step(0.35, hash3(i + 7.0).y));
	}

	if (crack > 0.0) {
		float reach = 0.25 + crack * 1.5;
		float near = 1.0 - smoothstep(reach * 0.65, reach, distance(rock_pos, crack_origin) + (vnoise(rock_pos * 5.0) - 0.5) * 0.35);
		if (near > 0.0) {
			vec3 warp = vec3(vnoise(rock_pos * 7.0), vnoise(rock_pos * 7.0 + 5.2), vnoise(rock_pos * 7.0 + 9.7));
			float line = (1.0 - smoothstep(0.025 + 0.03 * crack, 0.05 + 0.04 * crack, cell_edge(rock_pos * 3.1 + warp * 0.55))) * near;
			base = mix(base, vec3(0.015, 0.012, 0.018), line);
			em *= 1.0 - line;
		}
	}

	if (spot_on > 0.0 && core < 0.5) {
		vec3 rel = rock_pos - spot_pos;
		float d = length(rel);
		float pulse = 0.5 + 0.5 * sin(TIME * 5.0);
		float ring = 1.0 - smoothstep(0.018, 0.034, abs(d - (0.23 + 0.035 * pulse)));
		float dot_ = 1.0 - smoothstep(0.05, 0.09, d);
		// a four-point star that twinkles in the middle
		vec3 a = abs(rel);
		float star = (1.0 - smoothstep(0.0, 0.2, pow(a.x, 0.5) * 0.5 + pow(a.y, 0.5) * 0.5 + pow(a.z, 0.5) * 0.5 - 0.42)) * (1.0 - smoothstep(0.1, 0.22, d));
		float mark = clamp(ring + dot_ + star, 0.0, 1.0) * spot_on;
		base = mix(base, vec3(1.0, 0.82, 0.25), mark);
		em += vec3(1.0, 0.72, 0.18) * mark * (0.55 + 0.45 * pulse);
	}

	ALBEDO = base;
	ROUGHNESS = 1.0;
	EMISSION = em;
}
