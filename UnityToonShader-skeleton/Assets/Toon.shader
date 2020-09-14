Shader "Roystan/Toon"
{
	Properties
	{
		_Color("Color", Color) = (0.5, 0.65, 1, 1)
		_MainTex("Main Texture", 2D) = "white" {}

		[HDR]
		_AmbientColor("Ambient Color", Color) = (0.4, 0.4, 0.4, 1)//빛을 직접적으로 받지 않는 부분을 어떤 색으로 할것이냐

		[HDR]
		_SpecularColor("Specular Color", Color) = (0.9, 0.9, 0.9, 1)
		_Glossiness("Glossiness", Float) = 32

		[HDR]
		_RimColor("Rim Color", Color) = (1, 1, 1, 1)
		_RimAmount("Rim Amount", Range(0, 1)) = 0.716
		_RimThreshold("Rim Threshold", Range(0, 1)) = 0.1
	}
	SubShader
	{
		Tags
		{
			"LightMode" = "ForwardBase"
			"PassFlags" = "OnlyDirectional"
		}
		UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

			struct appdata
			{
				float4 vertex : POSITION;				
				float4 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 worldNormal : NORMAL;
				float3 viewDir : TEXCOORD1;
				SHADOW_COORDS(2)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

			float4 _Color;
			float4 _AmbientColor;

			float4 _SpecularColor;
			float _Glossiness;

			float4 _RimColor;
			float _RimAmount;
			float _RimThreshold;

			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.viewDir = WorldSpaceViewDir(v.vertex);
				TRANSFER_SHADOW(o)
				return o;
			}
			
			float2 MoreThanTwoBandsOfShading(float dotL)//두개 이상의 음영을 나타내는 방법(ramp texture을 사용)
			{
				return float2(1 - (dotL * 0.5 + 0.5), 0.5);//1 - (NdotL * 0.5 + 0.5)이 부분은 -1 ~ 1인 NdotL을 0~1로 변환 해 주는 부분이다(uv의 값은 0~1이기 때문)
				//이런식으로 NdotL을 적용해 리턴해서 uv에 받아줘서 적용하면 빛에 따라 NdotL의 값이 달라지기때문에 텍스쳐의 매핑이 빛에 따라 달라진다
			}

			float4 frag(v2f i) : SV_Target
			{
				float shadow = SHADOW_ATTENUATION(i);

				float3 normal = normalize(i.worldNormal);
				float NdotL = dot(_WorldSpaceLightPos0, normal);//빛의 법선과 오브젝트의 법선값을 내적해서 NdotL에 넣어준다
				//float lightIntensity = NdotL > 0 ? 1 : 0;//NdotL이 빛을 받는 중이면 1, 아니면 0으로 해서 극단적인 빛 반사를 나타 낼 수 있다
				float lightIntensity = smoothstep(0, 0.01, NdotL * shadow);//smoothstep(하한 값, 상한 값, 이 두 값 사이에 있을 것으로 예상되는 값) 하한, 상한 값을 벗어나면 각각 0 또는 1을 반환
				float4 light = lightIntensity * _LightColor0;
				//float2 uv = MoreThanTwoBandsOfShading(NdotL);
				//float4 sample = tex2D(_MainTex, uv);

				float3 viewDir = normalize(i.viewDir);
				float3 halfVector = normalize(_WorldSpaceLightPos0 + viewDir);
				float NdotH = dot(normal, halfVector);
				float specularIntensity = pow(NdotH * lightIntensity, _Glossiness * _Glossiness);
				float specularIntensitySmooth = smoothstep(0.005, 0.01, specularIntensity);
				float4 specular = _SpecularColor * specularIntensitySmooth;

				float4 rimDot = 1 - dot(normal, viewDir);// 1-는 반전의 의미
				float rimIntensity = rimDot * pow(NdotL, _RimThreshold);
				rimIntensity = smoothstep(_RimAmount - 0.01, _RimAmount + 0.01, rimIntensity);
				float4 rim = rimIntensity * _RimColor;//rim 이란 오브젝트 뒤에서 조명 비춰주는 의미(카메라에 안비춰지는 부분)

				float4 sample = tex2D(_MainTex, i.uv);

				return _Color * sample * (_AmbientColor + light + specular + rim);
			}
			ENDCG
		}
	}
}