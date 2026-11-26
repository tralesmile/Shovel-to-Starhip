shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// A fish silhouette seen through the water: teardrop body, flicking tail, soft edge.

uniform float wiggle_rate = 4.5;
uniform float phase = 0.0;
uniform float junk = 0.0;   // sunken junk is a lumpy blob that does not swim
uniform float gold = 0.0;   // golden carp glint

void vertex() {
	float tail = clamp(0.5 - UV.x, 0.0, 1.0);           // 0 at the nose half, 0.5 at the tail tip
	VERTEX.z += sin(TIME * wiggle_rate + phase - UV.x * 5.0) * tail * tail * 0.5 * (1.0 - junk);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;   // x: -1 tail .. +1 nose
	float body = length(vec2((p.x - 0.2) / 0.72, p.y / (0.52 - 0.16 * clamp(-p.x + 0.2, 0.0, 1.0))));
	float a = 1.0 - smoothstep(0.78, 1.05, body);
	float tx = (-p.x - 0.42) / 0.55;                     // 0 at the tail root, 1 at the tip
	if (tx > 0.0 && tx < 1.0) {
		float half_w = 0.1 + 0.55 * tx;
		float notch = max(0.0, tx - 0.55) * 0.7;
		a = max(a, (1.0 - smoothstep(half_w - 0.1, half_w, abs(p.y))) * smoothstep(notch - 0.08, notch, abs(p.y)) * (1.0 - smoothstep(0.85, 1.0, tx)));
	}
	float side = (1.0 - smoothstep(0.1, 0.22, length(vec2((p.x - 0.2) / 0.5, (abs(p.y) - 0.52) / 1.1))));
	a = max(a, side * 0.7);
	if (junk > 0.5) {
		float ang = atan(p.y, p.x);
		a = 1.0 - smoothstep(0.55, 0.75, length(p) + sin(ang * 3.0 + phase) * 0.09);
	}
	vec3 col = vec3(0.015, 0.09, 0.17);
	float glint = pow(max(0.0, sin(TIME * 2.3 + phase + p.x * 3.0)), 6.0);
	col = mix(col, vec3(0.95, 0.72, 0.12), gold * (0.35 + 0.6 * glint));
	ALBEDO = col;
	ALPHA = a * mix(0.7, 0.45, junk);
}
