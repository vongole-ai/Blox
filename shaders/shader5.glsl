// Cristal Nebuloso
// Paste into https://twigl.app  →  mode: "classic"
precision highp float;
uniform vec2 u_resolution;
uniform float u_time;

#define PI 3.14159265359
#define MAX_STEPS 80
#define T (u_time * 0.4)

float lenVal(vec2 v) { return sqrt(v.x*v.x + v.y*v.y); }
float lenVal(vec3 v) { return sqrt(v.x*v.x + v.y*v.y + v.z*v.z); }
float modD(float x, float y) { return x - y * floor(x / y); }
float mixD(float a, float b, float t) { return a + (b - a) * t; }

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n2(vec2 p) {
    float res = 0.0; float amp = 0.5;
    vec2 shift = vec2(100.0);
    for(int i=0; i<4; i++) {
        res += amp * fract(sin(dot(p + shift, vec2(12.9898, 78.233))) * 43758.5453);
        p *= 2.0; shift *= 2.0; amp *= 0.5;
    }
    return res;
}
float fbm(vec2 p) {
    float res = 0.0; float amp = 0.5;
    for(int i=0; i<4; i++) {
        res += amp * n2(p);
        p *= 2.0; amp *= 0.5;
    }
    return res;
}

float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(lenVal(p.xz) - t.x, p.y);
    return lenVal(q) - t.y;
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return lenVal(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float map(vec3 p) {
    // Deformación orgánica del toro principal basada en ruido
    float deform = n2(p.xy * 1.5 + T * 0.1) * 0.4;
    float d = sdTorus(p, vec2(2.0 + deform, 0.6));

    // Elementos orbitales simples
    vec3 p2 = p;
    p2.yz *= mat2(cos(T*0.5), -sin(T*0.5), sin(T*0.5), cos(T*0.5));
    d = min(d, sdBox(p2, vec3(0.2)));

    // Cáscara externa (efecto de cristal)
    float shell = sdTorus(p + vec3(sin(T*0.2)*0.2, 0.0, cos(T*0.2)*0.2), vec2(2.8, 1.2));
    d = mixD(d, shell, 0.3);

    return d;
}

vec3 aces(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    // Cámara en órbita
    float camAngle = T * 0.3;
    vec3 ro = vec3(cos(camAngle) * 6.0, 2.0 + sin(T * 0.5) * 0.5, sin(camAngle) * 6.0);
    vec3 lookAt = vec3(0.0, 0.0, 0.0);
    vec3 f = normalize(lookAt - ro);
    vec3 r = normalize(cross(vec3(0.0, 1.0, 0.0), f));
    vec3 u = cross(f, r);
    vec3 rd = normalize(f + uv.x * r + uv.y * u);

    vec3 p = ro;
    float t = 0.0;
    float d = 0.0;
    bool hit = false;

    for(int i=0; i<MAX_STEPS; i++) {
        p = ro + rd * t;
        d = map(p);
        if(d < 0.001) { hit = true; break; }
        t += d;
        if(t > 20.0) break;
    }

    vec3 col = vec3(0.0);

    if(hit) {
        // Normales por diferencias finitas
        vec2 e = vec2(0.001, 0.0);
        vec3 n = normalize(vec3(
            map(p+e.xyy) - map(p-e.xyy),
            map(p+e.yxy) - map(p-e.yxy),
            map(p+e.yyx) - map(p-e.yyx)
        ));

        // Iluminación
        vec3 lightDir = normalize(vec3(5.0, 8.0, 5.0));
        float dif = max(dot(n, lightDir), 0.0);
        float amb = 0.2;

        // Colores del material (Cian a Morado)
        vec3 baseCol = mix(vec3(0.0, 0.8, 1.0), vec3(0.8, 0.0, 1.0), n.y + 0.5);

        // Niebla atmosférica (Fog)
        float fog = 1.0 - exp(-0.15 * t);
        col = mix(baseCol * (dif + amb), vec3(0.05, 0.05, 0.15), fog);

        // Partículas/grano animado
        float grain = hash(floor(p.xy * 20.0) + floor(p.z * 20.0) + floor(u_time * 10.0));
        if(grain > 0.95) {
            col += vec3(1.0) * pow(grain - 0.95, 5.0) * 0.5;
        }
    } else {
        // Fondo
        col = vec3(0.0, 0.01, 0.05);
    }

    // Post-procesado
    col = aces(col);
    col = pow(col, vec3(0.4545));

    float vig = clamp(1.0 - dot(uv, uv), 0.0, 1.0);
    col *= vig;

    gl_FragColor = vec4(col, 1.0);
}
