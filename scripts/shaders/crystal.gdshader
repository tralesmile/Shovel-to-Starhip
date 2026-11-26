shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Glowing mine crystal: slow breathing pulse (phase varies by world position), bright fresnel rim
// and a sparkle band that slides up the facets. Works in the compatibility renderer.

uniform vec3 tint : source_color = vec3(0.35, 0.85, 1.0);
uniform float energy = 1.0;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float phase = world_pos.x * 0.9 + world_pos.z * 1.3;
	float pulse = 0.75 + 0.25 * sin(TIME * 1.8 + phase);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	float band = smoothstep(0.93, 1.0, sin(world_pos.y * 7.0 - TIME * 2.6 + phase));
	ALBEDO = tint * 0.55;
	ROUGHNESS = 0.4;
	EMISSION = (tint * (0.45 * pulse + rim * 0.9) + vec3(band * 0.6)) * energy;
}
