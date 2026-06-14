// Distrito Cubico Neon - Estructura flotante de cubos conectados por rayos de energia
// Paste into twigl.app  ->  mode: "classic"

precision highp float;
uniform vec2 resolution;
uniform float time;

#define T (time * 0.5)

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

float sdBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float sdCappedCylinder(vec3 p, float h, float r) {
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

mat2 rotM(float ang) {
    float s = sin(ang);
    float c = cos(ang);
    return mat2(c, -s, s, c);
}

float beam(vec3 p, vec3 a, vec3 b, float thickness) {
    vec3 pa = p - a;
    vec3 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float d = length(pa - ba * h) - thickness;
    float pulse = 0.02 * sin(T * 5.0 + length(ba) * 2.0);
    return d + pulse;
}

float structure(vec3 p) {
    float d = 1000.0;
    float grid = 3.0;
    
    for(int i = -2; i <= 2; i++) {
        for(int j = -2; j <= 2; j++) {
            float fi = float(i);
            float fj = float(j);
            float yoff = sin(fi * 0.7 + T) * 0.5 + cos(fj * 0.6 + T * 0.7) * 0.5;
            vec3 pos = vec3(fi * grid, yoff, fj * grid);
            float size = 0.6 + 0.2 * sin(fi * 1.3 + fj * 0.8 + T);
            float cube = sdBox(p - pos, vec3(size));
            d = min(d, cube);
            
            if(i < 2) {
                vec3 nextPos = vec3((fi + 1.0) * grid, sin((fi + 1.0) * 0.7 + T) * 0.5 + cos(fj * 0.6 + T * 0.7) * 0.5, fj * grid);
                float b = beam(p, pos, nextPos, 0.08);
                d = smin(d, b, 0.2);
            }
            if(j < 2) {
                vec3 nextPos = vec3(fi * grid, sin(fi * 0.7 + T) * 0.5 + cos((fj + 1.0) * 0.6 + T * 0.7) * 0.5, (fj + 1.0) * grid);
                float b = beam(p, pos, nextPos, 0.08);
                d = smin(d, b, 0.2);
            }
        }
    }
    return d;
}

float verticalRays(vec3 p) {
    float d = 1000.0;
    for(int i = 0; i < 5; i++) {
        float fi = float(i);
        float ang = fi * 1.256 + T * 0.3;
        float rad = 4.0 + sin(fi * 2.0 + T) * 1.0;
        vec3 pos = vec3(cos(ang) * rad, p.y, sin(ang) * rad);
        float h = 8.0 + 2.0 * sin(T + fi);
        float cyl = sdCappedCylinder(p - pos, h, 0.05 + 0.02 * sin(p.y * 3.0 + T * 4.0));
        d = min(d, cyl);
    }
    return d;
}

vec2 map(vec3 p) {
    vec2 res = vec2(1000.0, 0.0);
    
    float struc = structure(p);
    if(struc < res.x) res = vec2(struc, 1.0);
    
    float rays = verticalRays(p);
    if(rays < res.x) res = vec2(rays, 2.0);
    
    float floorY = -6.0;
    float fl = p.y - floorY;
    if(fl < res.x) res = vec2(fl, 3.0);
    
    return res;
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
    
    float camDist = 12.0 + 2.0 * sin(T * 0.4);
    float camAng = T * 0.2;
    float camHeight = 3.0 + 2.0 * sin(T * 0.3);
    
    vec3 ro = vec3(cos(camAng) * camDist, camHeight, sin(camAng) * camDist);
    vec3 ta = vec3(0.0, 0.0, 0.0);
    vec3 fwd = normalize(ta - ro);
    vec3 rgt = normalize(cross(fwd, vec3(0.0, 1.0, 0.0)));
    vec3 up = cross(rgt, fwd);
    vec3 rd = normalize(uv.x * rgt + uv.y * up + 1.5 * fwd);
    
    float t = 0.0;
    float tmax = 40.0;
    vec2 hit;
    vec3 col = vec3(0.0);
    float matID = 0.0;
    
    for(int i = 0; i < 100; i++) {
        vec3 p = ro + t * rd;
        hit = map(p);
        if(hit.x < 0.001 || t > tmax) break;
        t += hit.x * 0.8;
        matID = hit.y;
    }
    
    vec3 bgCol = vec3(0.02, 0.0, 0.05);
    bgCol += 0.1 * pow(fbm(uv * 3.0 + T), 2.0) * vec3(0.5, 0.0, 0.8);
    
    if(t < tmax) {
        vec3 p = ro + t * rd;
        vec3 n = calcNormal(p);
        
        vec3 light1 = normalize(vec3(8.0, 10.0, 5.0));
        vec3 light2 = normalize(vec3(-5.0, 8.0, -8.0));
        
        float diff1 = max(dot(n, light1), 0.0);
        float diff2 = max(dot(n, light2), 0.0) * 0.4;
        float amb = 0.05 + 0.05 * n.y;
        
        vec3 albedo;
        if(matID < 1.5) {
            albedo = vec3(0.1, 0.9, 1.0);
            float glow = 0.3 + 0.2 * sin(T * 3.0 + p.x + p.z);
            albedo += vec3(0.0, 0.4, 0.5) * glow;
        } else if(matID < 2.5) {
            albedo = vec3(1.0, 0.0, 0.8);
            albedo *= 0.5 + 0.5 * sin(p.y * 4.0 + T * 6.0);
        } else {
            albedo = vec3(0.05, 0.05, 0.1);
        }
        
        col = albedo * (diff1 + diff2 + amb);
        
        if(matID < 1.5) {
            col += vec3(0.0, 0.3, 0.4) * (0.5 + 0.5 * sin(T * 2.0));
        } else if(matID < 2.5) {
            col += vec3(0.5, 0.0, 0.4) * (0.3 + 0.3 * sin(T * 4.0));
        }
        
        float fogAmt = 1.0 - exp(-0.04 * t);
        col = mix(col, bgCol, fogAmt);
    } else {
        col = bgCol;
    }
    
    vec2 sparkUV = uv * 8.0 + vec2(T * 0.5, T * 0.3);
    float sparks = 0.0;
    for(int k = 0; k < 5; k++) {
        float fk = float(k);
        vec2 offs = vec2(fk * 7.3, fk * 5.1);
        float nval = n2(sparkUV * (1.0 + fk * 0.2) + offs);
        sparks += smoothstep(0.8, 0.95, nval) * (0.5 + 0.5 * sin(T * 4.0 + fk));
    }
    col += vec3(1.0, 0.8, 0.2) * sparks * 0.8;
    
    col = aces(col);
    col = pow(col, vec3(0.4545));
    
    float vig = 1.0 - 0.3 * dot(uv, uv);
    col *= vig;
    
    gl_FragColor = vec4(col, 1.0);
}