// Tunel Cuantico Psicodelico - Portal de luz con simetria radial y colores vibrantes
// Paste into twigl.app  ->  mode: "classic"

precision highp float;
uniform vec2 resolution;
uniform float time;

#define T (time * 0.8)

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float n2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float val = 0.0;
    float amp = 0.5;
    for(int i = 0; i < 4; i++) {
        val += amp * n2(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return val;
}

float sdCylinder(vec3 p, float r) {
    return length(p.xz) - r;
}

float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

mat2 rotM(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

vec3 palette(float t) {
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.263, 0.416, 0.557);
    return a + b * cos(6.28318 * (c * t + d));
}

vec2 map(vec3 p) {
    float ang = atan(p.z, p.x);
    float rad = length(p.xz);
    
    float tunnel = sdCylinder(p, 3.0 + 0.2 * sin(ang * 6.0 + T * 2.0));
    
    float rings = abs(sin(rad * 3.0 - T * 3.0 + p.y * 0.5)) - 0.05;
    rings = max(rings, abs(rad - 2.5) - 0.3);
    
    float spiral = abs(sin(ang * 3.0 + p.y * 2.0 - T * 4.0)) - 0.02;
    spiral = max(spiral, abs(rad - 2.8));
    
    float d = smin(tunnel, rings, 0.1);
    d = min(d, spiral);
    
    float glow = sdCylinder(p - vec3(0.0, -10.0, 0.0), 0.5);
    
    return vec2(d, glow);
}

vec3 calcNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p + e.xyy).x - map(p - e.xyy).x,
        map(p + e.yxy).x - map(p - e.yxy).x,
        map(p + e.yyx).x - map(p - e.yyx).x
    ));
}

vec3 aces(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution.xy) / resolution.y;
    
    float camZ = T * 4.0;
    vec3 ro = vec3(0.0, 0.0, camZ);
    vec3 rd = normalize(vec3(uv, 1.5));
    
    rd.xz = rd.xz * rotM(sin(T * 0.2) * 0.1);
    rd.yz = rd.yz * rotM(cos(T * 0.15) * 0.1);
    
    float t = 0.0;
    float tmax = 20.0;
    vec2 hit;
    vec3 col = vec3(0.0);
    
    for(int i = 0; i < 80; i++) {
        vec3 p = ro + t * rd;
        hit = map(p);
        if(hit.x < 0.001 || t > tmax) break;
        t += hit.x * 0.8;
    }
    
    vec3 bg = vec3(0.0);
    
    if(t < tmax) {
        vec3 p = ro + t * rd;
        vec3 n = calcNormal(p);
        
        float ang = atan(p.z, p.x);
        float rad = length(p.xz);
        
        float pattern = sin(rad * 5.0 - T * 3.0) * cos(ang * 6.0 + T * 2.0);
        pattern += 0.5 * sin(p.y * 3.0 + T);
        
        vec3 baseCol = palette(pattern * 0.5 + t * 0.05);
        
        float light = max(dot(n, -rd), 0.0);
        float rim = pow(1.0 - abs(dot(n, -rd)), 3.0);
        
        col = baseCol * light + baseCol * rim * 2.0;
        
        float fog = 1.0 - exp(-0.1 * t);
        col = mix(col, bg, fog);
    }
    
    float ang = atan(uv.y, uv.x);
    float len = length(uv);
    
    for(int j = 0; j < 3; j++) {
        float fj = float(j);
        float r = 0.3 + fj * 0.25;
        float ring = abs(len - r) - 0.02;
        float glow = smoothstep(0.05, 0.0, ring);
        vec3 c = palette(fj * 0.3 + T * 0.2);
        col += c * glow * 0.8;
    }
    
    float rays = abs(sin(ang * 6.0 + T * 2.0));
    rays = smoothstep(0.9, 1.0, rays) * (1.0 - len);
    col += vec3(1.0, 0.9, 0.7) * rays * 0.5;
    
    float centerGlow = exp(-len * 3.0) * (0.5 + 0.5 * sin(T * 5.0));
    col += vec3(1.0, 0.8, 0.9) * centerGlow;
    
    vec2 puv = uv * 8.0 + vec2(T);
    float particles = fbm(puv) * fbm(puv * 2.0 - T);
    col += vec3(0.5, 1.0, 0.9) * smoothstep(0.6, 0.9, particles) * 0.3;
    
    col = aces(col);
    col = pow(col, vec3(0.4545));
    
    float vig = 1.0 - 0.3 * dot(uv, uv);
    col *= vig;
    
    gl_FragColor = vec4(col, 1.0);
}