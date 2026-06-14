// Arrecife Tropical
// Paste into https://twigl.app  →  mode: "classic"
precision highp float;
uniform vec2 u_resolution;
uniform float u_time;
#define T (u_time * 0.5)
float hash(vec2 p){
    p = fract(p*vec2(123.34, 345.45));
    p += dot(p, p+34.345);
    return fract(p.x*p.y);
}
float n2(vec2 p){
    vec2 i = floor(p), f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i), hash(i+vec2(1.0,0.0)), f.x),
               mix(hash(i+vec2(0.0,1.0)), hash(i+vec2(1.0,1.0)), f.y), f.y);
}
float fbm(vec2 p){
    float v = 0.0, a = 0.5;
    for(int i=0;i<4;i++){
        v += a*n2(p);
        p = mat2(1.6,1.2,-1.2,1.6)*p;
        a *= 0.5;
    }
    return v;
}
// ---- Geometría del Pez -------------------------------------------------
float sdFish(vec3 p, float seed){
    float swim = sin(T * 4.0 + seed * 10.0) * 0.3;
    vec3 pBody = p;
    pBody.x += swim * (p.z + 0.5);
    float body = length(pBody * vec3(1.0, 1.5, 0.6)) - 0.4;
    vec3 pTail = p;
    pTail.x += swim * 1.5;
    float tail = length(vec3(pTail.x, pTail.y, abs(pTail.z + 0.8))) - 0.2;
    tail = max(tail, -pTail.z - 0.4);
    return min(body, tail);
}
float scene(vec3 p){
    float floorDist = p.y + 2.0 + fbm(p.xz * 0.1) * 0.5;
    float fishDist = 100.0;
    float s = 6.0;
    vec3 q = vec3(mod(p.x + s*0.5, s) - s*0.5,
                  mod(p.y + s*0.5, s) - s*0.5,
                  mod(p.z - T * 3.0 + s*0.5, s) - s*0.5);

    // Separamos el floor del hash
    vec2 gridId = floor(p.xz / s);
    float seed = hash(gridId);

    vec3 offset = vec3(sin(seed*10.0), cos(seed*5.0), 0.0) * 2.0;
    fishDist = sdFish(q - offset, seed);

    return min(floorDist, fishDist);
}
vec3 norm(vec3 p){
    vec2 e = vec2(0.01, 0.0);
    return normalize(vec3(
        scene(p+e.xyy) - scene(p-e.xyy),
        scene(p+e.yxy) - scene(p-e.yxy),
        scene(p+e.yyx) - scene(p-e.yyx)
    ));
}
vec2 march(vec3 ro, vec3 rd){
    float t = 0.0;
    for(int i=0;i<80;i++){
        float h = scene(ro + rd*t);
        if(h < 0.001 * t + 0.001) return vec2(t, 1.0);
        t += h;
        if(t > 40.0) break;
    }
    return vec2(t, -1.0);
}
float getCaustics(vec3 p){
    vec2 uv = p.xz * 0.2;
    float c = fbm(uv + T) + fbm(uv * 1.5 - T * 0.8);
    return smoothstep(0.6, 0.8, c);
}
vec3 aces(vec3 x){
    return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14), 0.0, 1.0);
}
void main(){
    vec2 res = u_resolution;
    vec2 uv = (gl_FragCoord.xy*2.0 - res)/min(res.x, res.y);
    vec3 ro = vec3(sin(T*0.2)*2.0, 1.0 + sin(T*0.3)*0.5, T*2.0);
    vec3 target = vec3(sin(T*0.2)*2.0, 1.0, T*2.0 + 5.0);
    vec3 ww = normalize(target - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = cross(uu, ww);
    vec3 rd = normalize(uv.x*uu + uv.y*vv + 2.0*ww);
    vec2 hit = march(ro, rd);
    vec3 col;
    if(hit.y < 0.0){
        col = mix(vec3(0.0, 0.4, 0.7), vec3(0.4, 0.8, 1.0), max(0.0, rd.y));
    } else {
        vec3 p = ro + rd*hit.x;
        vec3 n = norm(p);
        float distFloor = p.y + 2.0;

        if(distFloor < 1.0){
            vec3 sand = vec3(0.7, 0.6, 0.4);
            float caustics = getCaustics(p);
            col = sand + caustics * 0.4;
        } else {
            vec3 fishCol = vec3(1.0, 0.5, 0.1);
            float diff = clamp(dot(n, normalize(vec3(1,2,1))), 0.0, 1.0);
            col = fishCol * (diff + 0.3);
            col += pow(max(0.0, n.y), 10.0) * vec3(1.0, 1.0, 0.8);
        }
        float fog = 1.0 - exp(-hit.x * 0.12);
        col = mix(col, vec3(0.1, 0.6, 0.8), fog);
    }
    float rays = fbm(rd.xz * 0.5 + T * 0.1) * max(0.0, rd.y);
    col += rays * vec3(0.7, 0.9, 1.0) * 0.5;
    col = aces(col * 1.2);
    col = pow(max(col, vec3(0.0)), vec3(0.4545));
    col *= 1.0 - 0.3 * dot(uv, uv);

    gl_FragColor = vec4(col, 1.0);
}
