// Shared cartoon lighting: two crisp tones from the sun, a soft highlight band,
// a rim light, and smooth-edged pools for lamps at night.

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = smoothstep(-0.02, 0.08, ndl) * smoothstep(0.25, 0.6, ATTENUATION);
		float band = smoothstep(0.55, 0.62, ndl) * 0.12;
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * lit * 0.35;
		DIFFUSE_LIGHT += LIGHT_COLOR * (lit * (0.88 + band) + rim) / PI;
	} else {
		float a = clamp(ndl, 0.0, 1.0) * ATTENUATION;
		DIFFUSE_LIGHT += LIGHT_COLOR * smoothstep(0.01, 0.2, a) / PI;
	}
}
