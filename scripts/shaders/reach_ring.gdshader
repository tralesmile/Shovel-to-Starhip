shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
// A soft ground circle with marching dashes: "this is how far I reach".

uniform vec4 ring_color : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float radius = 0.96;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float edge = 1.0 - smoothstep(0.0, 0.028, abs(d - radius));
	float dash = step(0.35, fract(atan(p.y, p.x) * 5.7296 - TIME * 0.7));
	float fill = (1.0 - smoothstep(radius - 0.01, radius, d)) * (0.07 + 0.1 * smoothstep(0.55, 1.0, d / radius));
	ALBEDO = ring_color.rgb;
	ALPHA = clamp(edge * mix(0.35, 0.95, dash) + fill, 0.0, 1.0);
}
