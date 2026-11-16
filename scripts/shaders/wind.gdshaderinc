// Wind sway: tops of trees and grass move, bases stay put.
uniform float wind = 0.0;

vec3 apply_wind(vec3 v, mat4 model, float time) {
	if (wind <= 0.0) {
		return v;
	}
	vec3 origin = model[3].xyz;
	float h = max(v.y, 0.0);
	float phase = time * 1.6 + origin.x * 0.35 + origin.z * 0.27;
	float gust = 0.6 + 0.4 * sin(time * 0.37 + origin.x * 0.05);
	v.x += sin(phase) * wind * h * h * gust;
	v.z += cos(phase * 0.8) * wind * 0.5 * h * h * gust;
	return v;
}
