// Amazonia
// Paste into https://twigl.app  →  mode: "classic"
precision highp float;
uniform vec2 u_resolution;
uniform float u_time;

#define T (u_time*0.35)

float g_sun, g_fog;
vec3 g_ld;

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
    for(int i=0;i<5;i++){
        v += a*n2(p);
        p = mat2(1.6,1.2,-1.2,1.6)*p;
        a *= 0.5;
    }
    return v;
}

// ---- río de la selva --------------------------------------------------
float river(vec2 p){
    float h = 0.0, a = 1.0;
    vec2 q = p*0.08;
    // curvas del río
    q.x += sin(q.y*0.5)*3.0;
    for(int i=0;i<3;i++){
        float w = n2(q + vec2(T*0.4, T*0.2));
        h += w*a;
        q = mat2(1.5,1.0,-1.0,1.5)*q;
        a *= 0.5;
    }
    return h*0.8 - 1.5;
}

// ---- vegetación tropical -----------------------------------------------
float sdCylinder(vec3 p, float r, float h){
    return max(length(p.xz)-r, abs(p.y)-h);
}
float sdCapsule(vec3 p, vec3 a, vec3 b, float r){
    vec3 pa = p-a, ba = b-a;
    float h = clamp(dot(pa,ba)/dot(ba,ba), 0.0, 1.0);
    return length(pa - ba*h) - r;
}
float tree(vec3 p, float seed){
    float h = 8.0 + seed*6.0;
    float w = 0.4 + seed*0.3;
    // tronco torcido
    float twist = sin(p.y*0.3 + seed*10.0)*0.3;
    vec3 tp = vec3(p.x - twist, p.y, p.z);
    float trunk = sdCylinder(tp, w*0.6, h*0.5);
    // raíces aéreas
    float roots = sdCylinder(tp - vec3(w*0.8, 0.0, 0.0), w*0.3, h*0.3);
    roots = min(roots, sdCylinder(tp - vec3(-w*0.8, 0.0, 0.0), w*0.3, h*0.3));
    float d = min(trunk, roots);
    // copa del árbol (esferas para follaje)
    float canopy = length(tp - vec3(0.0, h, 0.0)) - (2.0 + seed);
    canopy = min(canopy, length(tp - vec3(1.5, h-0.5, 0.0)) - 1.5);
    canopy = min(canopy, length(tp - vec3(-1.2, h-0.3, 1.0)) - 1.3);
    d = min(d, canopy);
    return d;
}
float liana(vec3 p, vec3 a, vec3 b, float r){
    // liana ondulante
    vec3 pa = p-a, ba = b-a;
    float h = clamp(dot(pa,ba)/dot(ba,ba), 0.0, 1.0);
    vec3 closest = a + ba*h;
    float wave = sin(h*8.0 + T)*0.15;
    float d = length(p.xz - closest.xz - vec2(wave, 0.0)) - r;
    return max(d, abs(p.y - closest.y) - length(ba)*0.5);
}
float vegetation(vec3 p){
    float s = 12.0;
    vec2 id = floor(p.xz/s);
    vec2 q = p.xz - (id+0.5)*s;
    q += (vec2(hash(id+7.0), hash(id+23.0))-0.5)*4.0;
    float seed = hash(id);
    // árbol principal
    float d = tree(vec3(q.x, p.y, q.y), seed);
    // lianas colgantes
    vec3 start = vec3(q.x, 6.0 + seed*4.0, q.y);
    vec3 end = start + vec3(sin(seed*10.0)*2.0, -4.0 - seed*3.0, cos(seed*10.0)*2.0);
    float li = liana(p, start, end, 0.08);
    d = min(d, li);
    // helechos en el suelo
    float fern = length(p - vec3(q.x, 0.5, q.y)) - (0.8 + seed*0.5);
    fern = max(fern, abs(p.y - 0.5) - 0.3);
    d = min(d, fern);
    return d;
}
// troncos caídos en el río
float fallenLogs(vec3 p){
    vec3 q = vec3(mod(p.x, 25.0) - 12.5, p.y, p.z);
    float logD = sdCylinder(q - vec3(0.0, 0.3, 0.0), 0.4, 8.0);
    logD = min(logD, sdCylinder(q - vec3(5.0, 0.2, 2.0), 0.35, 6.0));
    return logD;
}

vec2 map(vec3 p){
    float dw = (p.y - river(p.xz))*0.5;
    float dv = min(vegetation(p), fallenLogs(p))*0.8;
    return dw < dv ? vec2(dw, 1.0) : vec2(dv, 2.0);
}
vec3 norm(vec3 p){
    vec2 e = vec2(0.012, -0.012);
    return normalize(e.xyy*map(p+e.xyy).x + e.yyx*map(p+e.yyx).x +
                     e.yxy*map(p+e.yxy).x + e.xxx*map(p+e.xxx).x);
}
vec2 march(vec3 ro, vec3 rd){
    float t = 0.0, m = -1.0;
    for(int i=0;i<90;i++){
        vec2 h = map(ro + rd*t);
        if(h.x < 0.0025*t + 0.001){ m = h.y; break; }
        t += h.x*0.9;
        if(t > 100.0) break;
    }
    if(t > 100.0) m = -1.0;
    return vec2(t, m);
}
vec2 marchR(vec3 ro, vec3 rd){
    float t = 0.0, m = -1.0;
    for(int i=0;i<40;i++){
        vec2 h = map(ro + rd*t);
        if(h.x < 0.004*t + 0.002){ m = h.y; break; }
        t += h.x*0.95;
        if(t > 50.0) break;
    }
    if(t > 50.0) m = -1.0;
    return vec2(t, m);
}

// ---- cielo amazónico --------------------------------------------------
vec3 skyColor(vec3 rd){
    float y = max(rd.y, 0.0);
    // azul tropical brillante
    vec3 col = mix(vec3(0.2, 0.5, 0.9), vec3(0.6, 0.85, 1.0), pow(y, 0.5));
    // nubes de tormenta tropical
    vec2 cuv = rd.xz/max(rd.y*0.6+0.2, 0.1);
    float cm = smoothstep(0.3, 0.95, fbm(cuv*0.6+vec2(T*0.8, T*0.4))*0.7
                                    + fbm(cuv*1.8-vec2(T*1.5, T*0.6))*0.5);
    col = mix(col, vec3(0.9, 0.95, 1.0), cm*0.4);
    // sol tropical intenso
    float sun = pow(max(dot(rd, g_ld), 0.0), 8.0);
    col += vec3(1.0, 0.9, 0.6)*sun*g_sun;
    return col;
}

// ---- shading de vegetación --------------------------------------------
vec3 jungleColor(vec3 p, vec3 n, vec3 rd){
    float tx = n2(p.xz*4.0 + vec2(p.y*3.0, 0.0));
    // verdes de la selva: desde musgo oscuro hasta hojas brillantes
    vec3 darkGreen = vec3(0.05, 0.25, 0.08);
    vec3 leafGreen = vec3(0.15, 0.55, 0.12);
    vec3 lightGreen = vec3(0.35, 0.75, 0.25);
    vec3 col = mix(darkGreen, leafGreen, tx);
    col = mix(col, lightGreen, n2(p.xy*3.0)*0.5);

    // madera del tronco
    float isTrunk = step(abs(n.y), 0.3);
    vec3 wood = vec3(0.25, 0.15, 0.08) * (0.7 + 0.4*tx);
    col = mix(col, wood, isTrunk);

    float dif = clamp(dot(n, g_ld), 0.0, 1.0);
    float amb = clamp(0.3 + 0.4*n.y, 0.0, 1.0);

    // luz filtrada por el dosel (dappled light)
    float canopy = n2(p.xz*8.0)*n2(p.xz*15.0 + T);
    float dapple = smoothstep(0.4, 0.7, canopy);

    col = col*(vec3(0.8, 0.9, 0.6)*dif*dapple + vec3(0.1, 0.15, 0.08)*amb + 0.08);
    // musgo húmedo brillante
    col += vec3(0.1, 0.3, 0.15)*step(0.6, tx)*dif*0.5;

    return col;
}

vec3 aces(vec3 x){
    return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14), 0.0, 1.0);
}

void main(){
    vec2 res = u_resolution;
    vec2 uv = (gl_FragCoord.xy*2.0 - res)/min(res.x, res.y);

    // sol tropical brillante
    g_sun = 1.2;
    g_ld = normalize(vec3(0.4, 0.85, 0.3));
    g_fog = 0.0;

    // cámara: navegando por el río en bote
    vec3 ro = vec3(0.6*sin(T*0.4), 1.2 + 0.15*sin(u_time*0.5), T*6.0);
    float yaw = 0.15*sin(u_time*0.08);
    vec3 ww = normalize(vec3(sin(yaw), -0.08, cos(yaw)));
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = cross(uu, ww);
    vec3 rd = normalize(uv.x*uu + uv.y*vv + 1.6*ww);

    vec2 hit = march(ro, rd);
    vec3 col;
    if(hit.y < 0.0){
        col = skyColor(rd);
    } else {
        vec3 p = ro + rd*hit.x;
        vec3 n = norm(p);
        if(hit.y < 1.5){
            // ---- agua del río ----
            vec2 dq = p.xz*3.0 - vec2(T*1.2, T*0.8);
            float h0 = n2(dq);
            n = normalize(n + vec3(-(n2(dq+vec2(0.05,0.0))-h0), 0.0,
                                   -(n2(dq+vec2(0.0,0.05))-h0))*1.5);
            vec3 rr = normalize(reflect(rd, n));
            float fre = pow(1.0 - max(dot(n,-rd), 0.0), 4.0);

            // color del río: café-sedimentoso a verde
            vec3 base = vec3(0.08, 0.15, 0.12) + vec3(0.05, 0.1, 0.08)*smoothstep(-1.0, 1.5, p.y);
            // reflejo del cielo y vegetación
            vec3 rcol;
            vec2 rh = marchR(p + n*0.06, rr);
            if(rh.y > 1.5){
                vec3 rp = p + n*0.06 + rr*rh.x;
                rcol = jungleColor(rp, norm(rp), rr);
                rcol = mix(rcol, skyColor(rr), 1.0 - exp(-rh.x*rh.x*0.001));
            } else {
                rcol = skyColor(rr);
            }
            col = mix(base, rcol, 0.35 + 0.55*fre);
            // brillo del sol en el agua
            col += vec3(0.8, 0.9, 0.6)*pow(max(dot(rr, g_ld), 0.0), 60.0)*0.8;
        } else {
            col = jungleColor(p, n, rd);
        }
        // niebla de la selva (humedad)
        float fog = 1.0 - exp(-hit.x*hit.x*0.00015);
        col = mix(col, vec3(0.4, 0.6, 0.5)*0.8, fog*0.6);
    }

    // partículas: polen, insectos, motas de luz
    vec2 sc = gl_FragCoord.xy/res;
    float part1 = n2(vec2(sc.x*150.0 + sc.y*30.0 + u_time*0.5, sc.y*8.0 + u_time*5.0));
    float part2 = n2(vec2(sc.x*250.0 - sc.y*50.0, sc.y*12.0 + u_time*8.0));
    col += (smoothstep(0.75,0.98,part1)*0.12 + smoothstep(0.80,0.99,part2)*0.06)
         * vec3(0.9, 1.0, 0.7);

    // post-procesado: vibrante y húmedo
    col *= vec3(0.95, 1.05, 0.9);
    col *= 1.0 - 0.25*dot(uv*0.5, uv*0.5);
    col = aces(col*1.15);
    col = pow(max(col, vec3(0.0)), vec3(0.4545));
    // grano de película tropical
    col += (hash(gl_FragCoord.xy + fract(u_time)*vec2(11.0,7.0)) - 0.5)*0.025;
    gl_FragColor = vec4(col, 1.0);
}
