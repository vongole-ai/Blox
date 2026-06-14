// Forja Volcanica - Abismo geotermico con columnas basalticas, lava viva y cristales incandescentes
// Paste into https://twigl.app  →  mode: "classic"
precision highp float;
uniform vec2 u_resolution;
uniform float u_time;

#define T (u_time * 0.25)
#define PI 3.14159265359

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float n2(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for(int i = 0; i < 4; i++) {
        v += a * n2(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

// Columnas basálticas hexagonales
float hexColumn(vec3 p, float scale) {
    vec2 q = p.xz;
    float angle = atan(q.y, q.x);
    float r = length(q);
    float hex = cos(angle * 3.0) * 0.866;
    return abs(r - hex * scale) - 0.15;
}

// Cristales que brillan
float crystal(vec3 p, float seed) {
    float wobble = sin(T + seed * 10.0) * 0.2;
    vec3 s = vec3(0.15, 0.8 + wobble, 0.15);
    vec3 q = abs(p) - s;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// Lava fluyendo (distancia con ruido)
float lavaFloor(vec3 p) {
    float wave = sin(p.x * 0.5 + T) * cos(p.z * 0.5 + T * 0.7) * 0.5;
    float noise = fbm(p.xz * 0.3 + T * 0.2) * 1.5;
    return p.y - (-4.0 + wave + noise);
}

// Escena principal
float map(vec3 p) {
    float d = 1e10;
    
    // Paredes de columnas basálticas
    float col = hexColumn(p, 3.5);
    d = min(d, col + 0.1 * sin(p.y * 2.0 + T));
    
    // Suelo de lava
    float lava = lavaFloor(p);
    d = min(d, lava);
    
    // Cristales dispersos
    float s = 6.0;
    vec3 id = floor(p / s) * s;
    float seed = hash(id.xz);
    
    for(int i = -1; i <= 1; i++) {
        for(int j = -1; j <= 1; j++) {
            vec3 offset = vec3(float(i) * s + 2.0 * sin(seed * 10.0),
                              -2.0 + seed * 2.0,
                              float(j) * s + 2.0 * cos(seed * 15.0));
            float crys = crystal(p - offset, seed + float(i * 3 + j));
            d = min(d, crys);
        }
    }
    
    // Techo
    d = min(d, -p.y - 8.0);
    
    return d;
}

vec3 norm(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)
    ));
}

vec2 march(vec3 ro, vec3 rd) {
    float t = 0.0, matID = -1.0;
    for(int i = 0; i < 100; i++) {
        vec3 p = ro + rd * t;
        float h = map(p);
        
        // Identificar material
        if(h < 0.001) {
            float lavaCheck = lavaFloor(p);
            float hexCheck = hexColumn(p, 3.5);
            if(abs(lavaCheck - h) < 0.01) {
                matID = 1.0; // Lava
            } else if(abs(hexCheck - h) < 0.02) {
                matID = 2.0; // Basalto
            } else {
                matID = 3.0; // Cristal
            }
            break;
        }
        t += h * 0.85;
        if(t > 60.0) break;
    }
    return vec2(t, matID);
}

vec3 aces(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void main() {
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y;
    
    // Cámara orbitando
    float camTheta = T * 0.4;
    float camPhi = 0.5 + 0.3 * sin(T * 0.3);
    float camDist = 12.0 + sin(T * 0.2) * 2.0;
    
    vec3 ro = vec3(
        camDist * cos(camPhi) * cos(camTheta),
        -3.0 + sin(T * 0.4) * 1.5,
        camDist * cos(camPhi) * sin(camTheta)
    );
    
    vec3 target = vec3(0.0, -2.0, 0.0);
    vec3 f = normalize(target - ro);
    vec3 r = normalize(cross(f, vec3(0.0, 1.0, 0.0)));
    vec3 u = cross(r, f);
    vec3 rd = normalize(uv.x * r + uv.y * u + 2.0 * f);
    
    vec2 hit = march(ro, rd);
    vec3 col;
    
    if(hit.y < 0.0) {
        // Cielo oscuro con brillo lejano
        col = vec3(0.02, 0.01, 0.05);
        col += vec3(1.0, 0.4, 0.1) * pow(max(0.0, -rd.y), 3.0) * 0.3;
    } else {
        vec3 p = ro + rd * hit.x;
        vec3 n = norm(p);
        
        // Iluminación desde la lava
        vec3 lightPos = vec3(sin(T * 0.8) * 5.0, -3.5, cos(T * 0.8) * 5.0);
        vec3 l = normalize(lightPos - p);
        float dif = max(dot(n, l), 0.0);
        float amb = 0.1;
        
        if(hit.y < 1.5) {
            // Lava incandescente
            float heat = fbm(p.xz * 2.0 + T) * 0.7 + 0.3;
            vec3 lavaCol = mix(vec3(0.1, 0.02, 0.0), vec3(1.0, 0.5, 0.0), heat);
            lavaCol = mix(lavaCol, vec3(1.0, 0.9, 0.3), pow(heat, 2.0) * 0.5);
            col = lavaCol * (dif + amb + 0.3) + vec3(0.8, 0.6, 0.1) * heat * 0.5;
        } else if(hit.y < 2.5) {
            // Basalto oscuro con grietas de fuego
            float crack = smoothstep(0.3, 0.7, fbm(p.xy * 3.0 + T * 0.5));
            col = mix(vec3(0.08, 0.06, 0.05), vec3(0.9, 0.4, 0.1), crack * 0.4);
            col *= (dif + amb);
        } else {
            // Cristales que brillan
            float glow = pow(max(0.0, 1.0 - length(p) * 0.1), 2.0);
            vec3 crystalCol = mix(vec3(0.5, 0.9, 1.0), vec3(1.0, 0.3, 0.8), sin(T * 2.0 + length(p)) * 0.5 + 0.5);
            col = crystalCol * (dif + amb + glow * 1.5);
        }
        
        // Neblina/humo
        float fog = 1.0 - exp(-hit.x * hit.x * 0.0008);
        col = mix(col, vec3(0.1, 0.05, 0.02), fog * 0.6);
    }
    
    // Partículas de fuego flotante
    vec2 sc = gl_FragCoord.xy / u_resolution.xy;
    float part = n2(vec2(sc.x * 100.0 + T * 5.0, sc.y * 100.0 + T * 3.0));
    col += vec3(1.0, 0.6, 0.2) * smoothstep(0.85, 0.99, part) * 0.4;
    
    // Post-procesado
    col = aces(col * 1.2);
    col = pow(col, vec3(0.4545));
    col *= 1.0 - 0.4 * dot(uv, uv); // Viñeta
    col += (hash(gl_FragCoord.xy + fract(u_time) * vec2(7.0, 11.0)) - 0.5) * 0.02; // Grano
    
    gl_FragColor = vec4(col, 1.0);
}
