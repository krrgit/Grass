
// This is directly copied from Blender (thank you open source <3)
// E.g.:
// - https://github.com/blender/blender/blob/9c0bffcc89f174f160805de042b00ae7c201c40b/source/blender/gpu/shaders/material/gpu_shader_material_noise.glsl#L196
// - https://github.com/blender/blender/blob/9c0bffcc89f174f160805de042b00ae7c201c40b/source/blender/gpu/shaders/material/gpu_shader_material_tex_musgrave.glsl#L692C39-L692C39
// 
// As such this file has a GPL / copy-left license
#define uint32_t uint

float fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}
 
#define rot(x, k) (((x) << (k)) | ((x) >> (32 - (k))))
 
// We can't do the above mix define, so I took this from:
// https://github.com/blender/blender/blob/9c0bffcc89f174f160805de042b00ae7c201c40b/source/blender/blenlib/intern/noise.cc#L254
float mix(float v0, float v1, float x) {
  return (1 - x) * v0 + x * v1;
}
 
#define final(a, b, c) \
  { \
    c ^= b; \
    c -= rot(b, 14); \
    a ^= c; \
    a -= rot(c, 11); \
    b ^= a; \
    b -= rot(a, 25); \
    c ^= b; \
    c -= rot(b, 16); \
    a ^= c; \
    a -= rot(c, 4); \
    b ^= a; \
    b -= rot(a, 14); \
    c ^= b; \
    c -= rot(b, 24); \
  }
 
#define FLOORFRAC(x, x_int, x_fract) { float x_floor = floor(x); x_int = int(x_floor); x_fract = x - x_floor; }
 
uint hash_uint4(uint kx, uint ky, uint kz, uint kw) {
    uint a, b, c;
    a = b = c = 0xdeadbeefu + (4u << 2u) + 13u;
 
    a += kx;
    b += ky;
    c += kz;
    mix(a, b, c);
 
    a += kw;
    final(a, b, c);
 
    return c;
}
 
uint hash_int4(int kx, int ky, int kz, int kw) {
    return hash_uint4(uint(kx), uint(ky), uint(kz), uint(kw));
}
 
float negate_if(float value, uint condition) {
    return (condition != 0u) ? -value : value;
}
 
float tri_mix(
    float v0,
    float v1,
    float v2,
    float v3,
    float v4,
    float v5,
    float v6,
    float v7,
    float x,
    float y,
    float z
) {
    float x1 = 1.0 - x;
    float y1 = 1.0 - y;
    float z1 = 1.0 - z;
    return z1 * (y1 * (v0 * x1 + v1 * x) + y * (v2 * x1 + v3 * x)) +
         z * (y1 * (v4 * x1 + v5 * x) + y * (v6 * x1 + v7 * x));
}
 
float quad_mix(
    float v0,
    float v1,
    float v2,
    float v3,
    float v4,
    float v5,
    float v6,
    float v7,
    float v8,
    float v9,
    float v10,
    float v11,
    float v12,
    float v13,
    float v14,
    float v15,
    float x,
    float y,
    float z,
    float w
) {
    return mix(
        tri_mix(v0, v1, v2, v3, v4, v5, v6, v7, x, y, z),
        tri_mix(v8, v9, v10, v11, v12, v13, v14, v15, x, y, z),
        w
    );
}
 
float noise_scale4(float result) {
    return 0.8344 * result;
}

float noise_grad(uint32_t hash, float x, float y, float z)
{
    uint32_t h = hash & 15u;
    float u = h < 8u ? x : y;
    float vt = (h == 12u || h == 14u) ? x : z;
    float v = h < 4u ? y : vt;
    return negate_if(u, h & 1u) + negate_if(v, h & 2u);
}
 
float noise_grad(uint hash, float x, float y, float z, float w) {
    uint h = hash & 31u;
    float u = h < 24u ? x : y;
    float v = h < 16u ? y : z;
    float s = h < 8u ? z : w;
    return negate_if(u, h & 1u) + negate_if(v, h & 2u) + negate_if(s, h & 4u);
}
 
float noise_perlin(float4 vec) {
    int X, Y, Z, W;
    float fx, fy, fz, fw;
 
    FLOORFRAC(vec.x, X, fx);
    FLOORFRAC(vec.y, Y, fy);
    FLOORFRAC(vec.z, Z, fz);
    FLOORFRAC(vec.w, W, fw);
 
    float u = fade(fx);
    float v = fade(fy);
    float t = fade(fz);
    float s = fade(fw);
 
    float r = quad_mix(
      noise_grad(hash_int4(X, Y, Z, W), fx, fy, fz, fw),
      noise_grad(hash_int4(X + 1, Y, Z, W), fx - 1.0, fy, fz, fw),
      noise_grad(hash_int4(X, Y + 1, Z, W), fx, fy - 1.0, fz, fw),
      noise_grad(hash_int4(X + 1, Y + 1, Z, W), fx - 1.0, fy - 1.0, fz, fw),
      noise_grad(hash_int4(X, Y, Z + 1, W), fx, fy, fz - 1.0, fw),
    // float offset,
    // float gain,
      noise_grad(hash_int4(X + 1, Y, Z + 1, W), fx - 1.0, fy, fz - 1.0, fw),
      noise_grad(hash_int4(X, Y + 1, Z + 1, W), fx, fy - 1.0, fz - 1.0, fw),
      noise_grad(hash_int4(X + 1, Y + 1, Z + 1, W), fx - 1.0, fy - 1.0, fz - 1.0, fw),
      noise_grad(hash_int4(X, Y, Z, W + 1), fx, fy, fz, fw - 1.0),
      noise_grad(hash_int4(X + 1, Y, Z, W + 1), fx - 1.0, fy, fz, fw - 1.0),
      noise_grad(hash_int4(X, Y + 1, Z, W + 1), fx, fy - 1.0, fz, fw - 1.0),
      noise_grad(hash_int4(X + 1, Y + 1, Z, W + 1), fx - 1.0, fy - 1.0, fz, fw - 1.0),
      noise_grad(hash_int4(X, Y, Z + 1, W + 1), fx, fy, fz - 1.0, fw - 1.0),
      noise_grad(hash_int4(X + 1, Y, Z + 1, W + 1), fx - 1.0, fy, fz - 1.0, fw - 1.0),
      noise_grad(hash_int4(X, Y + 1, Z + 1, W + 1), fx, fy - 1.0, fz - 1.0, fw - 1.0),
      noise_grad(hash_int4(X + 1, Y + 1, Z + 1, W + 1), fx - 1.0, fy - 1.0, fz - 1.0, fw - 1.0),
      u,
      v,
      t,
      s
    );
 
    return r;
}
 
float snoise(float4 p) {
    float r = noise_perlin(p);
    return (isinf(r)) ? 0.0 : noise_scale4(r);
}

struct ff_result
{
    float x;
    int i;
};

ff_result floor_fraction(float x)
{
    ff_result result;
    float x_floor = floor(x);
    result.x = x - x_floor;
    result.i = int(x_floor);
    return result;
}

uint32_t hash_bit_rotate(uint32_t x, uint32_t k)
{
    return (x << k) | (x >> (32 - k));
}

uint32_t hash_bit_final(uint32_t a, uint32_t b, uint32_t c)
{
    c ^= b;
    c -= hash_bit_rotate(b, 14);
    a ^= c;
    a -= hash_bit_rotate(c, 11);
    b ^= a;
    b -= hash_bit_rotate(a, 25);
    c ^= b;
    c -= hash_bit_rotate(b, 16);
    a ^= c;
    a -= hash_bit_rotate(c, 4);
    b ^= a;
    b -= hash_bit_rotate(a, 14);
    c ^= b;
    c -= hash_bit_rotate(b, 24);
    
    return c;
}

uint32_t hash(uint32_t kx, uint32_t ky)
{
    uint32_t a, b, c;
    a = b = c = 0xdeadbeef + (2 << 2) + 13;

    b += ky;
    a += kx;
    c = hash_bit_final(a, b, c);

    return c;
}


uint32_t hash(uint32_t kx, uint32_t ky, uint32_t kz)
{
    uint32_t a, b, c;
    a = b = c = 0xdeadbeef + (3 << 2) + 13;

    c += kz;
    b += ky;
    a += kx;
   
    c = hash_bit_final(a, b, c);

    return c;
}

float perlin_noise(float3 position)
{
    ff_result ffx = floor_fraction(position.x);
    ff_result ffy = floor_fraction(position.y);
    ff_result ffz = floor_fraction(position.z);

    int X = ffx.i;
    int Y = ffy.i;
    int Z = ffz.i;

    float fx = ffx.x;
    float fy = ffy.x;
    float fz = ffz.x;

    float u = fade(fx);
    float v = fade(fy);
    float w = fade(fz);

    float r = tri_mix(noise_grad(hash(X, Y, Z), fx, fy, fz),
                  noise_grad(hash(X + 1, Y, Z), fx - 1, fy, fz),
                  noise_grad(hash(X, Y + 1, Z), fx, fy - 1, fz),
                  noise_grad(hash(X + 1, Y + 1, Z), fx - 1, fy - 1, fz),
                  noise_grad(hash(X, Y, Z + 1), fx, fy, fz - 1),
                  noise_grad(hash(X + 1, Y, Z + 1), fx - 1, fy, fz - 1),
                  noise_grad(hash(X, Y + 1, Z + 1), fx, fy - 1, fz - 1),
                  noise_grad(hash(X + 1, Y + 1, Z + 1), fx - 1, fy - 1, fz - 1),
                  u,
                  v,
                  w);

    return r;
}

float perlin_signed(float3 position)
{
    /* Repeat Perlin noise texture every 100000.0f on each axis to prevent floating point
     * representation issues. This causes discontinuities every 100000.0f, however at such scales
     * this usually shouldn't be noticeable. */
    position = position % 100000.0f;

    return perlin_noise(position) * 0.9820f;
}

float uint_to_float_01(uint32_t k)
{
    return float(k) / float(0xFFFFFFFFu);
}


uint32_t float_as_uint(float f)
{
    // union {
    //     uint32_t i;
    //     float f;
    // } u;
    // u.f = f;
    // return u.i;
    return asuint(f);
}

uint32_t hash_float(float2 k)
{
    return hash(float_as_uint(k.x), float_as_uint(k.y));
}

float hash_float_to_float(float2 k)
{
    return uint_to_float_01(hash_float(k));
}

float3 random_float3_offset(float seed)
{
    return float3(100.0f + hash_float_to_float(float2(seed, 0.0f)) * 100.0f,
                  100.0f + hash_float_to_float(float2(seed, 1.0f)) * 100.0f,
                  100.0f + hash_float_to_float(float2(seed, 2.0f)) * 100.0f);
}

float3 perlin_distortion(float3 position, float strength)
{
    return float3(perlin_signed(position + random_float3_offset(0.0f)) * strength,
                  perlin_signed(position + random_float3_offset(1.0f)) * strength,
                  perlin_signed(position + random_float3_offset(2.0f)) * strength);
}


float perlin_float3_multi_fractal(float3 p, const float detail, const float roughness, const float lacunarity)
{
    float value = 1.0f;
    float pwr = 1.0f;

    for (int i = 0; i <= int(detail); i++) {
        value *= (pwr * perlin_signed(p) + 1.0f);
        pwr *= roughness;
        p *= lacunarity;
    }

    const float rmd = detail - floor(detail);
    if (rmd != 0.0f) {
        value *= (rmd * pwr * perlin_signed(p) + 1.0f); /* correct? */
    }

    return value;
}

float3 perlin_float3_fractal_distorted(float3 position,
                                       float detail,
                                       float roughness,
                                       float lacunarity,
                                       float distortion)
{
    position += perlin_distortion(position, distortion);
    return float3(perlin_float3_multi_fractal(
                      position, detail, roughness, lacunarity),
                  perlin_float3_multi_fractal(position + random_float3_offset(3.0f),
                                        detail,
                                        roughness,
                                        lacunarity),
                  perlin_float3_multi_fractal(position + random_float3_offset(4.0f),
                                        detail,
                                        roughness,
                                        lacunarity));
}

void NoiseTexture_float(float3 position,
float detail,
float roughness,
float lacunarity,
float distortion,
out float Out)
{
    Out =  perlin_float3_fractal_distorted(position,detail,roughness,lacunarity,distortion);
}

void NoiseTexture_half(float3 position,
float detail,
float roughness,
float lacunarity,
float distortion,
out float Out)
{
    Out =  perlin_float3_fractal_distorted(position,detail,roughness,lacunarity,distortion);
}