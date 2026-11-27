shader_type spatial;
render_mode unshaded, fog_disabled;
// Home, seen from far away: oceans, farm-green continents, drifting clouds and a blue rim.

uniform vec3 light_dir = vec3(0.6, 0.35, 0.7);

varying vec3 local_dir;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1) * 0.3 + vnoise(p * 4.3) * 0.15;
}

void vertex() {
	local_dir = normalize(VERTEX);
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float land = fbm(local_dir * 2.6 + 3.0);
	vec3 col = mix(vec3(0.07, 0.25, 0.65), vec3(0.12, 0.42, 0.82), vnoise(local_dir * 7.0));
	if (land > 0.53) {
		col = mix(vec3(0.2, 0.55, 0.24), vec3(0.75, 0.62, 0.3), smoothstep(0.58, 0.72, land));
	}
	if (abs(local_dir.y) > 0.86) {
		col = vec3(0.93, 0.96, 1.0);
	}
	float cloud = smoothstep(0.55, 0.75, fbm(local_dir * 3.8 + vec3(TIME * 0.01, 0.0, 11.0)));
	col = mix(col, vec3(1.0), cloud * 0.85);
	float lit = smoothstep(-0.25, 0.4, dot(world_normal, normalize(light_dir)));
	col *= 0.12 + 0.95 * lit;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	col += vec3(0.25, 0.55, 1.0) * rim * (0.25 + 0.75 * lit);
	ALBEDO = col;
}
