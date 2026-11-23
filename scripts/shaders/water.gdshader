shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;
// Stylised water: gentle waves, moving ripple bands and sparkles.

uniform vec3 deep : source_color = vec3(0.12, 0.42, 0.62);
uniform vec3 shallow : source_color = vec3(0.32, 0.68, 0.78);
uniform float flow = 0.6;
uniform sampler2D shore_tex : filter_linear, repeat_disable;   // baked: 1 at the shoreline, 0 in deep water
uniform float world_size = 400.0;

varying vec3 world_pos;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_pos.x * 0.5 + TIME * 1.3) * 0.04 + cos(world_pos.z * 0.4 + TIME) * 0.04;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 drift = vec2(0.0, TIME * flow);
	float n1 = noise(p * 0.35 + drift);
	float n2 = noise(p * 0.9 - drift * 1.3);
	vec3 col = mix(deep, shallow, smoothstep(0.35, 0.75, n1 * 0.6 + n2 * 0.4));
	float bands = smoothstep(0.46, 0.5, n2) - smoothstep(0.5, 0.54, n2);
	col += vec3(0.25) * bands;
	float sparkle = step(0.965, noise(p * 2.5 + vec2(TIME * 0.7, -TIME * 0.4)));
	col += vec3(0.6) * sparkle;
	// Shoreline foam from a baked shore-proximity map, broken up with moving noise.
	float shore = texture(shore_tex, world_pos.xz / world_size + 0.5).r;
	float foam_n = noise(p * 2.2 + vec2(TIME * 0.3, TIME * 0.18));
	float edge = smoothstep(0.5, 0.62, shore + (foam_n - 0.5) * 0.28 + sin(TIME * 1.4 + p.x * 1.7 + p.y) * 0.03);
	col = mix(col, vec3(0.96, 0.99, 1.0), edge);
	ALBEDO = col;
	ALPHA = mix(0.84, 0.97, edge);
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
