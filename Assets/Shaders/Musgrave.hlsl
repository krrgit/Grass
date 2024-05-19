// MusgraveNoise.hlsl
#ifndef MUSGRAVENOISE_HLSL
#define MUSGRAVENOISE_HLSL

float fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float mix(float v0, float v1, float x) {
    return (1 - x) * v0 + x * v1;
}

float noise_scale4(float result) {
    return 0.8344 * result;
}

float negate_if(float value, uint condition) {
    return (condition != 0u) ? -value : value;
}

float noise_grad(uint hash, float x, float y, float z, float w) {
    uint h = hash & 31u;
    float u = h < 24u ? x : y;
    float v = h < 16u ? y : z;
    float s = h < 8u ? z : w;
    return negate_if(u, h & 1u) + negate_if(v, h & 2u) + negate_if(s, h & 4u);
}

float noise_perlin(float4 vec) {
    int X = int(floor(vec.x));
    int Y = int(floor(vec.y));
    int Z = int(floor(vec.z));
    int W = int(floor(vec.w));

    float fx = frac(vec.x);
    float fy = frac(vec.y);
    float fz = frac(vec.z);
    float fw = frac(vec.w);

    float u = fade(fx);
    float v = fade(fy);
    float t = fade(fz);
    float s = fade(fw);

    float r = mix(
        mix(
            mix(
                mix(noise_grad(X + Y + Z + W, fx, fy, fz, fw), noise_grad(X + 1 + Y + Z + W, fx - 1, fy, fz, fw), u),
                mix(noise_grad(X + Y + 1 + Z + W, fx, fy - 1, fz, fw), noise_grad(X + 1 + Y + 1 + Z + W, fx - 1, fy - 1, fz, fw), u),
                v),
            mix(
                mix(noise_grad(X + Y + Z + 1 + W, fx, fy, fz - 1, fw), noise_grad(X + 1 + Y + Z + 1 + W, fx - 1, fy, fz - 1, fw), u),
                mix(noise_grad(X + Y + 1 + Z + 1 + W, fx, fy - 1, fz - 1, fw), noise_grad(X + 1 + Y + 1 + Z + 1 + W, fx - 1, fy - 1, fz - 1, fw), u),
                v),
            t),
        mix(
            mix(
                mix(noise_grad(X + Y + Z + W + 1, fx, fy, fz, fw - 1), noise_grad(X + 1 + Y + Z + W + 1, fx - 1, fy, fz, fw - 1), u),
                mix(noise_grad(X + Y + 1 + Z + W + 1, fx, fy - 1, fz, fw - 1), noise_grad(X + 1 + Y + 1 + Z + W + 1, fx - 1, fy - 1, fz, fw - 1), u),
                v),
            mix(
                mix(noise_grad(X + Y + Z + 1 + W + 1, fx, fy, fz - 1, fw - 1), noise_grad(X + 1 + Y + Z + 1 + W + 1, fx - 1, fy, fz - 1, fw - 1), u),
                mix(noise_grad(X + Y + 1 + Z + 1 + W + 1, fx, fy - 1, fz - 1, fw - 1), noise_grad(X + 1 + Y + 1 + Z + 1 + W + 1, fx - 1, fy - 1, fz - 1, fw - 1), u),
                v),
            t),
        s);

    return noise_scale4(r);
}

void node_tex_musgrave_fBm_4d_half(float4 co, float scale, float detail, float dimension, float lacunarity, out float value) {
    float4 p = co * scale;
    float H = max(dimension, 1e-5);
    float octaves = clamp(detail, 0.0, 15.0);
    float lac = max(lacunarity, 1e-5);

    value = 0.0;
    float pwr = 1.0;
    float pwHL = pow(lac, -H);

    for (int i = 0; i < int(octaves); i++) {
        value += noise_perlin(p) * pwr;
        pwr *= pwHL;
        p *= lac;
    }

    float rmd = octaves - floor(octaves);
    if (rmd != 0.0) {
        value += rmd * noise_perlin(p) * pwr;
    }
}

void TestFn_half(out float value)
{
    value = 1;
}

#endif
