shader_type spatial;
render_mode cull_back;
// Painted starship plating: riveted panels, two paint bands and a soft sheen.
#include "toon_light.gdshaderinc"

uniform vec4 base : source_color = vec4(0.9, 0.91, 0.95, 1.0);
uniform vec4 paint : source_color = vec4(0.92, 0.27, 0.22, 1.0);
uniform float band_lo = 1.55;
uniform float band_hi = 4.55;
uniform float patched = 0.0;   // 1 = rusty wreck with mismatched plates

varying vec3 local_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float around = atan(local_pos.x, local_pos.z) / 6.28318 * 12.0;
	float up = local_pos.y / 0.72;
	vec2 cell = vec2(floor(around + 0.5 * mod(floor(up), 2.0)), floor(up));
	vec2 f = vec2(fract(around + 0.5 * mod(floor(up), 2.0)), fract(up));
	vec3 col = base.rgb * (0.95 + 0.08 * hash(cell));
	float seam = max(1.0 - smoothstep(0.0, 0.035, min(f.x, 1.0 - f.x)), 1.0 - smoothstep(0.0, 0.045, min(f.y, 1.0 - f.y)));
	col = mix(col, col * 0.68, seam);
	// Rivets just inside each seam.
	vec2 r = vec2(fract(f.x * 4.0) - 0.5, (min(f.y, 1.0 - f.y) - 0.11) * 4.0);
	col = mix(col, vec3(0.45, 0.47, 0.52), 1.0 - smoothstep(0.12, 0.18, length(r)));
	// Paint bands with a thin pinstripe.
	float d1 = abs(local_pos.y - band_lo);
	float d2 = abs(local_pos.y - band_hi);
	float band = max(1.0 - step(0.27, d1), 1.0 - step(0.13, d2));
	float pin = max(1.0 - step(0.035, abs(d1 - 0.37)), 1.0 - step(0.03, abs(d2 - 0.22)));
	col = mix(col, paint.rgb * (0.92 + 0.1 * hash(cell)), max(band, pin));
	if (patched > 0.0) {
		float rust = step(0.72, hash(cell + 7.0));
		col = mix(col, vec3(0.5, 0.3, 0.18) * (0.7 + 0.5 * hash(floor(f * 7.0) + cell)), rust * patched);
		col *= 1.0 - 0.22 * patched;
	}
	ALBEDO = col;
	ROUGHNESS = 0.55;
	EMISSION = col * 0.04;
}
