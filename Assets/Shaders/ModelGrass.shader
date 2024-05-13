Shader "Unlit/ModelGrass" {
    Properties {
        _Albedo1 ("Albedo 1", Color) = (1, 1, 1)
        _Albedo2 ("Albedo 2", Color) = (1, 1, 1)
        _AOColor ("Ambient Occlusion", Color) = (1, 1, 1)
        _TipColor ("Tip Color", Color) = (1, 1, 1)
        _WindStrength ("Wind Strength", Range(0.5, 50.0)) = 1
        _Length("Length", Range(0,2.0)) = 1
        _Scale("Scale", Range(0.1,3.0)) = 1
        _Stiffness("Stiffness", Range(0.0,1.0)) = 0.8
        _CullingBias ("Cull Bias", Range(0.1, 1.0)) = 0.5
    }
    

    SubShader {
        Cull Off
        Zwrite On

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma target 4.5

            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"
            #include "../Resources/Random.cginc"

            struct VertexData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            struct GrassData {
                float4 position;
                float2 uv;
            };

            sampler2D _WindTex;
            float4 _Albedo1, _Albedo2, _AOColor, _TipColor;
            StructuredBuffer<GrassData> positionBuffer;
            float _Rotation, _WindStrength, _CullingBias,_Length, _Scale, _Stiffness;
            float _Saturation;
            

            float4 RotateAroundXInDegrees (float4 vertex, float degrees) {
                float alpha = degrees * UNITY_PI / 180.0;
                float sina, cosa;
                sincos(alpha, sina, cosa);
                float2x2 m = float2x2(cosa, -sina, sina, cosa);
                return float4(mul(m, vertex.yz), vertex.xw).zxyw;
            }
            
            float4 RotateAroundYInDegrees (float4 vertex, float degrees) {
                float alpha = degrees * UNITY_PI / 180.0;
                float sina, cosa;
                sincos(alpha, sina, cosa);
                float2x2 m = float2x2(cosa, -sina, sina, cosa);
                return float4(mul(m, vertex.xz), vertex.yw).xzyw;
            }

            bool VertexIsBelowClipPlane(float3 p, int planeIndex, float bias) {
                float4 plane = unity_CameraWorldClipPlanes[planeIndex];

                return dot(float4(p, 1), plane) < bias;
            }   

            bool cullVertex(float3 p, float bias) {
                return VertexIsBelowClipPlane(p, 0, bias) ||
                        VertexIsBelowClipPlane(p, 1, bias) ||
                        VertexIsBelowClipPlane(p, 2, bias) ||
                        VertexIsBelowClipPlane(p, 3, -1.0f);
            }

            v2f vert (VertexData v, uint instanceID : SV_INSTANCEID) {
                v2f o;
                
                float idHash = randValue(instanceID);
                idHash = randValue(idHash * 100000);

                float4 animationDirection = float4(0.0f, 0.0f, 1.0f, 0.0f);
                animationDirection = normalize(RotateAroundYInDegrees(animationDirection, idHash * 180.0f));

                float4 localPosition = RotateAroundXInDegrees(v.vertex, 90.0f);
                localPosition = RotateAroundYInDegrees(localPosition, idHash * 90.0f);

                float4 grassPosition = positionBuffer[instanceID].position;
                float4 worldUV = float4(positionBuffer[instanceID].uv, 0, 0);
                
                float swayVariance = lerp(_Stiffness, 1.0, idHash);
                float movement = v.uv.y * v.uv.y * v.uv.y * tex2Dlod(_WindTex, worldUV).r;
                movement *= swayVariance;
                
                localPosition.x += movement * animationDirection.x;
                localPosition.z += movement * animationDirection.y;
                localPosition.y += _Length * v.uv.y * v.uv.y;
                
                float4 worldPosition = float4(grassPosition.xyz + localPosition, 1.0f);
                worldPosition.y *= (1.0f + positionBuffer[instanceID].position.w) * _Scale;
                
                o.vertex = UnityObjectToClipPos(worldPosition);
                o.uv = v.uv;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                float4 col = lerp(_Albedo1, _Albedo2, i.uv.y);
                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float ndotl = DotClamped(lightDir, normalize(float3(0, 1, 0)));
                float4 ao = lerp(_AOColor, 1.0f, i.uv.y);
                float4 tip = 0;//lerp(0.0f, _TipColor, i.uv.y * i.uv.y * i.uv.y);
                

                return((col + tip) * ndotl * ao);// + ((col + tip) * UNITY_LIGHTMODEL_AMBIENT * (1.0 - ndotl) * ao * 0.95f));
            }

            ENDCG
        }
    }
}
