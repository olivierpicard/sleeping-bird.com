//
//  Glow.metal
//  ArperBird
//
//  Shader helpers for the neon glow mockups. Currently one effect: a dither
//  pass that breaks the concentric banding a stack of Gaussian blurs leaves on
//  a dark surface — the single biggest "reads as digital, not light" tell.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Cheap hash → [0, 1). Good enough for dither noise; not for anything that
/// needs real randomness.
static float glowHash(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

/// Triangular-PDF dither. Adds ~±`amount` code values of noise, so the smooth
/// ramps between blur passes stop quantizing into visible rings and dissolve
/// into a continuous falloff instead. TPDF (the difference of two uniform
/// samples) decorrelates the noise from the signal, which is why it kills
/// banding cleanly rather than just adding grain.
///
/// Keyed on colour *magnitude*, not alpha: the banding lives in the faint bloom
/// tail, where alpha is near zero — so scaling by alpha (the obvious move) would
/// starve the dither exactly where it's needed. Instead we ride wherever there's
/// any light and gate off only the true void, so the background stays clean. The
/// gate keys on `rgb` so it behaves the same whether the layer arrives pre- or
/// un-multiplied (SwiftUI doesn't promise which).
///
/// - Parameter amount: dither strength in code values. ~1 ≈ ±1/255, the
///   physically-right amount for an 8-bit surface — near-invisible by design,
///   its whole job is to make bands *vanish*, not to add visible grain. Push it
///   into double digits only to confirm it's engaging (you'll see the grain),
///   then dial back to the lowest value where the rings are gone.
[[ stitchable ]] half4 glowDither(float2 pos, half4 color, float amount) {
    float n = glowHash(pos) - glowHash(pos + float2(37.0, 17.0)); // TPDF in (-1, 1)
    float light = max(color.r, max(color.g, color.b));
    float gate = saturate(light * 60.0); // ~0 in the void, 1 with any light
    half amp = half(n * amount * gate / 255.0);
    return half4(color.rgb + amp, color.a);
}
