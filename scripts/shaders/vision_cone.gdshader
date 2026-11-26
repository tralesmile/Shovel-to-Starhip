shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Floor fan showing what a resident can see. UV.x = angle across the cone (0..1),
// UV.y = distance from the eyes as a share of full sight range.
uniform vec4 tint : source_color = vec4(0.35, 0.95, 0.55, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float alert : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float edge = smoothstep(0.96, 1.0, abs(UV.x - 0.5) * 2.0);
	float ring = smoothstep(0.82, 1.0, fract(UV.y * 5.0 - TIME * (0.35 + alert * 1.6)));
	float fill = mix(0.34, 0.12, clamp(UV.y * 1.4, 0.0, 1.0));
	// The suspicion "charge" floods outward from the eyes.
	float charge = step(UV.y, alert * 0.75) * 0.28;
	ALBEDO = tint.rgb;
	ALPHA = clamp(fill + ring * 0.2 + edge * 0.45 + charge, 0.0, 0.8) * strength;
}
