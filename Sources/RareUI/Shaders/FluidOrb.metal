//
//  FluidOrb.metal
//  A transliteration of the fragment shader in upstream's
//  `components/ui/fluid-orb.tsx`, from GLSL to Metal.
//
//  Everything below is upstream's, line for line, with two changes forced by the move:
//
//  1. GLSL's gl_FragCoord counts up from the bottom of the frame and SwiftUI's position
//     counts down from the top, so the vertical coordinate is flipped once at the start.
//     After that the body reads exactly as the original does, including which way round
//     the gradient goes.
//
//  2. SwiftUI hands a shader premultiplied colour and expects premultiplied colour back,
//     which is what upstream's `vec4(col * edge, edge)` already is.
//

#include <metal_stdlib>
using namespace metal;

static float rareUIHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

// Value noise: a random number per lattice point, smoothed between them with the
// hermite curve f * f * (3 - 2f) rather than a straight ramp.
static float rareUINoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(rareUIHash(i + float2(0.0, 0.0)), rareUIHash(i + float2(1.0, 0.0)), u.x),
        mix(rareUIHash(i + float2(0.0, 1.0)), rareUIHash(i + float2(1.0, 1.0)), u.x),
        u.y
    );
}

// Three octaves, each half the amplitude and twice the frequency of the last. Three is
// enough to read as fluid and cheap enough to run every frame at any size.
static float rareUIFbm(float2 p) {
    float v = 0.0;
    float a = 0.6;
    for (int i = 0; i < 3; i++) {
        v += a * rareUINoise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

[[stitchable]] half4 rareUIFluidOrb(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    half4 tint
) {
    float2 uv = float2(position.x / size.x, 1.0 - position.y / size.y);
    float t = time * 0.22;

    // Two drifts of unrelated period, so the fluid never settles into a loop.
    float2 drift = float2(
        sin(t) + 0.6 * sin(t * 1.7 + 1.3),
        cos(t * 0.8) + 0.6 * cos(t * 1.3 + 2.1)
    );

    float2 p = float2(uv.x * 1.8, uv.y * 1.0) + drift * 0.7;

    // Domain warping: the noise is sampled at a position that is itself noise, which is
    // what turns a cloud into something that looks like it is being stirred.
    float2 q = float2(rareUIFbm(p + drift), rareUIFbm(p + float2(3.2, 1.5) - drift));
    float f = rareUIFbm(p + 1.2 * q);

    float g = clamp(1.0 - uv.y, 0.0, 1.0);
    // The warp is faded out toward the bottom of the orb, so the dark end stays anchored
    // rather than boiling.
    float anchor = smoothstep(0.0, 0.3, uv.y);
    float shade = clamp(g + (f - 0.5) * 0.8 * anchor, 0.0, 1.0);

    float3 white = float3(0.99, 1.0, 1.0);
    float3 light = mix(white, float3(tint.rgb), 0.5);
    float3 dark = float3(tint.rgb);

    float3 col = white;
    col = mix(col, light, smoothstep(0.28, 0.52, shade));
    col = mix(col, dark, smoothstep(0.58, 0.88, shade));

    // The edge is a single smoothstep across one hundredth of the radius, which is what
    // gives the orb an antialiased rim without a mask.
    float edge = smoothstep(0.5, 0.49, distance(uv, float2(0.5)));

    return half4(half3(col * edge), half(edge));
}
