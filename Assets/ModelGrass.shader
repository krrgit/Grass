Shader "Unlit/ModelGrass" {
    Properties {
        _ShimmerColor ("Shimmer Color", Color) = (1, 1, 1, 1)
        _ShadowColor ("Shadow Color", Color) = (1, 1, 1, 1)
        _Width("Width", Range(0.1,3.0)) = 1
        _Length("Length", Range(0.1,3.0)) = 1
        _HeightVariance("Variance Scale", Range(0.0,5.0)) = 1
        _ShimmerIntensity("Shimmer Intensity", Range(0.0, 1.0)) = 0.4
        _SwayVariance("Sway Variance", Range(0.0,1.0)) = 0.8
        _CullingBias ("Cull Bias", Range(0.1, 1.0)) = 0.5
        _LODCutoff ("LOD Cutoff", Range(10.0, 500.0)) = 100
    }

    SubShader {


        Pass {
            Tags {
                "RenderType" = "Opaque"
                "LightMode" = "ForwardBase"
            }
            ZWrite On
            ZTest LEqual
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma target 4.5
            #pragma multi_compile_fwdbase
            
            #include "UnityPBSLighting.cginc"
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Random.cginc"

            struct VertexData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 _ShadowCoord: TEXCOORD1;
                float4 worldUV : TEXCOOORD2;
                float tipShimmer: TEXCOORD3;
            };
            
            struct GrassData {
                float4 position;
                float2 uv;
                float displacement;
            };

            sampler2D _WindTex;
            sampler2D _TerrainTex;
            float4 _ShadowColor, _ShimmerColor;
            StructuredBuffer<GrassData> positionBuffer;
            float _Width, _Length, _HeightVariance, _SwayVariance, _ShimmerIntensity;

            float4 RotateAroundYInDegrees(float4 vertex, float degrees) {
                float alpha = degrees * UNITY_PI / 180.0;
                float sina, cosa;
                sincos(alpha, sina, cosa);
                float2x2 m = float2x2(cosa, -sina, sina, cosa);
                return float4(mul(m, vertex.xz), vertex.yw).xzyw;
            }
            
            float4 RotateAroundXInDegrees(float4 vertex, float degrees) {
                float alpha = degrees * UNITY_PI / 180.0;
                float sina, cosa;
                sincos(alpha, sina, cosa);
                float2x2 m = float2x2(cosa, -sina, sina, cosa);
                return float4(mul(m, vertex.yz), vertex.xw).zxyw;
            }

            v2f vert(VertexData v, uint instanceID : SV_INSTANCEID) {
                v2f o;
                
                // Get Position from StructuredBuffer
                float4 grassPosition = positionBuffer[instanceID].position;

                // Generate hash from position
                float idHash = randValue(abs(grassPosition.x * 10000 + grassPosition.y * 100 + grassPosition.z * 0.05f + 2));
                idHash = randValue(idHash * 100000);

                // Animation Direction
                float4 animationDirection = float4(0.0f, 0.0f, 1.0f, 0.0f);
                animationDirection = normalize(RotateAroundYInDegrees(animationDirection, idHash * 180.0f));

                // Rotate the vertex locally
                float4 localPosition = RotateAroundXInDegrees(v.vertex, 90.0f);
                localPosition = RotateAroundYInDegrees(localPosition, idHash * 90.0f);
                localPosition.xz *= _Width;
                
                // Get the UV to sample the wind texture
                float4 worldUV = float4(positionBuffer[instanceID].uv, 0, 0);

                // Move the local position of the vertex to animate
                float swayVariance = lerp(0.4f, 0.9f, idHash) * _SwayVariance;
                float movement = v.uv.y * v.uv.y * tex2Dlod(_WindTex, worldUV).r * _Length;
                movement *= swayVariance;
                localPosition.x += movement * animationDirection.x;
                localPosition.z += movement * animationDirection.y;

                // Convert to world space + add height
                float4 worldPosition = float4(grassPosition.xyz + localPosition, 1.0f);
                float variance = positionBuffer[instanceID].position.w * _HeightVariance;
                worldPosition.y -= positionBuffer[instanceID].displacement;
                worldPosition.y *= (1.0f + variance) * _Length;
                worldPosition.y += positionBuffer[instanceID].displacement;

                o.tipShimmer = max(0.0f,tex2Dlod(_WindTex, worldUV).r);

                // Set Output
                o.pos = UnityObjectToClipPos(worldPosition);
                o.uv = v.uv;

                o.worldUV = worldUV;
                o._ShadowCoord = ComputeScreenPos(o.pos);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                float4 col = tex2Dlod(_TerrainTex, i.worldUV);
                // col = pow(col, 1.5f);

                // Main Light
                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float ndotl = saturate(dot(lightDir, normalize(float3(0, 1, 0))));

                // Color the tips
                col = lerp(col, _ShimmerColor, i.uv.y * i.uv.y * i.uv.y * i.uv.y * i.tipShimmer * _ShimmerIntensity);
                
                // Color the shadows
                float attenuation = SHADOW_ATTENUATION(i);
                col = lerp(_ShadowColor, col, attenuation);
                
                return (col) * ndotl;
            }
            ENDCG
        }
//Shadow caster pass    
        Pass {
            Name "ShadowCaster"
            Tags { 
                "LightMode" = "ShadowCaster"
            }
            ZWrite On
            ColorMask 0
            LOD 100
            ZTest LEqual
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma target 4.5
            #pragma multi_compile_shadowcaster
            
            #include "UnityPBSLighting.cginc"
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Random.cginc"

            struct VertexData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct GrassData {
                float4 position;
                float2 uv;
                float displacement;
            };

            sampler2D _WindTex;
            StructuredBuffer<GrassData> positionBuffer;
            float _Width, _Length, _HeightVariance, _SwayVariance;

            float4 RotateAroundYInDegrees(float4 vertex, float degrees) {
                float alpha = degrees * UNITY_PI / 180.0;
                float sina, cosa;
                sincos(alpha, sina, cosa);
                float2x2 m = float2x2(cosa, -sina, sina, cosa);
                return float4(mul(m, vertex.xz), vertex.yw).xzyw;
            }
            
            float4 RotateAroundXInDegrees(float4 vertex, float degrees) {
                float alpha = degrees * UNITY_PI / 180.0;
                float sina, cosa;
                sincos(alpha, sina, cosa);
                float2x2 m = float2x2(cosa, -sina, sina, cosa);
                return float4(mul(m, vertex.yz), vertex.xw).zxyw;
            }

            v2f vert(VertexData v, uint instanceID : SV_INSTANCEID) {
                v2f o;
                                
                // Get Position from StructuredBuffer
                float4 grassPosition = positionBuffer[instanceID].position;

                // Generate hash from position
                float idHash = randValue(abs(grassPosition.x * 10000 + grassPosition.y * 100 + grassPosition.z * 0.05f + 2));
                idHash = randValue(idHash * 100000);

                // Animation Direction
                float4 animationDirection = float4(0.0f, 0.0f, 1.0f, 0.0f);
                animationDirection = normalize(RotateAroundYInDegrees(animationDirection, idHash * 180.0f));

                // Rotate the vertex locally
                float4 localPosition = RotateAroundXInDegrees(v.vertex, 90.0f);
                localPosition = RotateAroundYInDegrees(localPosition, idHash * 90.0f);
                localPosition.xz *= _Width;
                
                // Get the UV to sample the wind texture
                float4 worldUV = float4(positionBuffer[instanceID].uv, 0, 0);

                // Move the local position of the vertex to animate
                float swayVariance = lerp(0.4f, 0.9f, idHash) * _SwayVariance;
                float movement = v.uv.y * v.uv.y * tex2Dlod(_WindTex, worldUV).r * _Length;
                movement *= swayVariance;
                localPosition.x += movement * animationDirection.x;
                localPosition.z += movement * animationDirection.y;

                // Convert to world space + add height
                float4 worldPosition = float4(grassPosition.xyz + localPosition, 1.0f);
                float variance = positionBuffer[instanceID].position.w * _HeightVariance;
                worldPosition.y -= positionBuffer[instanceID].displacement;
                worldPosition.y *= (1.0f + variance) * _Length;
                worldPosition.y += positionBuffer[instanceID].displacement;

                // Set Output
                o.pos = UnityObjectToClipPos(worldPosition);
                o.uv = v.uv;
                
                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                // Discard if writing to the shadow pass.
                // Dont discard if writing to the depth pass.
                // https://forum.unity.com/threads/receive-shadows-but-dont-cast-any.406822/
                if (unity_LightShadowBias.z != 0.0) discard;
                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
       }
    }
}
