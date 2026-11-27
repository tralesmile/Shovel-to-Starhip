shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
// Rocket exhaust on a cone: scrolling noise tongues, white-hot core fading to orange.

uniform vec4 core : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.38, 0.06, 1.0);
uniform float power = 1.0;

varying float along;   // 0 at the nozzle, 1 at the tip
varying vec3 local_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	along = clamp(0.5 - VERTEX.y, 0.0, 1.0);   // the mesh is 1 unit tall, nozzle at +0.5
	float a = atan(VERTEX.x, VERTEX.z);
	float wob = vnoise(vec2(a * 3.0, along * 6.0 - TIME * 14.0)) - 0.5;
	VERTEX.xz *= 1.0 + wob * 0.5 * along;
	local_pos = VERTEX;
}

void fragment() {
	float a = atan(local_pos.x, local_pos.z);
	float n = vnoise(vec2(a * 4.0, along * 7.0 - TIME * 18.0));
	float body = smoothstep(1.0, 0.25, along + (n - 0.5) * 0.55);
	float facing = abs(dot(NORMAL, VIEW));
	vec3 col = mix(edge.rgb, core.rgb, smoothstep(0.55, 0.0, along) * facing);
	ALBEDO = col * (0.75 + 0.55 * n);
	ALPHA = body * (0.35 + 0.65 * facing) * clamp(power, 0.0, 1.0);
}
