shader_type sky;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float stars(vec2 uv,float grid) {
 vec2 p=uv*grid, cell=floor(p), local=fract(p);
 vec2 center=vec2(hash(cell+1.7),hash(cell+8.3))*0.6+0.2;
 float d=length(local-center);
 return (1.0-smoothstep(0.015,0.07,d))*step(0.972,hash(cell))* (0.4+hash(cell+3.2));
}
void sky() {
 vec2 uv=vec2(atan(EYEDIR.z,EYEDIR.x)/6.283185+0.5,asin(clamp(EYEDIR.y,-1.0,1.0))/3.141593+0.5);
 float n=noise(uv*8.0)*0.5+noise(uv*21.0)*0.3+noise(uv*52.0)*0.2;
 float band=exp(-pow((uv.y-0.50+sin(uv.x*9.0)*0.15)*6.0,2.0));
 vec3 cloud=mix(vec3(0.025,0.055,0.10),vec3(0.10,0.035,0.12),noise(uv*5.0));
 vec3 base=vec3(0.001,0.003,0.009)+cloud*band*pow(n,2.0)*2.2;
 COLOR=base+vec3(0.72,0.85,1.0)*stars(uv,480.0)+vec3(1.0,0.86,0.68)*stars(uv,210.0)*0.7;
}
