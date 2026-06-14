// Cristales Etéreos
// Paste into https://twigl.app  →  mode: "classic"
precision highp float;
uniform vec2 u_resolution;
uniform float u_time;

#define T (u_time*0.2)

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

// ---- Geometría de Cristal ----------------------------------------------
float sdBox(vec3 p, vec3 b){
    vec3 q = abs(p) - b;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float crystal(vec3 p, float seed){
    // Rotación aleatoria basada en semilla
    float a = seed * 6.28;
    mat2 rot = mat2(cos(a), -sin(a), sin(a), cos(a));
    p.xz *= rot;
    p.xy *= rot;

    // Estiramiento para crear forma de prisma
    vec3 s = vec3(0.2, 1.2 + seed, 0.2);
    float d = sdBox(p, s);

    // Añadir facetas adicionales
    float facets = sdBox(p * 1.5, s * 0.5);
    return min(d, facets);
}

float scene(vec3 p){
    // Suelo y techo infinitos con ruido
    float ground = p.y + 2.0 + fbm(p.xz * 0.1) * 0.5;
    float ceiling = -p.y + 2.0 + fbm(p.xz * 0.1 + 10.0) * 0.5;
    float cave = max(ground, ceiling);

    // Repetición de cristales en el espacio
    float s = 6.0;
    vec3 q = vec3(mod(p.x+s*0.5, s)-s*0.5, p.y, mod(p.z+s*0.5, s)-s*0.5);

    float seed = hash(floor(p.xz/s));
    float crys = crystal(q - vec3(0.0, sin(T + seed*10.0)*1.0, 0.0), seed);

    return min(cave, crys);
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

// ---- Color e Iridiscencia ---------------------------------------------
vec3 palette(float t){
    // Paleta: Oro, Amatista, Diamante
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.263, 0.416, 0.557);
    return a + b*cos(6.28318*(c*t+d));
}

vec3 iridescent(vec3 n, vec3 rd){
    float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
    float angle = atan(n.x, n.z);
    return mix(vec3(0.8, 0.9, 1.0), palette(angle + T), fresnel);
}

vec3 aces(vec3 x){
    return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14), 0.0, 1.0);
}

void main(){
    vec2 res = u_resolution;
    vec2 uv = (gl_FragCoord.xy*2.0 - res)/min(res.x, res.y);

    // Cámara: Vuelo etéreo
    vec3 ro = vec3(sin(T*0.3)*3.0, 0.0, T*2.0);
    vec3 target = vec3(sin(T*0.3)*3.0, 0.0, T*2.0 + 5.0);
    vec3 ww = normalize(target - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = cross(uu, ww);
    vec3 rd = normalize(uv.x*uu + uv.y*vv + 2.0*ww);

    vec2 hit = march(ro, rd);
    vec3 col;

    if(hit.y < 0.0){
        // Fondo astral
        float sky = fbm(rd.xz * 0.5 + T*0.1);
        col = mix(vec3(0.02, 0.02, 0.05), vec3(0.1, 0.1, 0.2), sky);
        col += pow(max(0.0, rd.y), 2.0) * vec3(0.1, 0.2, 0.3);
    } else {
        vec3 p = ro + rd*hit.x;
        vec3 n = norm(p);

        // Material cristalino
        vec3 baseCol = iridescent(n, rd);
        float dif = clamp(dot(n, normalize(vec3(1,2,1))), 0.0, 1.0);
        float spec = pow(max(0.0, dot(reflect(rd, n), normalize(vec3(1,2,1)))), 32.0);

        col = baseCol * (dif + 0.2) + spec * 0.8;

        // Niebla etérea
        float fog = 1.0 - exp(-hit.x * 0.15);
        col = mix(col, vec3(0.05, 0.05, 0.1), fog);
    }

    // Partículas de polvo estelar
    vec2 sc = gl_FragCoord.xy/res;
    float p1 = n2(vec2(sc.x*120.0 + T, sc.y*120.0 - T));
    col += smoothstep(0.99, 1.0, p1) * vec3(1.0, 0.9, 0.7) * 0.4;

    // Post-procesado
    col = aces(col * 1.3);
    col = pow(max(col, vec3(0.0)), vec3(0.4545));
    col *= 1.0 - 0.3 * dot(uv, uv); // Viñeta

    gl_FragColor = vec4(col, 1.0);
}
