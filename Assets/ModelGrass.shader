Shader "Unlit/ModelGrass" {
    Properties {
        _Albedo1 ("Albedo 1", Color) = (1, 1, 1, 1)
        _Albedo2 ("Albedo 2", Color) = (1, 1, 1, 1)
        _AOColor ("Ambient Occlusion", Color) = (1, 1, 1, 1)
        _TipColor ("Tip Color", Color) = (1, 1, 1, 1)
        _Scale("Scale", Range(0.1,3.0)) = 1
        _HeightVariance("Variance Scale", Range(0.0,3.0)) = 1
        _TipColStart("Tip Color Start", Range(0.0, 1.0)) = 0.4
        _Stiffness("Stiffness", Range(0.0,1.0)) = 0.8
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
                float saturationLevel : TEXCOORD1;
                float4 _ShadowCoord: TEXCOORD2;
            };
            
            struct GrassData {
                float4 position;
                float2 uv;
                float displacement;
            };

            sampler2D _WindTex;
            float4 _Albedo1, _Albedo2, _AOColor, _TipColor;
            StructuredBuffer<GrassData> positionBuffer;
            float _Scale, _HeightVariance, _Stiffness;
            sampler2D _CameraDepthTexture;

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

                // Get the UV to sample the wind texture
                float4 worldUV = float4(positionBuffer[instanceID].uv, 0, 0);

                // Move the local position of the vertex to animate
                float swayVariance = lerp(_Stiffness, 1.0, idHash);
                float movement = v.uv.y * v.uv.y * tex2Dlod(_WindTex, worldUV).r * _Scale;
                movement *= swayVariance;
                localPosition.x += movement * animationDirection.x;
                localPosition.z += movement * animationDirection.y;

                // Convert to world space
                float4 worldPosition = float4(grassPosition.xyz + localPosition, 1.0f);
                float variance = (positionBuffer[instanceID].position.w * _HeightVariance);
                worldPosition.y -= positionBuffer[instanceID].displacement;
                worldPosition.y *= (1.0f + variance) * _Scale;
                worldPosition.y += positionBuffer[instanceID].displacement;

                // Set Output
                o.pos = UnityObjectToClipPos(worldPosition);
                o.uv = v.uv;
                o.saturationLevel = positionBuffer[instanceID].position.w;

                o._ShadowCoord = ComputeScreenPos(o.pos);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                float4 col = lerp(_Albedo1, _Albedo2, i.saturationLevel);
                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float ndotl = saturate(dot(lightDir, normalize(float3(0, 1, 0))));
                
                float attenuation = SHADOW_ATTENUATION(i);
                
                col = lerp(_AOColor, col, attenuation);
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
            float4 _Albedo1, _Albedo2, _AOColor, _TipColor;
            StructuredBuffer<GrassData> positionBuffer;
            float _Scale, _HeightVariance, _Stiffness;

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

                // Get the world UV
                float4 worldUV = float4(positionBuffer[instanceID].uv, 0, 0);

                // Move the local position of the vertex to animate
                float swayVariance = lerp(0.5, 1.0, idHash) * _Stiffness;
                float movement = v.uv.y * v.uv.y * tex2Dlod(_WindTex, worldUV).r * _Scale;
                movement *= swayVariance;
                localPosition.x += movement * animationDirection.x;
                localPosition.z += movement * animationDirection.y;

                // Convert to world space
                float4 worldPosition = float4(grassPosition.xyz + localPosition, 1.0f);
                float variance = (positionBuffer[instanceID].position.w * _HeightVariance);
                worldPosition.y -= positionBuffer[instanceID].displacement;
                worldPosition.y *= (1.0f + variance) * _Scale;
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
