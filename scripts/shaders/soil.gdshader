shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// Tilled soil. `wet` darkens it and adds a damp sheen (tweened while you water, so you can watch it
// soak in); `soak` spreads the dark patch out from the middle; `compost` sprinkles dark and green flecks.

uniform vec3 dry_color : source_color = vec3(0.60, 0.40, 0.23);
uniform vec3 wet_color : source_color = vec3(0.27, 0.17, 0.10);
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float compost : hint_range(0.0, 1.0) = 0.0;

varying vec3 local_pos;
varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise(world_pos.xz * 7.0);
	float grain = noise(world_pos.xz * 23.0);
	// The dark patch grows from the centre outwards, with a ragged edge.
	float r = length(local_pos.xz) / 1.3 + (n - 0.5) * 0.35;
	float w = clamp((wet * 1.5 - r) * 4.0, 0.0, 1.0);
	float ridge = smoothstep(0.0, 0.11, local_pos.y);
	vec3 c = mix(dry_color, wet_color, w);
	c *= mix(0.78, 1.12, ridge);
	c *= 0.9 + 0.2 * grain;
	float fleck = step(0.80, noise(world_pos.xz * 15.0 + 9.0)) * compost;
	float green = step(0.78, noise(world_pos.xz * 19.0 + 31.0)) * compost;
	c = mix(c, vec3(0.10, 0.07, 0.04), fleck * 0.85);
	c = mix(c, vec3(0.30, 0.52, 0.16), green * 0.8);
	ALBEDO = c;
	ROUGHNESS = mix(1.0, 0.42, w * (1.0 - ridge * 0.7));
	SPECULAR = 0.35 * w;
}
