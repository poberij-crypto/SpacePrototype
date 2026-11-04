shader_type sky;
void sky() {
 float h = max(EYEDIR.y,0.0);
 vec3 horizon = vec3(0.66,0.74,0.78);
 vec3 zenith = vec3(0.12,0.30,0.49);
 vec3 color = mix(horizon,zenith,pow(h,0.55));
 float sun = pow(max(dot(EYEDIR,normalize(vec3(-0.4,0.65,-0.6))),0.0),600.0);
 float haze = pow(max(dot(EYEDIR,normalize(vec3(-0.4,0.65,-0.6))),0.0),12.0);
 COLOR = color + vec3(1.0,0.82,0.59)*sun*3.0 + vec3(0.15,0.10,0.04)*haze;
}
