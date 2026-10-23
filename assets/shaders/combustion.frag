#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uProgress; // 0.0 (unburned) to 1.0 (fully incinerated)
uniform float uTime;
uniform vec4 uFireColor; // Ember/Flame primary tint

out vec4 fragColor;

// Simplex/Perlin noise helper
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
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
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = rot * p * 2.0 + vec2(100.0);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution.xy;

    if (uProgress <= 0.001) {
        fragColor = vec4(0.0); // Transparent, let canvas pass through
        return;
    }

    // Organic burning front rising from bottom to top or radial outward
    vec2 nUv = uv * 6.0;
    nUv.y -= uTime * 0.8; // Moving flame drift
    float n = fbm(nUv);

    // Combustion threshold: sweeping diagonally upward
    float burnCoord = (1.0 - uv.y) * 0.7 + uv.x * 0.3 + n * 0.35;
    float threshold = uProgress * 1.5;

    if (burnCoord < threshold - 0.15) {
        // Fully burned to ash / void
        fragColor = vec4(0.0, 0.0, 0.0, 0.95 * min(1.0, (threshold - burnCoord) * 3.0));
    } else if (burnCoord < threshold) {
        // Active glowing ember front
        float edgeDist = (threshold - burnCoord) / 0.15;
        vec3 flameGlow = mix(vec3(1.0, 0.9, 0.3), vec3(1.0, 0.2, 0.02), edgeDist);
        fragColor = vec4(flameGlow, 1.0);
    } else {
        // Intact zone
        fragColor = vec4(0.0);
    }
}
