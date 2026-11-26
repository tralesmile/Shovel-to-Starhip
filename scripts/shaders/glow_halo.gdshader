// Soft additive billboard halo (fireflies and the Firefly Jar). Cheap: one quad, no light.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(0.85, 1.0, 0.35, 1.0);
uniform float strength = 1.0;

void vertex() {
	// Face the camera, keeping the node's scale.
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(sx, 0.0, 0.0, 0.0), vec4(0.0, sy, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float soft = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	float core = smoothstep(0.22, 0.0, d);
	ALBEDO = glow_color.rgb * (soft + core) * strength;
	ALPHA = clamp((soft + core) * strength, 0.0, 1.0);
}
