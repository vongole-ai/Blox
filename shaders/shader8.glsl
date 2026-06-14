// Medusa Biomecanica - Criatura flotante con tentaculos organicos pulsando en el vacio
// Paste into twigl.app  ->  mode: "classic"

precision highp float;
uniform vec2 resolution;
uniform float time;

#define T (time * 0.35)

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
    for(int i = 0; i < 5; i++) {
        val += amp * n2(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return val;
}

float sdSphere(vec3 p, float rad) {
    return length(p) - rad;
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a;
    vec3 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
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

float tentacle(vec3 p, float id, float len) {
    float wave = sin(p.y * 2.0 - T * 3.0 + id * 1.5) * 0.3;
    float wave2 = cos(p.y * 1.5 + T * 2.0 + id) * 0.2;
    vec3 off = vec3(wave, 0.0, wave2);
    off.xz = off.xz * rotM(id + T * 0.5);
    vec3 p2 = p + off;
    p2.xz = p2.xz * rotM(id * 0.5);
    float r = 0.15 + 0.1 * sin(p.y * 3.0 + T);
    r *= smoothstep(len, len * 0.3, p.y);
    return sdCapsule(p2, vec3(0.0), vec3(0.0, -len, 0.0), r);
}

float core(vec3 p) {
    float d1 = sdSphere(p, 1.2 + 0.1 * sin(T * 2.0));
    float d2 = sdSphere(p - vec3(0.8, 0.0, 0.0), 0.6);
    float d3 = sdSphere(p + vec3(0.8, 0.0, 0.0), 0.6);
    float d4 = sdSphere(p - vec3(0.0, 0.0, 0.8), 0.6);
    float d5 = sdSphere(p + vec3(0.0, 0.0, 0.8), 0.6);
    float merged = smin(d1, d2, 0.4);
    merged = smin(merged, d3, 0.4);
    merged = smin(merged, d4, 0.4);
    merged = smin(merged, d5, 0.4);
    merged += 0.05 * n2(p.xz * 3.0 + T);
    return merged;
}

float rings(vec3 p) {
    float ang = atan(p.z, p.x);
    float rad = length(p.xz);
    float ring1 = abs(rad - 2.0 + 0.3 * sin(ang * 3.0 + T)) - 0.05;
    float ring2 = abs(rad - 2.5 + 0.2 * cos(ang * 5.0 - T * 0.7)) - 0.03;
    float y1 = 0.5 * sin(ang * 2.0 + T);
    float y2 = 0.3 * cos(ang * 4.0 - T * 0.5);
    ring1 = max(ring1, abs(p.y - y1) - 0.02);
    ring2 = max(ring2, abs(p.y - y2) - 0.02);
    return min(ring1, ring2);
}

vec2 map(vec3 p) {
    vec2 res = vec2(1000.0, 0.0);
    float nucleus = core(p);
    if(nucleus < res.x) res = vec2(nucleus, 1.0);
    for(int i = 0; i < 6; i++) {
        float fi = float(i);
        float ang = fi * 1.0472;
        float rad = 1.0;
        vec3 tentPos = p - vec3(cos(ang) * rad, 0.5, sin(ang) * rad);
        tentPos.xz = tentPos.xz * rotM(-ang);
        float tent = tentacle(tentPos, fi, 3.0 + 0.5 * sin(T + fi));
        if(tent < res.x) res = vec2(tent, 2.0);
    }
    float orb = sdSphere(p - vec3(3.0, 1.0, 2.0), 0.4 + 0.1 * sin(T * 4.0));
    orb = min(orb, sdSphere(p - vec3(-2.5, -0.5, 3.0), 0.3));
    orb = min(orb, sdSphere(p - vec3(2.0, -1.5, -2.5), 0.35));
    if(orb < res.x) res = vec2(orb, 3.0);
    float ring = rings(p);
    if(ring < res.x) res = vec2(ring, 4.0);
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
    float camDist = 7.0 + 2.0 * sin(T * 0.4);
    float camYaw = T * 0.3;
    float camPitch = 0.2 + 0.15 * sin(T * 0.2);
    vec3 ro = vec3(
        camDist * cos(camPitch) * cos(camYaw),
        camDist * sin(camPitch),
        camDist * cos(camPitch) * sin(camYaw)
    );
    vec3 ta = vec3(0.0, -0.5, 0.0);
    vec3 fwd = normalize(ta - ro);
    vec3 rgt = normalize(cross(fwd, vec3(0.0, 1.0, 0.0)));
    vec3 up = cross(rgt, fwd);
    vec3 rd = normalize(uv.x * rgt + uv.y * up + 1.8 * fwd);
    float t = 0.0;
    float tmax = 25.0;
    vec2 hit;
    vec3 col = vec3(0.0);
    float matID = 0.0;
    for(int i = 0; i < 90; i++) {
        vec3 p = ro + t * rd;
        hit = map(p);
        if(hit.x < 0.001 || t > tmax) break;
        t += hit.x * 0.7;
        matID = hit.y;
    }
    vec3 bgBase = vec3(0.01, 0.02, 0.05);
    vec3 bgCol = bgBase + 0.1 * pow(fbm(uv * 2.0 + T * 0.1), 2.0) * vec3(0.2, 0.4, 0.8);
    if(t < tmax) {
        vec3 p = ro + t * rd;
        vec3 n = calcNormal(p);
        vec3 light1 = normalize(vec3(5.0, 8.0, 5.0));
        vec3 light2 = normalize(vec3(-4.0, 3.0, -6.0));
        float diff1 = max(dot(n, light1), 0.0);
        float diff2 = max(dot(n, light2), 0.0) * 0.5;
        float amb = 0.08 + 0.04 * n.y;
        vec3 albedo;
        if(matID < 1.5) {
            albedo = vec3(0.1, 0.7, 0.6);
            albedo += 0.3 * vec3(0.4, 0.9, 1.0) * (0.5 + 0.5 * sin(T * 3.0 + length(p) * 2.0));
        } else if(matID < 2.5) {
            albedo = vec3(0.8, 0.3, 0.5) * (0.7 + 0.3 * sin(p.y * 5.0 - T * 2.0));
        } else if(matID < 3.5) {
            albedo = vec3(1.0, 0.6, 0.2);
        } else {
            albedo = vec3(0.9, 0.9, 1.0) * 0.8;
        }
        col = albedo * (diff1 + diff2 + amb);
        float fogAmt = 1.0 - exp(-0.06 * t);
        col = mix(col, bgCol, fogAmt);
    } else {
        col = bgCol;
    }
    vec2 starUV = uv * 6.0 + vec2(T * 0.2, T * 0.15);
    float sparks = 0.0;
    for(int k = 0; k < 4; k++) {
        float fk = float(k);
        vec2 offs = vec2(fk * 3.7, fk * 2.1);
        float nval = n2(starUV * (0.8 + fk * 0.3) + offs);
        sparks += smoothstep(0.75, 0.95, nval) * (0.4 + 0.3 * sin(T * 3.0 + fk));
    }
    col += vec3(0.8, 0.9, 1.0) * sparks;
    col = aces(col);
    col = pow(col, vec3(0.4545));
    float vig = 1.0 - 0.25 * dot(uv, uv);
    col *= vig;
    gl_FragColor = vec4(col, 1.0);
}