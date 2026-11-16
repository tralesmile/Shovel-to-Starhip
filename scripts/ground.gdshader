shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Terrain: grass with soft colour variation, sandy shores, rocky slopes,
// warmer hilltops, and worn dirt paths with ragged edges.

#include "res://scripts/shaders/toon_light.gdshaderinc"

uniform vec3 grass_a : source_color = vec3(0.27, 0.48, 0.27);
uniform vec3 grass_b : source_color = vec3(0.35, 0.56, 0.30);
uniform vec3 grass_dark : source_color = vec3(0.21, 0.39, 0.22);
uniform vec3 hill_top : source_color = vec3(0.45, 0.58, 0.30);
uniform vec3 dirt : source_color = vec3(0.62, 0.46, 0.30);
uniform vec3 sand : source_color = vec3(0.86, 0.78, 0.55);
uniform vec3 rock : source_color = vec3(0.52, 0.5, 0.48);

varying vec3 world_pos;
varying vec3 world_nrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = noise(p * 0.08) * 0.6 + noise(p * 0.3) * 0.3 + noise(p * 1.5) * 0.1;
	vec3 col = mix(grass_a, grass_b, smoothstep(0.3, 0.7, n));
	float patches = smoothstep(0.62, 0.8, noise(p * 0.05 + 7.0));
	col = mix(col, grass_dark, patches * 0.6);
	// Hilltops dry out a little.
	col = mix(col, hill_top, smoothstep(2.0, 8.0, world_pos.y) * 0.6);
	// Rocky where it's steep.
	float slope = 1.0 - world_nrm.y;
	col = mix(col, rock, smoothstep(0.32, 0.45, slope));
	// Sandy near water.
	col = mix(col, sand, 1.0 - smoothstep(-0.75, -0.35, world_pos.y));
	// Paths: farm gate -> road, farm -> house, farm -> store, store -> spaceport.
	float d = seg(p, vec2(0.0, 5.0), vec2(0.0, 11.5));
	d = min(d, seg(p, vec2(-1.0, 7.0), vec2(-12.5, 1.8)));
	d = min(d, seg(p, vec2(1.0, 7.5), vec2(14.0, 8.8)));
	d = min(d, seg(p, vec2(14.0, 8.8), vec2(24.0, -8.0)));
	d = min(d, seg(p, vec2(24.0, -8.0), vec2(31.0, -18.0)));
	d += (noise(p * 0.9) - 0.5) * 0.45;
	float path = 1.0 - smoothstep(0.55, 0.85, d);
	vec3 dirt_col = dirt * (0.9 + 0.2 * noise(p * 3.0));
	col = mix(col, dirt_col, path);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
