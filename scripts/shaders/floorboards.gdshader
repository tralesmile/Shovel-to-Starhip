shader_type spatial;

// Staggered wooden floorboards with per-board tint and a faint grain.
uniform vec4 wood : source_color = vec4(0.5, 0.33, 0.19, 1.0);
uniform vec2 centre = vec2(0.0);
uniform vec2 half_size = vec2(4.0, 3.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = wpos.xz - centre;
	float row = floor(p.y / 0.34);
	float x = p.x + hash(vec2(row, 3.0)) * 2.0;
	vec2 board = vec2(floor(x / 1.5), row);
	float tint = mix(0.82, 1.14, hash(board));
	float grain = sin((x + hash(board) * 7.0) * 9.0 + sin(p.y * 38.0) * 1.6) * 0.035;
	float fy = fract(p.y / 0.34);
	float fx = fract(x / 1.5);
	float seam = smoothstep(0.0, 0.06, fy) * smoothstep(0.0, 0.015, fx);
	vec3 col = wood.rgb * (tint + grain) * mix(0.55, 1.0, seam);
	// Contact shadow where the floor meets the walls.
	vec2 edge = half_size - abs(p);
	col *= mix(0.6, 1.0, smoothstep(0.0, 0.7, min(edge.x, edge.y)));
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
}
