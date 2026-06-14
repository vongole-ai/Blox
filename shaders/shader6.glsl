// Cristales Bioluminiscentes Subterráneos
// Paste into https://twigl.app  →  mode: "classic"
precision highp float;
uniform vec2 u_resolution;
uniform float u_time;

#define T (u_time * 0.4)

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
    float v = 0.0;
    float amp = 0.5;
    for(int i = 0; i < 4; i++) {
        v += amp * n2(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return v;
}

float sdSphere(vec3 p, float s) {
    return length(p) - s;
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

mat2 rot2(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

float crystalShape(vec3 p) {
    float ang = atan(p.z, p.x);
    float rad = length(p.xz);
    float crystal = sdCappedCylinder(p, 2.0 + 0.5 * sin(ang * 6.0 + T), 0.3 + 0.1 * cos(ang * 3.0));
    crystal += 0.1 * sin(p.y * 3.0 + T * 2.0);
    return crystal;
}

vec2 map(vec3 p) {
    vec2 res = vec2(1000.0, 0.0);

    float cave = -sdSphere(p - vec3(0.0, 0.0, 0.0), 12.0);
    cave = smin(cave, sdSphere(p - vec3(8.0, -5.0, 8.0), 6.0), 2.0);
    cave = smin(cave, sdSphere(p - vec3(-7.0, 4.0, -6.0), 5.0), 2.0);

    float floorY = -3.0 + 0.5 * n2(p.xz * 0.5) + 0.3 * n2(p.xz * 1.5);
    float ground = p.y - floorY;
    cave = max(cave, -ground);

    float cryst1 = crystalShape(p - vec3(2.0, -2.0, 2.0));
    cryst1 = smin(cryst1, crystalShape((p - vec3(-2.0, 1.0, -2.0)) * vec3(0.8, 1.2, 0.8)), 0.5);

    float pillar = sdCappedCylinder(p - vec3(0.0, -1.0, 0.0), 4.0, 0.4 + 0.1 * sin(p.y * 2.0));
    pillar += 0.05 * n2(p.xz * 5.0 + T);

    float stalactite = sdCappedCylinder(p - vec3(4.0, 4.0, -3.0), 1.5, 0.2 + 0.05 * n2(p.xz * 3.0));
    stalactite = min(stalactite, sdCappedCylinder(p - vec3(-3.0, 3.5, 4.0), 1.2, 0.15));

    if(cryst1 < res.x) res = vec2(cryst1, 1.0);
    if(pillar < res.x) res = vec2(pillar, 2.0);
    if(stalactite < res.x) res = vec2(stalactite, 3.0);
    if(cave < res.x && cave > -0.1) res = vec2(abs(cave), 4.0);

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
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;

    float camRadius = 8.0 + 2.0 * sin(T * 0.3);
    float camTheta = T * 0.5;
    float camPhi = 0.4 + 0.3 * sin(T * 0.2);

    vec3 ro = vec3(
        camRadius * cos(camPhi) * cos(camTheta),
        camRadius * sin(camPhi),
        camRadius * cos(camPhi) * sin(camTheta)
    );

    vec3 ta = vec3(0.0, 0.0, 0.0);
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = cross(uu, ww);
    vec3 rd = normalize(uv.x * uu + uv.y * vv + 1.5 * ww);

    float t = 0.0;
    float tmax = 30.0;
    vec2 h;
    vec3 col = vec3(0.0);
    float matID = 0.0;

    for(int i = 0; i < 80; i++) {
        vec3 p = ro + t * rd;
        h = map(p);
        matID = h.y;
        if(h.x < 0.001 || t > tmax) break;
        t += h.x * 0.8;
    }

    vec3 bgCol = vec3(0.02, 0.03, 0.08) + 0.02 * fbm(uv * 3.0 + T);

    if(t < tmax) {
        vec3 p = ro + t * rd;
        vec3 n = calcNormal(p);

        vec3 lightPos = vec3(5.0 * cos(T), 6.0, 5.0 * sin(T));
        vec3 l = normalize(lightPos - p);
        float diff = max(dot(n, l), 0.0);
        float amb = 0.15 + 0.1 * n.y;

        vec3 baseCol;
        if(matID < 1.5) {
            baseCol = vec3(0.1, 0.6, 0.9) + 0.3 * sin(p * 2.0 + T);
            baseCol += 0.4 * vec3(0.5, 0.8, 1.0) * (0.5 + 0.5 * sin(T * 3.0 + length(p) * 2.0));
        } else if(matID < 2.5) {
            baseCol = vec3(0.4, 0.3, 0.2) * (0.8 + 0.4 * n2(p.xz * 2.0));
        } else if(matID < 3.5) {
            baseCol = vec3(0.7, 0.5, 0.3);
        } else {
            baseCol = vec3(0.05, 0.08, 0.12);
        }

        col = baseCol * (diff + amb);

        float fogFactor = 1.0 - exp(-0.08 * t);
        col = mix(col, bgCol, fogFactor);
    } else {
        col = bgCol;
    }

    vec2 particleUV = uv * 4.0 + vec2(T * 0.5, T * 0.3);
    float particles = 0.0;
    for(int j = 0; j < 3; j++) {
        float fj = float(j);
        vec2 offs = vec2(fj * 1.5, fj * 2.3);
        float nval = n2(particleUV * (1.0 + fj * 0.5) + offs);
        particles += smoothstep(0.7, 0.9, nval) * 0.3;
    }
    col += vec3(0.6, 0.9, 1.0) * particles * (0.6 + 0.4 * sin(T * 2.0));

    col = aces(col);
    col = pow(col, vec3(0.4545));

    float vignette = 1.0 - 0.3 * dot(uv, uv);
    col *= vignette;

    gl_FragColor = vec4(col, 1.0);
}
