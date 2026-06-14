// Forja Volcanica HD - Abismo geotermico con lava viva, cristales y corredor
// Paste into twigl.app  ->  mode: "classic"

precision highp float;
uniform vec2 resolution;
uniform float time;

#define T (time * 0.25)
#define PI 3.14159265

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float hash3(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898, 78.233, 54.53))) * 43758.5453);
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

float n3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n = hash3(i);
    n += hash3(i + vec3(1.0, 0.0, 0.0)) * f.x * (1.0 - f.y) * (1.0 - f.z);
    n += hash3(i + vec3(0.0, 1.0, 0.0)) * (1.0 - f.x) * f.y * (1.0 - f.z);
    n += hash3(i + vec3(0.0, 0.0, 1.0)) * (1.0 - f.x) * (1.0 - f.y) * f.z;
    n += hash3(i + vec3(1.0, 1.0, 0.0)) * f.x * f.y * (1.0 - f.z);
    n += hash3(i + vec3(1.0, 0.0, 1.0)) * f.x * (1.0 - f.y) * f.z;
    n += hash3(i + vec3(0.0, 1.0, 1.0)) * (1.0 - f.x) * f.y * f.z;
    n += hash3(i + vec3(1.0, 1.0, 1.0)) * f.x * f.y * f.z;
    return n;
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for(int i = 0; i < 6; i++) {
        v += a * n2(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

float fbm3(vec3 p) {
    float v = 0.0, a = 0.5;
    for(int i = 0; i < 5; i++) {
        v += a * n3(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

float sdBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a;
    vec3 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
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

float getLavaHeight(vec2 p) {
    float y = -2.0 + 0.5 * sin(p.x * 0.5 + T) * cos(p.y * 0.5 + T * 0.7);
    y += 0.3 * fbm(p * 0.4 + T * 0.2);
    y += 0.15 * sin(p.x * 1.2 + T * 1.5) * cos(p.y * 0.8);
    y += 0.08 * fbm(p * 1.5 - T * 0.5);
    return y;
}

float runner(vec3 p) {
    float runRadius = 5.0;
    float runSpeed = T * 3.0;
    float runX = cos(runSpeed) * runRadius;
    float runZ = sin(runSpeed) * runRadius;
    
    float lavaH = getLavaHeight(vec2(runX, runZ));
    float bounce = abs(sin(runSpeed * 2.0)) * 0.3;
    float runY = lavaH + 1.0 + bounce;
    
    vec3 pos = vec3(runX, runY, runZ);
    vec3 q = p - pos;
    
    float ang = -runSpeed + 1.57;
    q.xz = q.xz * rotM(ang);
    
    float legSwing = sin(runSpeed * 3.0);
    float armSwing = cos(runSpeed * 3.0);
    
    // Cuerpo con ropa
    float body = sdCapsule(q, vec3(0.0, 0.6, 0.0), vec3(0.0, 1.5, 0.0), 0.2);
    body = smin(body, sdBox(q - vec3(0.0, 1.1, 0.0), vec3(0.25, 0.4, 0.15)), 0.1);
    
    // Cabeza
    float head = sdSphere(q - vec3(0.0, 1.75, 0.0), 0.18);
    
    // Piernas con botas
    vec3 legL1 = vec3(-0.15, 0.6, 0.0);
    vec3 legL2 = vec3(-0.15 + legSwing * 0.3, 0.3, 0.0);
    vec3 legL3 = vec3(-0.15 + legSwing * 0.5, 0.0, 0.0);
    float leftLeg = sdCapsule(q, legL1, legL2, 0.09);
    leftLeg = smin(leftLeg, sdCapsule(q, legL2, legL3, 0.07), 0.05);
    // Bota
    leftLeg = smin(leftLeg, sdBox(q - legL3 - vec3(0.0, 0.05, 0.0), vec3(0.12, 0.1, 0.15)), 0.05);
    
    vec3 legR1 = vec3(0.15, 0.6, 0.0);
    vec3 legR2 = vec3(0.15 - legSwing * 0.3, 0.3, 0.0);
    vec3 legR3 = vec3(0.15 - legSwing * 0.5, 0.0, 0.0);
    float rightLeg = sdCapsule(q, legR1, legR2, 0.09);
    rightLeg = smin(rightLeg, sdCapsule(q, legR2, legR3, 0.07), 0.05);
    rightLeg = smin(rightLeg, sdBox(q - legR3 - vec3(0.0, 0.05, 0.0), vec3(0.12, 0.1, 0.15)), 0.05);
    
    // Brazos
    float leftArm = sdCapsule(q, vec3(-0.35, 1.4, 0.0), vec3(-0.5 - armSwing * 0.2, 0.9, 0.0), 0.08);
    float rightArm = sdCapsule(q, vec3(0.35, 1.4, 0.0), vec3(0.5 + armSwing * 0.2, 0.9, 0.0), 0.08);
    
    float d = min(body, head);
    d = min(d, leftLeg);
    d = min(d, rightLeg);
    d = min(d, leftArm);
    d = min(d, rightArm);
    
    return d;
}

float map(vec3 p) {
    float d = 1000.0;
    
    // Lava con mas detalle
    float lavaY = getLavaHeight(p.xz);
    float lava = p.y - lavaY;
    d = min(d, lava);
    
    // Columnas con detalles
    vec2 grid = floor(p.xz / 4.0);
    float seed = hash(grid);
    vec2 gridCenter = grid * 4.0 + vec2(2.0, 2.0);
    gridCenter += vec2(sin(seed * 5.0), cos(seed * 7.0)) * 1.5;
    
    // Columna base
    float colDist = length(p.xz - gridCenter) - 0.7;
    colDist = max(colDist, p.y + 5.0);
    colDist = max(colDist, -p.y + 1.0);
    
    // Anillos en la columna
    float rings = abs(sin(p.y * 3.0 + seed * 5.0)) - 0.05;
    rings = max(rings, abs(length(p.xz - gridCenter) - 0.75));
    colDist = smin(colDist, rings, 0.02);
    
    d = min(d, colDist);
    
    // Cristales complejos
    vec3 crystalCenter = vec3(gridCenter.x, lavaY + 0.4, gridCenter.y);
    vec3 cq = p - crystalCenter;
    cq.yz = cq.yz * rotM(0.3 + seed);
    cq.xz = cq.xz * rotM(seed * 2.0);
    float cryst = sdBox(cq, vec3(0.15, 0.6, 0.15));
    cryst = smin(cryst, sdBox(cq - vec3(0.0, 0.3, 0.0), vec3(0.1, 0.3, 0.1)), 0.05);
    d = min(d, cryst);
    
    // Corredor
    float run = runner(p);
    d = min(d, run);
    
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

float getAO(vec3 p, vec3 n) {
    float ao = 0.0;
    for(int i = 1; i <= 5; i++) {
        float dist = float(i) * 0.15;
        float h = map(p + n * dist);
        ao += (dist - h) / dist;
    }
    return clamp(1.0 - ao * 0.15, 0.0, 1.0);
}

float softShadow(vec3 p, vec3 l, float mint, float maxt) {
    float res = 1.0;
    float t = mint;
    for(int i = 0; i < 16; i++) {
        if(t > maxt) break;
        float h = map(p + l * t);
        if(h < 0.001) return 0.0;
        res = min(res, 8.0 * h / t);
        t += h;
    }
    return clamp(res, 0.0, 1.0);
}

vec3 aces(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution.xy) / resolution.y;
    
    // Camara con movimiento suave
    float camTheta = T * 0.3 + sin(T * 0.2) * 0.3;
    float camHeight = 2.5 + sin(T * 0.4) * 0.5;
    vec3 ro = vec3(12.0 * cos(camTheta), camHeight, 12.0 * sin(camTheta));
    vec3 target = vec3(0.0, -0.5, 0.0);
    vec3 f = normalize(target - ro);
    vec3 r = normalize(cross(f, vec3(0.0, 1.0, 0.0)));
    vec3 u = cross(r, f);
    vec3 rd = normalize(uv.x * r + uv.y * u + 1.8 * f);
    
    // Raymarching
    float t = 0.0;
    float tmax = 50.0;
    float matID = 0.0;
    
    for(int i = 0; i < 120; i++) {
        vec3 p = ro + rd * t;
        float h = map(p);
        if(h < 0.001) {
            matID = 1.0;
            break;
        }
        t += h * 0.7;
        if(t > tmax) break;
    }
    
    vec3 col;
    
    if(matID < 0.5) {
        // Cielo con neblina
        col = vec3(0.02, 0.01, 0.03);
        col += vec3(0.9, 0.3, 0.1) * pow(max(0.0, -rd.y), 2.0) * 0.3;
        col += vec3(0.1, 0.05, 0.08) * fbm(rd.xz * 3.0 + T) * 0.5;
    } else {
        vec3 p = ro + rd * t;
        vec3 n = calcNormal(p);
        
        float lavaY = getLavaHeight(p.xz);
        float runDist = runner(p);
        float isRunner = step(runDist, 0.01);
        float isLava = step(p.y, lavaY + 0.05);
        
        // Multi-luz
        vec3 light1 = normalize(vec3(sin(T * 0.8) * 4.0, -3.0, cos(T * 0.8) * 4.0));
        vec3 light2 = normalize(vec3(-3.0, 2.0, -2.0));
        vec3 light3 = normalize(vec3(2.0, -1.0, 3.0));
        
        float dif1 = max(dot(n, light1), 0.0);
        float dif2 = max(dot(n, light2), 0.0) * 0.4;
        float dif3 = max(dot(n, light3), 0.0) * 0.3;
        
        // Soft shadows desde la luz principal
        float shadow = softShadow(p, light1, 0.1, 10.0);
        
        float ao = getAO(p, n);
        
        float amb = 0.08;
        
        vec3 baseCol;
        
        if(isRunner > 0.5) {
            // Corredor - silueta con detalles
            baseCol = vec3(0.08, 0.05, 0.03);
            // Rim lighting intenso desde la lava
            float rim = pow(1.0 - max(dot(n, -light1), 0.0), 2.0);
            baseCol += vec3(1.0, 0.4, 0.1) * rim * 0.8;
        } else if(isLava > 0.5) {
            // Lava con mas capas
            float heat = fbm(p.xz * 2.0 + T);
            heat += 0.3 * sin(p.x * 5.0 + T * 2.0) * cos(p.z * 3.0);
            heat = clamp(heat, 0.0, 1.0);
            baseCol = mix(vec3(0.4, 0.0, 0.0), vec3(1.0, 0.5, 0.0), heat);
            baseCol = mix(baseCol, vec3(1.0, 0.9, 0.5), pow(heat, 3.0));
            // Brillo emisivo
            baseCol += vec3(0.5, 0.2, 0.05) * (1.0 - heat);
        } else {
            // Columnas y cristales
            float crack = fbm3(p * 2.0) * fbm3(p * 4.0);
            baseCol = vec3(0.12, 0.09, 0.07) * (0.8 + 0.4 * crack);
            baseCol += vec3(0.6, 0.3, 0.1) * smoothstep(0.6, 0.9, crack) * 0.4;
        }
        
        // Combinar iluminacion
        col = baseCol * (dif1 * shadow + dif2 + dif3 + amb);
        col *= ao;
        
        // Reflexion en la lava
        if(isLava > 0.5) {
            vec3 refDir = reflect(rd, n);
            float refHeat = fbm(refDir.xz * 2.0 + T);
            vec3 refCol = mix(vec3(0.8, 0.3, 0.0), vec3(1.0, 0.8, 0.3), refHeat);
            col = mix(col, refCol, 0.15);
        }
        
        // Niebla volumetrica
        float fog = 1.0 - exp(-0.04 * t);
        vec3 fogCol = vec3(0.05, 0.02, 0.01) + vec3(0.3, 0.1, 0.05) * (1.0 - rd.y);
        col = mix(col, fogCol, fog);
    }
    
    // Particulas de ceniza
    vec2 sc = gl_FragCoord.xy / resolution.xy;
    float ash = 0.0;
    for(int i = 0; i < 4; i++) {
        float fi = float(i);
        vec2 offs = vec2(fi * 23.0, fi * 17.0);
        float a = n2(vec2(sc.x * 60.0 + T * (2.0 + fi), sc.y * 60.0 + T * 3.0 + offs.x));
        ash += smoothstep(0.92, 0.99, a) * (0.3 + 0.2 * sin(T + fi));
    }
    col += vec3(0.6, 0.5, 0.4) * ash;
    
    // Chispas del corredor
    float runSpeed = T * 3.0;
    float runX = cos(runSpeed) * 5.0;
    float runZ = sin(runSpeed) * 5.0;
    vec2 footPos = vec2(runX, runZ) / 15.0 + 0.5;
    float footDist = length(sc - footPos);
    float spark = smoothstep(0.015, 0.0, footDist) * (0.5 + 0.5 * sin(runSpeed * 15.0));
    col += vec3(1.0, 0.95, 0.7) * spark;
    
    // Post-procesado
    col = aces(col * 1.3);
    col = pow(col, vec3(0.4545));
    
    // Viñeta
    float vig = 1.0 - 0.25 * dot(uv, uv);
    col *= vig;
    
    gl_FragColor = vec4(col, 1.0);
}