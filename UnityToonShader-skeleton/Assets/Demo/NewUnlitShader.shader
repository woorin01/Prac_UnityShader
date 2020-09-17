Shader "Unlit/NewUnlitShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

        _Edge_Thres("Edge Thres", Range(0, 1)) = 0.2
        _Edge_Thres2("Edge Thres", Range(0, 10)) = 3.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

			float HueLevCount;
			float SatLevCount;
			float ValLevCount;

			float HueLevels[6];
			float SatLevels[7];
			float ValLevels[4];

			float textureSize;

            float edge_thres;
            float edge_thres2;

			float _Edge_Thres;
			float _Edge_Thres2;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            void SetArray()
            {
                HueLevCount = 6;
                SatLevCount = 7;
                ValLevCount = 4;

                HueLevels[0] = 0.0; HueLevels[1] = 140.0; HueLevels[2] = 160.0;
                HueLevels[3] = 240.0; HueLevels[4] = 240.0; HueLevels[5] = 360.0;

                SatLevels[0] = 0.0; SatLevels[1] = 0.15; SatLevels[2] = 0.3;
                SatLevels[3] = 0.45; SatLevels[4] = 0.6; SatLevels[5] = 0.8; SatLevels[6] = 1.0;

                ValLevels[0] = 0.0; ValLevels[1] = 0.3;
                ValLevels[2] = 0.6; ValLevels[3] = 1.0;

                edge_thres = 0.2;
                edge_thres2 = 5.0;

                textureSize = 512.0;
            }
			
			float3 RGBtoHSV(float r, float g, float b) 
            {
               float minv, maxv, delta;
               float3 res;
            
               minv = min(min(r, g), b);
               maxv = max(max(r, g), b);
               res.z = maxv;            // v
               
               delta = maxv - minv;
            
               if( maxv != 0.0 )
                  res.y = delta / maxv;      // s
               else {
                  // r = g = b = 0      // s = 0, v is undefined
                  res.y = 0.0;
                  res.x = -1.0;
                  return res;
               }
            
               if( r == maxv )
                  res.x = ( g - b ) / delta;      // between yellow & magenta
               else if( g == maxv )
                  res.x = 2.0 + ( b - r ) / delta;   // between cyan & yellow
               else
                  res.x = 4.0 + ( r - g ) / delta;   // between magenta & cyan
            
               res.x = res.x * 60.0;            // degrees
               if( res.x < 0.0 )
                  res.x = res.x + 360.0;
                  
               return res;
            }

            float3 HSVtoRGB(float h, float s, float v)
            {
                int i;
                float f, p, q, t;
                float3 res;

                if (s == 0.0)
                {
                    // achromatic (grey)
                    res.x = v;
                    res.y = v;
                    res.z = v;
                    return res;
                }

                h /= 60.0;         // sector 0 to 5
                i = int(floor(h));
                f = h - float(i);         // factorial part of h
                p = v * (1.0 - s);
                q = v * (1.0 - s * f);
                t = v * (1.0 - s * (1.0 - f));

                switch (i)
                {
                case 0:
                    res.x = v;
                    res.y = t;
                    res.z = p;
                    break;
                case 1:
                    res.x = q;
                    res.y = v;
                    res.z = p;
                    break;
                case 2:
                    res.x = p;
                    res.y = v;
                    res.z = t;
                    break;
                case 3:
                    res.x = p;
                    res.y = q;
                    res.z = v;
                    break;
                case 4:
                    res.x = t;
                    res.y = p;
                    res.z = v;
                    break;
                default:      // case 5:
                    res.x = v;
                    res.y = p;
                    res.z = q;
                    break;
                }
                return res;
            }

			//HueLevCount = 6, SatLevCount = 7, ValLevCount = 4
            float nearestLevel(float col, float mode) 
            {
               int levCount;
			   
               if (mode==0) levCount = HueLevCount;
               if (mode==1) levCount = SatLevCount;
               if (mode==2) levCount = ValLevCount;
               
               for (int i =0; i<levCount-1; i++ ) {
                 if (mode==0) {
                    if (col >= HueLevels[i] && col <= HueLevels[i+1]) {
                      return HueLevels[i+1];
                    }
                 }
                 if (mode==1) {
                    if (col >= SatLevels[i] && col <= SatLevels[i+1]) {
                      return SatLevels[i+1];
                    }
                 }
                 if (mode==2) {
                    if (col >= ValLevels[i] && col <= ValLevels[i+1]) {
                      return ValLevels[i+1];
                    }
                 }
               }

			   return 0.0;
            }

            float avg_intensity(float4 pix)
            {
                return (pix.r + pix.g + pix.b) / 3.;
            }

            float4 get_pixel(float2 coords, float dx, float dy)
            {
                return tex2D(_MainTex, coords + float2(dx, dy));
            }

            float IsEdge(in float2 coords)
            {
                float dxtex = 1.0 / textureSize;
                float dytex = 1.0 / textureSize;
                float pix[9];
                int k = -1;
                float delta;

                // read neighboring pixel intensities
                for (int i = -1; i < 2; i++) {
                    for (int j = -1; j < 2; j++) {
                        k++;
                        pix[k] = avg_intensity(get_pixel(coords, float(i) * dxtex,
                            float(j) * dytex));
                    }
                }

                // average color differences around neighboring pixels
                delta = (abs(pix[1] - pix[7]) +
                    abs(pix[5] - pix[3]) +
                    abs(pix[0] - pix[8]) +
                    abs(pix[2] - pix[6])
                    ) / 4.0;

                //return clamp(5.5*delta,0.0,1.0);
                return clamp(_Edge_Thres2 * delta, 0.0, 1.0);
            }

            float4 frag (v2f i) : SV_Target
            {
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);

				//
				float2 uv = i.uv.xy;
  				float4 tc = float4(1.0, 0.0, 0.0, 1.0);
                SetArray();
                
    			float3 colorOrg = tex2D(_MainTex, uv).rgb;
    			float3 vHSV =  RGBtoHSV(colorOrg.r,colorOrg.g,colorOrg.b);
    			vHSV.x = nearestLevel(vHSV.x, 0);
    			vHSV.y = nearestLevel(vHSV.y, 1);
    			vHSV.z = nearestLevel(vHSV.z, 2);
                
    			float edg = IsEdge(uv);
    			float3 vRGB = (edg >= _Edge_Thres) ? float3(0.0,0.0,0.0) : HSVtoRGB(vHSV.x,vHSV.y,vHSV.z);
    			tc = float4(vRGB.x,vRGB.y,vRGB.z, 1);  
				//
  
                return tc;
            }
            ENDCG
        }
    }
}
