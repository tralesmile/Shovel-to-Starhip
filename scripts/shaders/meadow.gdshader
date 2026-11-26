shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
// Living meadow grass: rolling wind gusts (with a pale sheen where they pass), blades that bend away from
// feet, wheels and animals (plus a fading wake), a bomb shockwave ripple, and cut/stubble per instance.
// INSTANCE_CUSTOM: x = cut (0 full, 1 stubble, 2 hidden under a floor), y = tint 0..1, z = 1 tall.

#include "res://scripts/shaders/toon_light.gdshaderinc"

uniform vec4 benders[12];          // xyz = world position, w = radius (0 = unused)
uniform float bend_power[12];      // 0..1 strength (the wake fades out)
uniform vec4 shock;                // x, z, wave radius, strength
uniform float wind_strength = 1.0; // weather pushes this up
uniform vec3 root_color : source_color = vec3(0.19, 0.40, 0.21);
uniform vec3 tip_color : source_color = vec3(0.52, 0.74, 0.30);
uniform vec3 dry_color : source_color = vec3(0.86, 0.76, 0.36);
uniform vec3 stubble_color : source_color = vec3(0.60, 0.62, 0.32);

varying float tip;
varying float tint;
varying float gust_v;
varying float tall;
varying float cut_v;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	float cut = INSTANCE_CUSTOM.x;
	tint = INSTANCE_CUSTOM.y;
	tall = INSTANCE_CUSTOM.z;
	cut_v = cut;
	tip = UV.y;
	if (cut > 1.5) {
		VERTEX = vec3(0.0);
	} else {
		if (cut > 0.5) {
			VERTEX.y *= mix(0.45, 0.17, tall);
		}
		vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float h = max(wpos.y - base.y, 0.0);
		float bendy = UV.y * UV.y;   // roots stay put, tips swing
		float loose = cut > 0.5 ? 0.15 : 1.0;
		// Gusts: soft noise bands rolling downwind across the whole field.
		float gust = smoothstep(0.45, 0.85, vnoise(wpos.xz * 0.11 - vec2(TIME * 0.85, TIME * 0.35)));
		gust_v = gust * bendy;
		float flutter = sin(TIME * 2.3 + wpos.x * 1.7 + wpos.z * 1.3) * 0.05;
		vec2 push = vec2(1.0, 0.42) * (flutter + gust * 0.26) * wind_strength * loose;
		float squash = gust * 0.06 * loose;
		for (int i = 0; i < 12; i++) {
			vec4 b = benders[i];
			if (b.w <= 0.0) {
				continue;
			}
			vec2 d = base.xz - b.xz;
			float dist = length(d);
			if (dist < b.w && abs(base.y - b.y) < 1.8) {
				float k = (1.0 - dist / b.w) * bend_power[i];
				vec2 away = dist > 0.01 ? d / dist : vec2(1.0, 0.0);
				push += away * min(k * 2.0, 1.0) * 0.75 * loose;
				squash += min(k * 1.6, 0.7) * loose;
			}
		}
		if (shock.w > 0.0) {
			vec2 d = base.xz - shock.xy;
			float dist = length(d);
			float ring = max(1.0 - abs(dist - shock.z) / 1.6, 0.0) * shock.w;
			if (dist > 0.01) {
				push += d / dist * ring * 1.1;
				squash += ring * 0.5;
			}
		}
		vec3 off = vec3(push.x * bendy * h, -min(squash, 0.8) * bendy * h, push.y * bendy * h);
		// World offset back into model space (instances are only yawed and uniformly scaled).
		mat3 basis = mat3(MODEL_MATRIX);
		VERTEX += (transpose(basis) * off) / dot(basis[0], basis[0]);
	}
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 top = mix(tip_color, tip_color * vec3(1.12, 1.04, 0.8), tint);
	top = mix(top, dry_color, smoothstep(0.78, 1.0, tint) * tall);
	vec3 col = mix(root_color, top, smoothstep(0.0, 0.95, tip));
	if (cut_v > 0.5) {
		col = mix(root_color, stubble_color, tip);
	}
	col += vec3(0.13, 0.16, 0.07) * gust_v * step(cut_v, 0.5);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	// Light both faces like the ground so blades never turn black from behind.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
