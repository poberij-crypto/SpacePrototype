shader_type spatial;
render_mode unshaded;
uniform vec4 star_color : source_color = vec4(1.0, 0.78, 0.4, 1.0);
varying vec3 surface_point;
void vertex() {
	surface_point = normalize(VERTEX);
}
void fragment() {
	float cells = sin(surface_point.x * 58.0 + sin(surface_point.z * 41.0) * 2.0 + TIME * 0.16);
	cells *= sin(surface_point.y * 63.0 + surface_point.z * 17.0 - TIME * 0.1);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float limb = 0.55 + 0.45 * sqrt(facing);
	vec3 color = mix(star_color.rgb, vec3(1.0, 0.98, 0.84), 0.48 + cells * 0.11);
	ALBEDO = color * limb;
	EMISSION = color * (0.6 + cells * 0.08);
}
