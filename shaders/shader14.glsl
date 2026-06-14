// Planeta Pixelado - Mundo retro con scanlines y paleta limitada
// Paste into twigl.app  ->  mode: "classic"

precision highp float;
uniform vec2 resolution;
uniform float time;

#define T (time * 0.15)

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

// Paleta restringida estilo retro
vec3 palette(float t) {
    // Oceanos: azules, Tierra: verdes, Hielo: blanco/gris
    if(t < 0.35) return vec3(0.2, 0.4, 0.8);      // Agua profunda
    if(t < 0.45) return vec3(0.4, 0.7, 0.9);      // Agua superficial
    if(t < 0.55) return vec3(0.5, 0.8, 0.4);      // Tierra baja
    if(t < 0.70) return vec3(0.3, 0.6, 0.3);      // Tierra/alta
    if(t < 0.85) return vec3(0.7, 0.75, 0.8);     // Montanas
    return vec3(0.95, 0.95, 1.0);                  // Hielo/nieve
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution.xy) / resolution.y;
    
    // Pixelacion
    float pixelSize = 80.0;
    vec2 pixUV = floor(uv * pixelSize) / pixelSize;
    
    // Efecto scanlines verticales
    float scanline = sin(gl_FragCoord.x * 0.5 + T * 2.0) * 0.5 + 0.5;
    float scan = step(0.7, scanline);
    
    // Esfera del planeta
    float r = length(pixUV);
    if(r > 0.45) {
        // Espacio estrellado
        float stars = step(0.98, hash(floor(uv * 200.0)));
        gl_FragColor = vec4(vec3(stars), 1.0);
        return;
    }
    
    // Coordenadas esfericas
    float ang = atan(pixUV.y, pixUV.x);
    float z = sqrt(0.45 * 0.45 - r * r);
    vec3 pos = normalize(vec3(pixUV, z));
    
    // Rotacion del planeta
    float rot = T;
    float x = pos.x * cos(rot) - pos.z * sin(rot);
    float z2 = pos.x * sin(rot) + pos.z * cos(rot);
    pos.x = x;
    pos.z = z2;
    
    // Generar continentes con ruido
    float noise = fbm(pos.xy * 3.0 + fbm(pos.yz * 2.0) * 0.5);
    noise += 0.3 * fbm(pos.xz * 5.0);
    
    // Sombreado simple
    float light = dot(pos, normalize(vec3(0.5, 0.3, 1.0)));
    light = light * 0.5 + 0.5;
    
    // Posterizar a colores limitados
    float levels = floor(noise * 6.0) / 6.0;
    vec3 col = palette(levels);
    
    // Aplicar sombra
    col *= light;
    
    // Scanlines verticales glitch
    float glitch = sin(pixUV.x * 20.0 + T * 3.0) * 0.5 + 0.5;
    if(glitch > 0.85) col = mix(col, col * 0.3, 0.5);
    
    // Dithering
    float dither = hash(pixUV * 100.0 + T);
    col += (dither - 0.5) * 0.05;
    
    // Borde atmosferico
    float rim = smoothstep(0.45, 0.4, r);
    col = mix(col * 0.2, col, rim);
    
    // Scanlines finales
    col *= (1.0 - scan * 0.15);
    
    gl_FragColor = vec4(col, 1.0);
}