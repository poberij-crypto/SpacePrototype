shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 star_color : source_color = vec4(1.0, 0.65, 0.24, 1.0);
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	ALBEDO = star_color.rgb;
	ALPHA = rim * 0.22;
}
