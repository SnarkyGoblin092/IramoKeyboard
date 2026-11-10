#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// The light / dark wave's lens (ModeWave.swift): around the wave's irregular front, what is under it is bent
// towards the front and split into its colours, the way light is at the edge of a thick lens, and darkened a
// little just inside it.

// The crests of the front (the same as ModeWave.crests): how many round the circle, how high, where they start
// and how far they travel round as the wave spreads.
constant float crestCount[5] = {2.0, 3.0, 5.0, 7.0, 11.0};
constant float crestHeight[5] = {0.110, 0.090, 0.060, 0.035, 0.020};
constant float crestPhase[5] = {0.4, 2.1, 4.0, 1.1, 5.3};
constant float crestDrift[5] = {1.7, -2.3, 3.1, -4.2, 5.0};

// The radius of the front at `angle` (ModeWave.radius).
static float frontRadius(float angle, float progress, float endRadius, float shift) {
    float swell = 1.0;
    for (int i = 0; i < 5; i++) {
        swell += crestHeight[i] * sin(crestCount[i] * angle + crestPhase[i] + shift + crestDrift[i] * progress);
    }
    return progress * endRadius * swell;
}

[[ stitchable ]] half4 waveLens(float2 position, SwiftUI::Layer layer, float2 center, float progress,
                                float endRadius, float shift, float reach, float strength) {
    if (progress <= 0.0 || progress >= 1.0) {
        return layer.sample(position);
    }
    float2 offset = position - center;
    float distance = length(offset);
    // Far from the front nothing is bent: those points (nearly all of them) are passed through before any of the
    // costly work. (The crests move the front by at most 31.5% of its radius; 2.2 reaches away the bend is under
    // the 1% it is cut off at below.)
    float front = progress * endRadius;
    float margin = reach * 2.2;
    if (distance < front * 0.685 - margin || distance > front * 1.315 + margin) {
        return layer.sample(position);
    }
    float2 direction = offset / max(distance, 0.001);
    // How far outside the front this point is (negative: inside).
    float signedDistance = distance - frontRadius(atan2(offset.y, offset.x), progress, endRadius, shift);
    float spread = reach;
    float scaled = signedDistance / spread;
    float profile = exp(-scaled * scaled);
    if (profile < 0.01) {
        return layer.sample(position);
    }
    // The bend: what is seen here is taken from nearer the front, more so the closer to it; the three colours
    // are taken from slightly different places.
    float bend = strength * profile;
    float2 toward = -direction * bend * sign(signedDistance + 0.001);
    half red = layer.sample(position + toward * 1.45).r;
    half4 middle = layer.sample(position + toward);
    half blue = layer.sample(position + toward * 0.55).b;
    half4 color = half4(red, middle.g, blue, middle.a);
    // A little darker just inside the front, as the thick edge of the glass would be.
    float sharp = signedDistance / (spread * 0.35);
    float edge = step(signedDistance, 0.0) * exp(-sharp * sharp);
    color.rgb *= half(1.0 - 0.28 * edge);
    return color;
}
