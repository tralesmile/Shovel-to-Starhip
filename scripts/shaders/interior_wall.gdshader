shader_type spatial;
render_mode cull_back;

// Wallpaper with soft stripes and polka dots above a wooden wainscot. World-space
// so every wall segment lines up without UVs.
uniform vec4 paper : source_color = vec4(0.85, 0.9, 0.95, 1.0);
uniform vec4 wood : source_color = vec4(0.45, 0.3, 0.18, 1.0);
uniform float floor_y = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	float along = abs(wnorm.x) > 0.5 ? wpos.z : wpos.x;
	float h = wpos.y - floor_y;
	float stripe = step(0.5, fract(along * 1.6));
	vec3 col = paper.rgb * mix(0.9, 1.0, stripe);
	vec2 cell = fract(vec2(along * 1.6 + 0.25, h * 1.8)) - 0.5;
	col = mix(col, paper.rgb * 0.72, (1.0 - smoothstep(0.07, 0.1, length(cell))) * stripe);
	if (h < 0.95) {
		float plank = fract(along * 2.4);
		float seam = smoothstep(0.0, 0.05, plank) * smoothstep(1.0, 0.95, plank);
		col = wood.rgb * mix(0.65, 1.0, seam);
		if (h < 0.12) col = wood.rgb * 0.55;
	}
	if (h > 0.95 && h < 1.04) col = wood.rgb * 1.25;
	// Darken into the corners near floor and ceiling for a little depth.
	col *= mix(0.78, 1.0, smoothstep(0.0, 0.5, h)) * mix(0.8, 1.0, smoothstep(0.0, 0.6, 3.2 - h));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
