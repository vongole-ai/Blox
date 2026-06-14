// Amber Ruins - Eroded alien pillars veined with bioluminescent moss, drifting luminous spores under a hazy twilight
// Paste into https://twigl.app - mode: classic

precision highp float;
uniform vec2 resolution;
uniform float time;

#define T (time * 0.3)

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float n2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float va = hash(i);
    float vb = hash(i + vec2(1.0, 0.0));
    float vc = hash(i + vec2(0.0, 1.0));
    float vd = hash(i + vec2(1.0, 1.0));
    return mix(mix(va, vb, f.x), mix(vc, vd, f.x), f.y);
}

float fbm(vec2 p) {
    float val = 0.0;
    float amp = 0.5;
    mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 5; i++) {
        val += amp * n2(p);
        p = rot * p * 2.0;
        amp *= 0.5;
    }
    return val;
}

float sdPillar(vec3 p, float r, float h) {
    float cyl = length(p.xz) - r;
    cyl = max(cyl, p.y);
    cyl = max(cyl, -(p.y - h));
    return cyl;
}

vec2 map(vec3 p) {
    float gDist = p.y - fbm(p.xz * 0.4) * 0.12;
    float sDist = 1e10;

    float erode0 = fbm(p.xz * 0.25 + T * 0.04) * 0.45;
    sDist = min(sDist, sdPillar(p, 0.9 + erode0, 5.8));

    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float ang = fi * 0.8976 + 0.4;
        float rad = 3.8 + sin(fi * 2.3) * 1.3;
        vec3 cp = vec3(cos(ang) * rad, 0.0, sin(ang) * rad);
        vec3 q = p - cp;
        float h = 1.8 + sin(fi * 1.7 + 0.5) * 1.6;
        float erode = fbm(q.xz * 0.6 + fi * 4.1) * 0.3;
        sDist = min(sDist, sdPillar(q, 0.38 + erode, h));
    }

    float dist = min(gDist, sDist);
    float matId = sDist < gDist ? 1.0 : 0.0;
    return vec2(dist, matId);
}

vec3 calcNormal(vec3 p) {
    vec2 e = vec2(0.002, 0.0);
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
    float ee = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + ee), 0.0, 1.0);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution) / resolution.y;

    float camA = T * 0.22;
    float camR = 9.5 + sin(T * 0.15) * 2.5;
    float camH = 3.2 + sin(T * 0.1) * 1.0;
    vec3 ro = vec3(cos(camA) * camR, camH, sin(camA) * camR);
    vec3 ta = vec3(sin(T * 0.06) * 0.8, 2.0 + sin(T * 0.08) * 0.4, cos(T * 0.06) * 0.8);

    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
    vec3 vv = cross(uu, ww);
    vec3 rd = normalize(uv.x * uu + uv.y * vv + 1.6 * ww);

    float tDist = 0.0;
    vec2 hit = vec2(0.0);
    for (int i = 0; i < 80; i++) {
        vec3 pos = ro + rd * tDist;
        hit = map(pos);
        if (hit.x < 0.001 || tDist > 50.0) break;
        tDist += hit.x;
    }

    float skyG = clamp(rd.y * 0.5 + 0.5, 0.0, 1.0);
    vec3 skyCol = mix(vec3(0.1, 0.05, 0.02), vec3(0.01, 0.015, 0.04), skyG);
    skyCol += vec3(0.22, 0.1, 0.03) * (1.0 - smoothstep(0.0, 0.15, abs(rd.y)));

    vec3 col = skyCol;

    if (tDist < 50.0) {
        vec3 pos = ro + rd * tDist;
        vec3 n = calcNormal(pos);
        vec3 lDir = normalize(vec3(0.5, 0.7, 0.3));

        float dif = max(dot(n, lDir), 0.0);
        float amb = 0.1 + 0.06 * (0.5 + 0.5 * n.y);

        vec3 halfV = normalize(lDir - rd);
        float spec = pow(max(dot(n, halfV), 0.0), 32.0) * 0.3;

        float rim = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);

        vec3 stoneCol = vec3(0.52, 0.34, 0.19);
        vec3 groundCol = vec3(0.2, 0.14, 0.09) + fbm(pos.xz * 3.0) * 0.1;

        float vein = fbm(pos.xz * 2.0 + pos.y * 1.5 + T * 0.06);
        vein = smoothstep(0.45, 0.55, vein);
        vec3 veinCol = vec3(0.04, 0.5, 0.42) * vein * 3.5;

        float gMoss = fbm(pos.xz * 1.5 + T * 0.03);
        gMoss = smoothstep(0.55, 0.65, gMoss);
        vec3 gMossCol = vec3(0.03, 0.35, 0.28) * gMoss * 1.5;

        vec3 baseCol = hit.y > 0.5 ? stoneCol : groundCol;
        col = baseCol * (amb + dif * 0.75);
        col += spec * vec3(0.6, 0.4, 0.2);
        col += vec3(0.15, 0.08, 0.03) * rim * 0.5;
        col += veinCol * hit.y;
        col += gMossCol * (1.0 - hit.y);

        float fogF = 1.0 - exp(-tDist * 0.03);
        col = mix(col, vec3(0.1, 0.05, 0.025), fogF);
    }

    for (int j = 0; j < 16; j++) {
        float fj = float(j);
        vec3 sp = vec3(
            sin(fj * 2.39 + T * 0.28) * 6.0,
            0.8 + sin(fj * 1.73 + T * 0.18) * 2.5,
            cos(fj * 3.17 + T * 0.22) * 6.0
        );
        vec3 toSp = sp - ro;
        float proj = dot(toSp, rd);
        if (proj > 0.0) {
            vec3 closest = ro + rd * proj;
            float dRay = length(closest - sp);
            float glow = 0.005 / (dRay * dRay + 0.005);
            glow *= smoothstep(40.0, 3.0, proj);
            float flicker = 0.6 + 0.4 * sin(fj * 7.3 + T * 2.5);
            col += vec3(0.04, 0.45, 0.38) * glow * flicker * 0.14;
        }
    }

    float grain = (hash(gl_FragCoord.xy + fract(T * 100.0)) - 0.5) * 0.035;
    col += grain;

    col = aces(col);
    col = pow(col, vec3(0.4545));

    vec2 vUV = gl_FragCoord.xy / resolution - 0.5;
    col *= 1.0 - dot(vUV, vUV) * 0.6;

    gl_FragColor = vec4(col, 1.0);
}