// Forja Volcanica - Abismo geotermico con lava viva y cristales
// Paste into twigl.app  ->  mode: "classic"

precision highp float;
uniform vec2 resolution;
uniform float time;

#define T (time * 0.25)

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

float sdBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float map(vec3 p) {
    float d = 1000.0;
    
    // Suelo de lava ondulante
    float lavaY = -2.0 + 0.5 * sin(p.x * 0.5 + T) * cos(p.z * 0.5 + T * 0.7);
    lavaY += 0.3 * fbm(p.xz * 0.4 + T * 0.2);
    float lava = p.y - lavaY;
    d = min(d, lava);
    
    // Columnas cilindricas
    vec2 grid = floor(p.xz / 4.0);
    float seed = hash(grid);
    vec2 gridCenter = grid * 4.0 + vec2(2.0, 2.0);
    gridCenter += vec2(sin(seed * 5.0), cos(seed * 7.0)) * 1.5;
    float colDist = length(p.xz - gridCenter) - 0.7;
    colDist = max(colDist, p.y + 5.0);
    colDist = max(colDist, -p.y + 1.0);
    d = min(d, colDist);
    
    // Cristales
    vec3 crystalCenter = vec3(gridCenter.x, lavaY + 0.4, gridCenter.y);
    float cryst = sdBox(p - crystalCenter, vec3(0.2, 0.7, 0.2));
    d = min(d, cryst);
    
    return d;
}

vec3 calcNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)
    ));
}

vec3 aces(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution.xy) / resolution.y;
    
    // Camara
    float camTheta = T * 0.5;
    vec3 ro = vec3(10.0 * cos(camTheta), 2.0, 10.0 * sin(camTheta));
    vec3 target = vec3(0.0, -1.0, 0.0);
    vec3 f = normalize(target - ro);
    vec3 r = normalize(cross(f, vec3(0.0, 1.0, 0.0)));
    vec3 u = cross(r, f);
    vec3 rd = normalize(uv.x * r + uv.y * u + 1.5 * f);
    
    // Raymarching
    float t = 0.0;
    float tmax = 40.0;
    float matID = 0.0;
    
    for(int i = 0; i < 100; i++) {
        vec3 p = ro + rd * t;
        float h = map(p);
        if(h < 0.001) {
            matID = 1.0;
            break;
        }
        t += h * 0.8;
        if(t > tmax) break;
    }
    
    vec3 col;
    
    if(matID < 0.5) {
        // Cielo/fondo
        col = vec3(0.02, 0.01, 0.03);
        col += vec3(0.9, 0.3, 0.1) * pow(max(0.0, -rd.y), 2.0) * 0.3;
    } else {
        vec3 p = ro + rd * t;
        vec3 n = calcNormal(p);
        
        // Luz desde abajo (lava)
        vec3 lightPos = vec3(sin(T * 0.8) * 4.0, -4.0, cos(T * 0.8) * 4.0);
        vec3 l = normalize(lightPos - p);
        float dif = max(dot(n, l), 0.0);
        float amb = 0.1;
        
        // Color segun material
        float lavaY = -2.0 + 0.5 * sin(p.x * 0.5 + T) * cos(p.z * 0.5 + T * 0.7);
        lavaY += 0.3 * fbm(p.xz * 0.4 + T * 0.2);
        
        if(p.y < lavaY + 0.05) {
            // Lava
            float heat = fbm(p.xz * 2.0 + T);
            col = mix(vec3(0.5, 0.0, 0.0), vec3(1.0, 0.6, 0.0), heat);
            col += vec3(1.0, 0.9, 0.5) * pow(heat, 3.0);
            col *= (dif + 0.5);
        } else if(abs(p.y - (lavaY + 0.4)) < 0.6) {
            // Cristal
            col = mix(vec3(0.2, 0.8, 1.0), vec3(1.0, 0.2, 0.6), sin(T * 3.0 + p.y) * 0.5 + 0.5);
            col *= (dif + amb + 0.5);
        } else {
            // Columna
            col = vec3(0.1, 0.08, 0.06) * (dif + amb);
        }
        
        // Niebla atmosferica
        float fog = 1.0 - exp(-0.05 * t);
        vec3 fogCol = vec3(0.05, 0.02, 0.01);
        col = mix(col, fogCol, fog);
    }
    
    // Particulas de fuego
    vec2 sc = gl_FragCoord.xy / resolution.xy;
    float part = n2(vec2(sc.x * 80.0 + T * 6.0, sc.y * 80.0 + T * 4.0));
    col += vec3(1.0, 0.5, 0.1) * smoothstep(0.88, 0.99, part) * 0.6;
    
    // Post-procesado
    col = aces(col * 1.2);
    col = pow(col, vec3(0.4545));
    col *= 1.0 - 0.3 * dot(uv, uv);
    
    gl_FragColor = vec4(col, 1.0);
}