shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
void fragment(){
 float rim=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
 ALBEDO=vec3(0.08,0.32,0.8);ALPHA=rim*0.48;
}
