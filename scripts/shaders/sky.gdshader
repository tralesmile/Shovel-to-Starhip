shader_type sky;
// Day / sunset / night sky with a sun, a moon and twinkling stars.

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float day = 1.0;
uniform float sunset = 0.0;
uniform float night = 0.0;

uniform vec3 day_top : source_color = vec3(0.30, 0.55, 0.92);
uniform vec3 day_horizon : source_color = vec3(0.72, 0.84, 0.95);
uniform vec3 sunset_top : source_color = vec3(0.36, 0.34, 0.62);
uniform vec3 sunset_horizon : source_color = vec3(1.0, 0.55, 0.38);
uniform vec3 night_top : source_color = vec3(0.02, 0.03, 0.10);
uniform vec3 night_horizon : source_color = vec3(0.08, 0.10, 0.22);
uniform vec3 ground : source_color = vec3(0.22, 0.32, 0.22);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = EYEDIR;
	float w = max(day + sunset + night, 0.001);
	vec3 top = (day_top * day + sunset_top * sunset + night_top * night) / w;
	vec3 hor = (day_horizon * day + sunset_horizon * sunset + night_horizon * night) / w;
	float h = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(hor, top, pow(h, 0.55));
	float sd = dot(d, normalize(sun_dir));
	// Warm glow around the sun at sunrise/sunset.
	col += vec3(1.0, 0.45, 0.2) * pow(max(sd, 0.0), 6.0) * sunset * 0.7;
	// Sun disc + halo.
	float sun = smoothstep(0.9990, 0.9994, sd);
	col = mix(col, vec3(1.0, 0.95, 0.8), sun * (1.0 - night));
	col += vec3(1.0, 0.9, 0.7) * pow(max(sd, 0.0), 120.0) * 0.4 * (1.0 - night);
	// Moon opposite the sun.
	float md = dot(d, -normalize(sun_dir));
	float moon = smoothstep(0.9988, 0.9992, md);
	col = mix(col, vec3(0.92, 0.94, 1.0), moon * night);
	col += vec3(0.6, 0.7, 1.0) * pow(max(md, 0.0), 200.0) * 0.3 * night;
	// Stars.
	vec3 cell = floor(d * 220.0);
	float s = hash(cell);
	float star = step(0.9965, s) * (0.6 + 0.4 * sin(TIME * 2.0 + s * 100.0));
	col += vec3(star) * night * smoothstep(0.02, 0.2, d.y);
	// Below the horizon fade to a dark ground colour (hidden by terrain anyway).
	col = mix(col, ground * (0.3 + 0.7 * (1.0 - night)), smoothstep(0.0, -0.08, d.y));
	COLOR = col;
}
