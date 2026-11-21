#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// The light / dark wave's lens (ModeWave.swift): around the wave's irregular front, what is under it is bent
// towards the front and split into its colours, the way light is at the edge of a thick lens, and darkened a
// little just inside it.

// The radius of the front at `angle` (ModeWave.radius). Every wave has its own crests (ModeWave.makeCrests),
// six numbers each: how many round the circle, how high at most, where it starts, how far it travels round as the
// wave spreads, and how fast and from where its height swells and ebbs.
static float frontRadius(float angle, float progress, float endRadius, device const float *crests, int count) {
    float swell = 1.0;
    for (int i = 0; i + 5 < count; i += 6) {
        float height = crests[i + 1] * (0.65 + 0.35 * sin(crests[i + 4] * progress + crests[i + 5]));
        swell += height * sin(crests[i] * angle + crests[i + 2] + crests[i + 3] * progress);
    }
    return progress * endRadius * swell;
}

[[ stitchable ]] half4 waveLens(float2 position, SwiftUI::Layer layer, float2 center, float progress,
                                float endRadius, float reach, float strength,
                                device const float *crests, int crestCount) {
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
    float signedDistance = distance - frontRadius(atan2(offset.y, offset.x), progress, endRadius, crests, crestCount);
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
