shader_type spatial;
render_mode diffuse_burley;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p){
 vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
varying vec3 sphere_pos;
void vertex(){sphere_pos=normalize(VERTEX);}
uniform int planet_kind = 0;
uniform vec4 palette : source_color = vec4(1.0);

void fragment(){
 vec3 p=sphere_pos;
 float continent=noise(p*3.0)+noise(p*9.0)*0.25+noise(p*21.0)*0.08;
 float land=smoothstep(0.67,0.71,continent);
 vec3 water=mix(vec3(0.014,0.055,0.13),vec3(0.02,0.18,0.25),smoothstep(0.63,0.75,continent));
 vec3 ground=mix(vec3(0.08,0.17,0.12),vec3(0.27,0.26,0.17),noise(p*16.0));
 vec3 surface=mix(water,ground,land);
 float ice=smoothstep(0.81,0.96,abs(p.y)+noise(p*12.0)*0.12);
 surface=mix(surface,vec3(0.72,0.80,0.85),ice);
 float cloud=smoothstep(0.67,0.79,noise(p*8.0+vec3(0.2,0.4,0.6))*0.7+noise(p*24.0)*0.3);
 if (planet_kind == 1) {
  float stone = noise(p * 12.0) * 0.65 + noise(p * 38.0) * 0.35;
  surface = mix(vec3(0.16,0.13,0.12), vec3(0.65,0.48,0.32), stone);
 } else if (planet_kind == 2) {
  float bands = sin(p.y * 44.0 + noise(p * 8.0) * 3.2) * 0.5 + 0.5;
  surface = mix(vec3(0.24,0.19,0.16),vec3(0.86,0.72,0.47),bands);
 }
 ALBEDO=palette.rgb*(planet_kind == 0 ? mix(surface,vec3(0.55,0.64,0.73),cloud*0.75) : surface);
 ROUGHNESS=0.65;SPECULAR=0.35;
}
