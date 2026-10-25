#version 460 core

#include <flutter/runtime_effect.glsl>

// Level-set burn front over a baked ignition-distance field.
//
// uField holds d(x): the time a flame takes to reach x, igniting at the end of
// the last stroke, running along the ink and creeping across paper. It is
// normalised to [0, 1] and packed as v = 256*R + G over 65535. The front is
//   phi(x, t) = d(x) + A * fbm(x, t) - front(t)
// Burned where phi < 0, an incandescent rim for 0 <= phi < band, untouched beyond.

uniform vec2 uSize;
uniform float uFront;
uniform float uBand;
uniform float uTime;
uniform float uSeed;
uniform vec4 uPaper;
uniform vec4 uBurn;
uniform float uDark; // 1 on dark paper, 0 on light paper
uniform sampler2D uField;

out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21) + uSeed);
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
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
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

// Blackbody-like ramp from char through deep red to the skin's burn colour and
// a pale incandescent core (roughly 1000 K to 1800 K).
vec3 blackbody(float t) {
    vec3 charColor = vec3(0.10, 0.06, 0.05);
    vec3 deepRed = vec3(0.55, 0.07, 0.02);
    vec3 core = vec3(1.0, 0.86, 0.58);
    if (t < 0.35) return mix(charColor, deepRed, t / 0.35);
    if (t < 0.75) return mix(deepRed, uBurn.rgb, (t - 0.35) / 0.4);
    return mix(uBurn.rgb, core, (t - 0.75) / 0.25);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec2 c = uv - 0.5;
    if (dot(c, c) > 0.25) {
        fragColor = vec4(0.0);
        return;
    }

    vec4 f = texture(uField, uv);
    float d = f.r * (65280.0 / 65535.0) + f.g * (255.0 / 65535.0);
    // Slow drift only: no luminance flicker above a few hertz.
    float n = fbm(uv * 9.0 + vec2(uSeed * 7.0, uTime * 0.18)) - 0.5;
    float phi = d + 0.16 * n - uFront;

    if (phi < 0.0) {
        // Consumed: bare paper with a scorch that cools away. On dark paper
        // the scorch darkens (a light tint would read as a glow).
        float scorch = clamp(1.0 + phi / (uBand * 2.0), 0.0, 1.0);
        vec3 light = mix(uPaper.rgb, vec3(0.30, 0.17, 0.10), 0.10 * scorch * scorch);
        vec3 dark = mix(uPaper.rgb, vec3(0.0), 0.25 * scorch);
        fragColor = vec4(mix(light, dark, uDark), 1.0);
        return;
    }
    if (phi < uBand) {
        float heat = 1.0 - phi / uBand;
        float a = smoothstep(0.0, 0.35, heat);
        // Dark paper: full blackbody ramp. Light paper: incandescence cannot be
        // brighter than white, so the edge is char-dominant (sumi to umber)
        // with a thin line of the skin's burn colour at the very front.
        vec3 charEdge = mix(vec3(0.08, 0.08, 0.09), vec3(0.35, 0.18, 0.10), smoothstep(0.0, 0.8, heat));
        vec3 lightCol = mix(charEdge, uBurn.rgb, smoothstep(0.82, 0.97, heat));
        vec3 col = mix(lightCol, blackbody(heat), uDark);
        fragColor = vec4(col * a, a);
        return;
    }
    fragColor = vec4(0.0);
}
