// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X
Shader "Procedural Worlds/Simple Water LW"
{
    Properties
    {
		_GlobalTiling("Global Tiling", Range( 0 , 32768)) = 50
		_WaveSpeed("Wave Speed", Vector) = (-0.04,0.045,0,0)
		_SurfaceOpacity("Surface Opacity", Range( 0 , 1)) = 1
		_WaterNormal("Water Normal", 2D) = "white" {}
		_NormalScale("Normal Scale", Range( 0.025 , 2)) = 0.4
		_SurfaceColor("Surface Color", Color) = (0.4329584,0.5616246,0.6691177,1)
		_SurfaceColorBlend("Surface Color Blend", Range( 0 , 1)) = 0.9
		_WaterSpecular("Water Specular", Range( 0 , 1)) = 0.1
		_WaterSmoothness("Water Smoothness", Range( 0 , 1)) = 0.9
		_Distortion("Distortion", Range( 0 , 2)) = 0.2
		_FoamMap("Foam Map", 2D) = "white" {}
		_FoamTint("Foam Tint", Color) = (1,1,1,0)
		_FoamOpacity("Foam Opacity", Range( 0 , 1)) = 1
    }

    SubShader
    {
        Tags { "RenderPipeline"="LightweightPipeline" "RenderType"="Transparent" "Queue"="Transparent" }

		Cull Off
		HLSLINCLUDE
		#pragma target 3.0
		ENDHLSL

        Pass
        {

        	Tags { "LightMode"="LightweightForward" }

        	Name "Base"
			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite On
			ZTest LEqual
			Offset 0 , 0
			ColorMask RGBA

        	HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x


        	// -------------------------------------
            // Lightweight Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

        	// -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex vert
        	#pragma fragment frag

        	#define REQUIRE_OPAQUE_TEXTURE 1
        	#define _NORMALMAP 1


        	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        	#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
        	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

            CBUFFER_START(UnityPerMaterial)
			sampler2D _WaterNormal;
			float _NormalScale;
			float2 _WaveSpeed;
			float _GlobalTiling;
			float _Distortion;
			uniform sampler2D _CameraDepthTexture;
			float _SurfaceOpacity;
			float4 _SurfaceColor;
			float _SurfaceColorBlend;
			float4 _FoamTint;
			sampler2D _FoamMap;
			float _FoamOpacity;
			samplerCUBE SkyboxReflection;
			float _WaterSpecular;
			float _WaterSmoothness;
			CBUFFER_END

			inline float4 ASE_ComputeGrabScreenPos( float4 pos )
			{
				#if UNITY_UV_STARTS_AT_TOP
				float scale = -1.0;
				#else
				float scale = 1.0;
				#endif
				float4 o = pos;
				o.y = pos.w * 0.5f;
				o.y = ( pos.y - o.y ) * _ProjectionParams.x * scale + o.y;
				return o;
			}


            struct GraphVertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;
                float4 ase_tangent : TANGENT;
                float4 texcoord1 : TEXCOORD1;
				float4 ase_texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

        	struct GraphVertexOutput
            {
                float4 clipPos                : SV_POSITION;
                float4 lightmapUVOrVertexSH	  : TEXCOORD0;
        		half4 fogFactorAndVertexLight : TEXCOORD1; // x: fogFactor, yzw: vertex light
            	float4 shadowCoord            : TEXCOORD2;
				float4 tSpace0					: TEXCOORD3;
				float4 tSpace1					: TEXCOORD4;
				float4 tSpace2					: TEXCOORD5;
				float4 ase_texcoord7 : TEXCOORD7;
				float4 ase_texcoord8 : TEXCOORD8;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            	UNITY_VERTEX_OUTPUT_STEREO
            };


            GraphVertexOutput vert (GraphVertexInput v)
        	{
        		GraphVertexOutput o = (GraphVertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(v);
            	UNITY_TRANSFER_INSTANCE_ID(v, o);
        		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float4 ase_clipPos = TransformObjectToHClip((v.vertex).xyz);
				float4 screenPos = ComputeScreenPos(ase_clipPos);
				o.ase_texcoord7 = screenPos;

				o.ase_texcoord8.xy = v.ase_texcoord.xy;

				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord8.zw = 0;
				v.vertex.xyz +=  float3( 0, 0, 0 ) ;
				v.ase_normal =  v.ase_normal ;

        		// Vertex shader outputs defined by graph
                float3 lwWNormal = TransformObjectToWorldNormal(v.ase_normal);
				float3 lwWorldPos = TransformObjectToWorld(v.vertex.xyz);
				float3 lwWTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
				float3 lwWBinormal = normalize(cross(lwWNormal, lwWTangent) * v.ase_tangent.w);
				o.tSpace0 = float4(lwWTangent.x, lwWBinormal.x, lwWNormal.x, lwWorldPos.x);
				o.tSpace1 = float4(lwWTangent.y, lwWBinormal.y, lwWNormal.y, lwWorldPos.y);
				o.tSpace2 = float4(lwWTangent.z, lwWBinormal.z, lwWNormal.z, lwWorldPos.z);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);

         		// We either sample GI from lightmap or SH.
        	    // Lightmap UV and vertex SH coefficients use the same interpolator ("float2 lightmapUV" for lightmap or "half3 vertexSH" for SH)
                // see DECLARE_LIGHTMAP_OR_SH macro.
        	    // The following funcions initialize the correct variable with correct data
        	    OUTPUT_LIGHTMAP_UV(v.texcoord1, unity_LightmapST, o.lightmapUVOrVertexSH.xy);
        	    OUTPUT_SH(lwWNormal, o.lightmapUVOrVertexSH.xyz);

        	    half3 vertexLight = VertexLighting(vertexInput.positionWS, lwWNormal);
        	    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
        	    o.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
        	    o.clipPos = vertexInput.positionCS;

        	#ifdef _MAIN_LIGHT_SHADOWS
        		o.shadowCoord = GetShadowCoord(vertexInput);
        	#endif
        		return o;
        	}

        	half4 frag (GraphVertexOutput IN ) : SV_Target
            {
            	UNITY_SETUP_INSTANCE_ID(IN);

        		float3 WorldSpaceNormal = normalize(float3(IN.tSpace0.z,IN.tSpace1.z,IN.tSpace2.z));
				float3 WorldSpaceTangent = float3(IN.tSpace0.x,IN.tSpace1.x,IN.tSpace2.x);
				float3 WorldSpaceBiTangent = float3(IN.tSpace0.y,IN.tSpace1.y,IN.tSpace2.y);
				float3 WorldSpacePosition = float3(IN.tSpace0.w,IN.tSpace1.w,IN.tSpace2.w);
				float3 WorldSpaceViewDirection = SafeNormalize( _WorldSpaceCameraPos.xyz  - WorldSpacePosition );

				float4 screenPos = IN.ase_texcoord7;
				float4 ase_grabScreenPos = ASE_ComputeGrabScreenPos( screenPos );
				float4 ase_grabScreenPosNorm = ase_grabScreenPos / ase_grabScreenPos.w;
				float temp_output_130_0_g47 = _NormalScale;
				float2 temp_output_137_0_g47 = _WaveSpeed;
				float temp_output_6_0_g47 = (temp_output_137_0_g47).x;
				float2 temp_cast_1 = (temp_output_6_0_g47).xx;
				float temp_output_132_0_g47 = _GlobalTiling;
				float _Tiling389_g47 = temp_output_132_0_g47;
				float2 temp_cast_2 = (_Tiling389_g47).xx;
				float2 temp_cast_3 = (0.15).xx;
				float2 uv11_g47 = IN.ase_texcoord8.xy * temp_cast_2 + temp_cast_3;
				float2 panner17_g47 = ( 1.0 * _Time.y * temp_cast_1 + uv11_g47);
				float cos272_g47 = cos( temp_output_6_0_g47 );
				float sin272_g47 = sin( temp_output_6_0_g47 );
				float2 rotator272_g47 = mul( panner17_g47 - float2( 0.2,0 ) , float2x2( cos272_g47 , -sin272_g47 , sin272_g47 , cos272_g47 )) + float2( 0.2,0 );
				float2 temp_cast_4 = (( temp_output_132_0_g47 + 2.0 )).xx;
				float2 temp_cast_5 = (1.2).xx;
				float2 uv10_g47 = IN.ase_texcoord8.xy * temp_cast_4 + temp_cast_5;
				float2 panner16_g47 = ( 1.0 * _Time.y * (( temp_output_137_0_g47 / 2.0 )).xy + uv10_g47);
				float3 _Normal25_g47 = BlendNormal( UnpackNormalmapRGorAG( tex2D( _WaterNormal, rotator272_g47 ), temp_output_130_0_g47 ) , UnpackNormalmapRGorAG( tex2D( _WaterNormal, panner16_g47 ), ( temp_output_130_0_g47 - 0.001 ) ) );
				float4 fetchOpaqueVal86_g47 = SAMPLE_TEXTURE2D( _CameraOpaqueTexture, sampler_CameraOpaqueTexture, ( float3( (ase_grabScreenPosNorm).xy ,  0.0 ) + ( _Normal25_g47 * _Distortion ) ).xy);
				float4 _DistortionDeep383_g47 = ( fetchOpaqueVal86_g47 * ( 1.0 - 1.5 ) );
				float4 ase_screenPosNorm = screenPos / screenPos.w;
				ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
				float clampDepth20_g47 = Linear01Depth(tex2Dproj( _CameraDepthTexture, ase_screenPosNorm ).r,_ZBufferParams);
				float _ScreenPosition391_g47 = abs( ( clampDepth20_g47 - ase_screenPosNorm.w ) );
				float screenDepth555_g47 = LinearEyeDepth(tex2Dproj( _CameraDepthTexture, screenPos ).r,_ZBufferParams);
				float distanceDepth555_g47 = abs( ( screenDepth555_g47 - LinearEyeDepth( ase_screenPosNorm.z,_ZBufferParams ) ) / ( saturate( pow( ( _ScreenPosition391_g47 + ( 1.0 - 1.0 ) ) , ( 1.0 - 1.0 ) ) ) ) );
				float _WaterDepth559_g47 = distanceDepth555_g47;
				float clampResult606_g47 = clamp( _WaterDepth559_g47 , 0.0 , 2.0 );
				float clampResult666 = clamp( 0.0 , 0.0 , 30.0 );
				float clampResult668 = clamp( 1.0 , 0.0 , 5.0 );
				float4 lerpResult583_g47 = lerp( ( float4(0.05201113,0.1105556,0.1911763,1) * ( 1.0 - 1.0 ) ) , _DistortionDeep383_g47 , ( 1.0 - saturate( pow( ( clampResult606_g47 + ( 1.0 - clampResult666 ) ) , ( 1.0 - clampResult668 ) ) ) ));
				float4 _DeepColor598_g47 = saturate( lerpResult583_g47 );
				float clampResult681 = clamp( _SurfaceOpacity , 0.5 , 1.0 );
				float temp_output_331_0_g47 = ( 1.0 - clampResult681 );
				float4 lerpResult657_g47 = lerp( _DeepColor598_g47 , _DistortionDeep383_g47 , temp_output_331_0_g47);
				float temp_output_625_0_g47 = _SurfaceColorBlend;
				float4 _DistortionShallow382_g47 = fetchOpaqueVal86_g47;
				float clampResult642_g47 = clamp( _WaterDepth559_g47 , 0.0 , 8.0 );
				float clampResult597 = clamp( 0.0 , 0.0 , 30.0 );
				float clampResult596 = clamp( 1.0 , 0.0 , 5.0 );
				float4 lerpResult617_g47 = lerp( ( _SurfaceColor * temp_output_625_0_g47 ) , _DistortionShallow382_g47 , ( 1.0 - saturate( pow( ( clampResult642_g47 + ( 1.0 - clampResult597 ) ) , ( 1.0 - clampResult596 ) ) ) ));
				float4 _ShallowColor634_g47 = saturate( lerpResult617_g47 );
				float4 lerpResult658_g47 = lerp( _ShallowColor634_g47 , _DistortionShallow382_g47 , temp_output_331_0_g47);
				float clampResult668_g47 = clamp( _WaterDepth559_g47 , 0.0 , 1.0 );
				float4 lerpResult654_g47 = lerp( lerpResult657_g47 , lerpResult658_g47 , abs( pow( clampResult668_g47 , ( 1.0 - 1.0 ) ) ));
				float4 clampResult692_g47 = clamp( lerpResult654_g47 , float4( 0,0,0,0 ) , float4( 1,1,1,0 ) );
				float clampResult610 = clamp( 3.5 , 2.0 , 4.0 );
				float clampResult562_g47 = clamp( saturate( pow( ( _WaterDepth559_g47 + ( 1.0 - 0.4941176 ) ) , ( 1.0 - clampResult610 ) ) ) , 0.0 , 3.0 );
				float2 temp_cast_7 = (( _Tiling389_g47 * 2.1 )).xx;
				float2 uv45_g47 = IN.ase_texcoord8.xy * temp_cast_7 + float2( 0,0 );
				float2 panner49_g47 = ( 1.0 * _Time.y * float2( -0.01,0.01 ) + uv45_g47);
				float4 clampResult663_g47 = clamp( ( clampResult562_g47 * _FoamTint * tex2D( _FoamMap, panner49_g47 ) ) , float4( 0,0,0,0 ) , float4( 1,1,1,0 ) );
				float4 lerpResult328_g47 = lerp( clampResult663_g47 , float4( 0,0,0,0 ) , ( 1.0 - _FoamOpacity ));
				float4 _FoamAlbedo314_g47 = saturate( lerpResult328_g47 );
				float4 _Albedo105_g47 = saturate( ( clampResult692_g47 + _FoamAlbedo314_g47 ) );

				float3 tanToWorld0 = float3( WorldSpaceTangent.x, WorldSpaceBiTangent.x, WorldSpaceNormal.x );
				float3 tanToWorld1 = float3( WorldSpaceTangent.y, WorldSpaceBiTangent.y, WorldSpaceNormal.y );
				float3 tanToWorld2 = float3( WorldSpaceTangent.z, WorldSpaceBiTangent.z, WorldSpaceNormal.z );
				float3 worldRefl54_g47 = reflect( -WorldSpaceViewDirection, float3( dot( tanToWorld0, _Normal25_g47 ), dot( tanToWorld1, _Normal25_g47 ), dot( tanToWorld2, _Normal25_g47 ) ) );
				float3 tanNormal29_g47 = _Normal25_g47;
				float3 worldNormal29_g47 = float3(dot(tanToWorld0,tanNormal29_g47), dot(tanToWorld1,tanNormal29_g47), dot(tanToWorld2,tanNormal29_g47));
				float dotResult35_g47 = dot( worldNormal29_g47 , _MainLightPosition.xyz );
				float temp_output_116_0_g47 = 1.0;
				float _FakeShadow99_g47 = ( 1.0 - saturate( (dotResult35_g47*temp_output_116_0_g47 + temp_output_116_0_g47) ) );
				float4 lerpResult143_g47 = lerp( texCUBE( SkyboxReflection, worldRefl54_g47 ) , float4( 1,1,1,0 ) , _FakeShadow99_g47);
				float4 _Reflections95_g47 = saturate( lerpResult143_g47 );
				float clampResult310 = clamp( ( 1.0 - 1.0 ) , 0.0 , 1.0 );

				float clampResult231_g47 = clamp( _WaterSpecular , 0.0 , 0.05 );
				float clampResult232_g47 = clamp( 1.0 , 0.0 , 0.2 );
				float lerpResult97_g47 = lerp( clampResult231_g47 , clampResult232_g47 , _FoamAlbedo314_g47.r);
				float _Specular104_g47 = lerpResult97_g47;

				float clampResult402_g47 = clamp( _WaterSmoothness , 0.0 , 0.99 );
				float lerpResult96_g47 = lerp( clampResult402_g47 , 1.0 , _FoamAlbedo314_g47.r);
				float _Smoothness98_g47 = lerpResult96_g47;

				float _AmbientOcclusion672_g47 = 1.0;

				float clampResult556_g47 = clamp( distanceDepth555_g47 , 0.0 , 1.0 );
				float _EdgeBlend490_g47 = clampResult556_g47;


		        float3 Albedo = _Albedo105_g47.rgb;
				float3 Normal = _Normal25_g47;
				float3 Emission = ( _Reflections95_g47 * clampResult310 ).rgb;
				float3 Specular = float3(0.5, 0.5, 0.5);
				float Metallic = _Specular104_g47;
				float Smoothness = _Smoothness98_g47;
				float Occlusion = _AmbientOcclusion672_g47;
				float Alpha = _EdgeBlend490_g47;
				float AlphaClipThreshold = 0;

        		InputData inputData;
        		inputData.positionWS = WorldSpacePosition;

        #ifdef _NORMALMAP
        	    inputData.normalWS = normalize(TransformTangentToWorld(Normal, half3x3(WorldSpaceTangent, WorldSpaceBiTangent, WorldSpaceNormal)));
        #else
            #if !SHADER_HINT_NICE_QUALITY
                inputData.normalWS = WorldSpaceNormal;
            #else
        	    inputData.normalWS = normalize(WorldSpaceNormal);
            #endif
        #endif

        #if !SHADER_HINT_NICE_QUALITY
        	    // viewDirection should be normalized here, but we avoid doing it as it's close enough and we save some ALU.
        	    inputData.viewDirectionWS = WorldSpaceViewDirection;
        #else
        	    inputData.viewDirectionWS = normalize(WorldSpaceViewDirection);
        #endif

        	    inputData.shadowCoord = IN.shadowCoord;

        	    inputData.fogCoord = IN.fogFactorAndVertexLight.x;
        	    inputData.vertexLighting = IN.fogFactorAndVertexLight.yzw;
        	    inputData.bakedGI = SAMPLE_GI(IN.lightmapUVOrVertexSH.xy, IN.lightmapUVOrVertexSH.xyz, inputData.normalWS);

        		half4 color = LightweightFragmentPBR(
        			inputData,
        			Albedo,
        			Metallic,
        			Specular,
        			Smoothness,
        			Occlusion,
        			Emission,
        			Alpha);

			#ifdef TERRAIN_SPLAT_ADDPASS
				color.rgb = MixFogColor(color.rgb, half3( 0, 0, 0 ), IN.fogFactorAndVertexLight.x );
			#else
				color.rgb = MixFog(color.rgb, IN.fogFactorAndVertexLight.x);
			#endif

        #if _AlphaClip
        		clip(Alpha - AlphaClipThreshold);
        #endif

		#if ASE_LW_FINAL_COLOR_ALPHA_MULTIPLY
				color.rgb *= color.a;
		#endif
        		return color;
            }

        	ENDHLSL
        }


        Pass
        {

        	Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }

			ZWrite On
			ZTest LEqual

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x


            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment



            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

            CBUFFER_START(UnityPerMaterial)
			uniform sampler2D _CameraDepthTexture;
			CBUFFER_END


            struct GraphVertexInput
            {
                float4 vertex : POSITION;
                float3 ase_normal : NORMAL;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };


        	struct VertexOutput
        	{
        	    float4 clipPos      : SV_POSITION;
                float4 ase_texcoord7 : TEXCOORD7;
                UNITY_VERTEX_INPUT_INSTANCE_ID
        	};

            // x: global clip space bias, y: normal world space bias
            float4 _ShadowBias;
            float3 _LightDirection;

            VertexOutput ShadowPassVertex(GraphVertexInput v)
        	{
        	    VertexOutput o;
        	    UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

				float4 ase_clipPos = TransformObjectToHClip((v.vertex).xyz);
				float4 screenPos = ComputeScreenPos(ase_clipPos);
				o.ase_texcoord7 = screenPos;


				v.vertex.xyz +=  float3(0,0,0) ;
				v.ase_normal =  v.ase_normal ;

        	    float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                float3 normalWS = TransformObjectToWorldDir(v.ase_normal);

                float invNdotL = 1.0 - saturate(dot(_LightDirection, normalWS));
                float scale = invNdotL * _ShadowBias.y;

                // normal bias is negative since we want to apply an inset normal offset
                positionWS = normalWS * scale.xxx + positionWS;
                float4 clipPos = TransformWorldToHClip(positionWS);

                // _ShadowBias.x sign depens on if platform has reversed z buffer
                clipPos.z += _ShadowBias.x;

        	#if UNITY_REVERSED_Z
        	    clipPos.z = min(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
        	#else
        	    clipPos.z = max(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
        	#endif
                o.clipPos = clipPos;

        	    return o;
        	}

            half4 ShadowPassFragment(VertexOutput IN) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);

               float4 screenPos = IN.ase_texcoord7;
               float4 ase_screenPosNorm = screenPos / screenPos.w;
               ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
               float clampDepth20_g47 = Linear01Depth(tex2Dproj( _CameraDepthTexture, ase_screenPosNorm ).r,_ZBufferParams);
               float _ScreenPosition391_g47 = abs( ( clampDepth20_g47 - ase_screenPosNorm.w ) );
               float screenDepth555_g47 = LinearEyeDepth(tex2Dproj( _CameraDepthTexture, screenPos ).r,_ZBufferParams);
               float distanceDepth555_g47 = abs( ( screenDepth555_g47 - LinearEyeDepth( ase_screenPosNorm.z,_ZBufferParams ) ) / ( saturate( pow( ( _ScreenPosition391_g47 + ( 1.0 - 1.0 ) ) , ( 1.0 - 1.0 ) ) ) ) );
               float clampResult556_g47 = clamp( distanceDepth555_g47 , 0.0 , 1.0 );
               float _EdgeBlend490_g47 = clampResult556_g47;


				float Alpha = _EdgeBlend490_g47;
				float AlphaClipThreshold = AlphaClipThreshold;

         #if _AlphaClip
        		clip(Alpha - AlphaClipThreshold);
        #endif
                return 0;
            }

            ENDHLSL
        }


        Pass
        {

        	Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }

            ZWrite On
			ColorMask 0

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex vert
            #pragma fragment frag



            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

			CBUFFER_START(UnityPerMaterial)
			uniform sampler2D _CameraDepthTexture;
			CBUFFER_END



            struct GraphVertexInput
            {
                float4 vertex : POSITION;
				float3 ase_normal : NORMAL;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };


        	struct VertexOutput
        	{
        	    float4 clipPos      : SV_POSITION;
                float4 ase_texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
        	};

            VertexOutput vert(GraphVertexInput v)
            {
                VertexOutput o = (VertexOutput)0;
        	    UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float4 ase_clipPos = TransformObjectToHClip((v.vertex).xyz);
				float4 screenPos = ComputeScreenPos(ase_clipPos);
				o.ase_texcoord = screenPos;


				v.vertex.xyz +=  float3(0,0,0) ;
				v.ase_normal =  v.ase_normal ;

        	    o.clipPos = TransformObjectToHClip(v.vertex.xyz);
        	    return o;
            }

            half4 frag(VertexOutput IN) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);

				float4 screenPos = IN.ase_texcoord;
				float4 ase_screenPosNorm = screenPos / screenPos.w;
				ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
				float clampDepth20_g47 = Linear01Depth(tex2Dproj( _CameraDepthTexture, ase_screenPosNorm ).r,_ZBufferParams);
				float _ScreenPosition391_g47 = abs( ( clampDepth20_g47 - ase_screenPosNorm.w ) );
				float screenDepth555_g47 = LinearEyeDepth(tex2Dproj( _CameraDepthTexture, screenPos ).r,_ZBufferParams);
				float distanceDepth555_g47 = abs( ( screenDepth555_g47 - LinearEyeDepth( ase_screenPosNorm.z,_ZBufferParams ) ) / ( saturate( pow( ( _ScreenPosition391_g47 + ( 1.0 - 1.0 ) ) , ( 1.0 - 1.0 ) ) ) ) );
				float clampResult556_g47 = clamp( distanceDepth555_g47 , 0.0 , 1.0 );
				float _EdgeBlend490_g47 = clampResult556_g47;


				float Alpha = _EdgeBlend490_g47;
				float AlphaClipThreshold = AlphaClipThreshold;

         #if _AlphaClip
        		clip(Alpha - AlphaClipThreshold);
        #endif
                return 0;
            }
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.

        Pass
        {

        	Name "Meta"
            Tags { "LightMode"="Meta" }

            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x


            #pragma vertex vert
            #pragma fragment frag


            #define REQUIRE_OPAQUE_TEXTURE 1


			uniform float4 _MainTex_ST;

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

			CBUFFER_START(UnityPerMaterial)
			sampler2D _WaterNormal;
			float _NormalScale;
			float2 _WaveSpeed;
			float _GlobalTiling;
			float _Distortion;
			uniform sampler2D _CameraDepthTexture;
			float _SurfaceOpacity;
			float4 _SurfaceColor;
			float _SurfaceColorBlend;
			float4 _FoamTint;
			sampler2D _FoamMap;
			float _FoamOpacity;
			samplerCUBE SkyboxReflection;
			CBUFFER_END

			inline float4 ASE_ComputeGrabScreenPos( float4 pos )
			{
				#if UNITY_UV_STARTS_AT_TOP
				float scale = -1.0;
				#else
				float scale = 1.0;
				#endif
				float4 o = pos;
				o.y = pos.w * 0.5f;
				o.y = ( pos.y - o.y ) * _ProjectionParams.x * scale + o.y;
				return o;
			}


            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature EDITOR_VISUALIZATION


            struct GraphVertexInput
            {
                float4 vertex : POSITION;
				float3 ase_normal : NORMAL;
				float4 texcoord1 : TEXCOORD1;
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_tangent : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

        	struct VertexOutput
        	{
        	    float4 clipPos      : SV_POSITION;
                float4 ase_texcoord : TEXCOORD0;
                float4 ase_texcoord1 : TEXCOORD1;
                float4 ase_texcoord2 : TEXCOORD2;
                float4 ase_texcoord3 : TEXCOORD3;
                float4 ase_texcoord4 : TEXCOORD4;
                float4 ase_texcoord5 : TEXCOORD5;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
        	};

            VertexOutput vert(GraphVertexInput v)
            {
                VertexOutput o = (VertexOutput)0;
        	    UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				float4 ase_clipPos = TransformObjectToHClip((v.vertex).xyz);
				float4 screenPos = ComputeScreenPos(ase_clipPos);
				o.ase_texcoord = screenPos;

				float3 ase_worldTangent = TransformObjectToWorldDir(v.ase_tangent.xyz);
				o.ase_texcoord2.xyz = ase_worldTangent;
				float3 ase_worldNormal = TransformObjectToWorldNormal(v.ase_normal);
				o.ase_texcoord3.xyz = ase_worldNormal;
				float ase_vertexTangentSign = v.ase_tangent.w * unity_WorldTransformParams.w;
				float3 ase_worldBitangent = cross( ase_worldNormal, ase_worldTangent ) * ase_vertexTangentSign;
				o.ase_texcoord4.xyz = ase_worldBitangent;
				float3 ase_worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.ase_texcoord5.xyz = ase_worldPos;

				o.ase_texcoord1.xy = v.ase_texcoord.xy;

				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord1.zw = 0;
				o.ase_texcoord2.w = 0;
				o.ase_texcoord3.w = 0;
				o.ase_texcoord4.w = 0;
				o.ase_texcoord5.w = 0;

				v.vertex.xyz +=  float3(0,0,0) ;
				v.ase_normal =  v.ase_normal ;

                o.clipPos = MetaVertexPosition(v.vertex, v.texcoord1.xy, v.texcoord1.xy, unity_LightmapST);
        	    return o;
            }

            half4 frag(VertexOutput IN) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);

           		float4 screenPos = IN.ase_texcoord;
           		float4 ase_grabScreenPos = ASE_ComputeGrabScreenPos( screenPos );
           		float4 ase_grabScreenPosNorm = ase_grabScreenPos / ase_grabScreenPos.w;
           		float temp_output_130_0_g47 = _NormalScale;
           		float2 temp_output_137_0_g47 = _WaveSpeed;
           		float temp_output_6_0_g47 = (temp_output_137_0_g47).x;
           		float2 temp_cast_1 = (temp_output_6_0_g47).xx;
           		float temp_output_132_0_g47 = _GlobalTiling;
           		float _Tiling389_g47 = temp_output_132_0_g47;
           		float2 temp_cast_2 = (_Tiling389_g47).xx;
           		float2 temp_cast_3 = (0.15).xx;
           		float2 uv11_g47 = IN.ase_texcoord1.xy * temp_cast_2 + temp_cast_3;
           		float2 panner17_g47 = ( 1.0 * _Time.y * temp_cast_1 + uv11_g47);
           		float cos272_g47 = cos( temp_output_6_0_g47 );
           		float sin272_g47 = sin( temp_output_6_0_g47 );
           		float2 rotator272_g47 = mul( panner17_g47 - float2( 0.2,0 ) , float2x2( cos272_g47 , -sin272_g47 , sin272_g47 , cos272_g47 )) + float2( 0.2,0 );
           		float2 temp_cast_4 = (( temp_output_132_0_g47 + 2.0 )).xx;
           		float2 temp_cast_5 = (1.2).xx;
           		float2 uv10_g47 = IN.ase_texcoord1.xy * temp_cast_4 + temp_cast_5;
           		float2 panner16_g47 = ( 1.0 * _Time.y * (( temp_output_137_0_g47 / 2.0 )).xy + uv10_g47);
           		float3 _Normal25_g47 = BlendNormal( UnpackNormalmapRGorAG( tex2D( _WaterNormal, rotator272_g47 ), temp_output_130_0_g47 ) , UnpackNormalmapRGorAG( tex2D( _WaterNormal, panner16_g47 ), ( temp_output_130_0_g47 - 0.001 ) ) );
           		float4 fetchOpaqueVal86_g47 = SAMPLE_TEXTURE2D( _CameraOpaqueTexture, sampler_CameraOpaqueTexture, ( float3( (ase_grabScreenPosNorm).xy ,  0.0 ) + ( _Normal25_g47 * _Distortion ) ).xy);
           		float4 _DistortionDeep383_g47 = ( fetchOpaqueVal86_g47 * ( 1.0 - 1.5 ) );
           		float4 ase_screenPosNorm = screenPos / screenPos.w;
           		ase_screenPosNorm.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm.z : ase_screenPosNorm.z * 0.5 + 0.5;
           		float clampDepth20_g47 = Linear01Depth(tex2Dproj( _CameraDepthTexture, ase_screenPosNorm ).r,_ZBufferParams);
           		float _ScreenPosition391_g47 = abs( ( clampDepth20_g47 - ase_screenPosNorm.w ) );
           		float screenDepth555_g47 = LinearEyeDepth(tex2Dproj( _CameraDepthTexture, screenPos ).r,_ZBufferParams);
           		float distanceDepth555_g47 = abs( ( screenDepth555_g47 - LinearEyeDepth( ase_screenPosNorm.z,_ZBufferParams ) ) / ( saturate( pow( ( _ScreenPosition391_g47 + ( 1.0 - 1.0 ) ) , ( 1.0 - 1.0 ) ) ) ) );
           		float _WaterDepth559_g47 = distanceDepth555_g47;
           		float clampResult606_g47 = clamp( _WaterDepth559_g47 , 0.0 , 2.0 );
           		float clampResult666 = clamp( 0.0 , 0.0 , 30.0 );
           		float clampResult668 = clamp( 1.0 , 0.0 , 5.0 );
           		float4 lerpResult583_g47 = lerp( ( float4(0.05201113,0.1105556,0.1911763,1) * ( 1.0 - 1.0 ) ) , _DistortionDeep383_g47 , ( 1.0 - saturate( pow( ( clampResult606_g47 + ( 1.0 - clampResult666 ) ) , ( 1.0 - clampResult668 ) ) ) ));
           		float4 _DeepColor598_g47 = saturate( lerpResult583_g47 );
           		float clampResult681 = clamp( _SurfaceOpacity , 0.5 , 1.0 );
           		float temp_output_331_0_g47 = ( 1.0 - clampResult681 );
           		float4 lerpResult657_g47 = lerp( _DeepColor598_g47 , _DistortionDeep383_g47 , temp_output_331_0_g47);
           		float temp_output_625_0_g47 = _SurfaceColorBlend;
           		float4 _DistortionShallow382_g47 = fetchOpaqueVal86_g47;
           		float clampResult642_g47 = clamp( _WaterDepth559_g47 , 0.0 , 8.0 );
           		float clampResult597 = clamp( 0.0 , 0.0 , 30.0 );
           		float clampResult596 = clamp( 1.0 , 0.0 , 5.0 );
           		float4 lerpResult617_g47 = lerp( ( _SurfaceColor * temp_output_625_0_g47 ) , _DistortionShallow382_g47 , ( 1.0 - saturate( pow( ( clampResult642_g47 + ( 1.0 - clampResult597 ) ) , ( 1.0 - clampResult596 ) ) ) ));
           		float4 _ShallowColor634_g47 = saturate( lerpResult617_g47 );
           		float4 lerpResult658_g47 = lerp( _ShallowColor634_g47 , _DistortionShallow382_g47 , temp_output_331_0_g47);
           		float clampResult668_g47 = clamp( _WaterDepth559_g47 , 0.0 , 1.0 );
           		float4 lerpResult654_g47 = lerp( lerpResult657_g47 , lerpResult658_g47 , abs( pow( clampResult668_g47 , ( 1.0 - 1.0 ) ) ));
           		float4 clampResult692_g47 = clamp( lerpResult654_g47 , float4( 0,0,0,0 ) , float4( 1,1,1,0 ) );
           		float clampResult610 = clamp( 3.5 , 2.0 , 4.0 );
           		float clampResult562_g47 = clamp( saturate( pow( ( _WaterDepth559_g47 + ( 1.0 - 0.4941176 ) ) , ( 1.0 - clampResult610 ) ) ) , 0.0 , 3.0 );
           		float2 temp_cast_7 = (( _Tiling389_g47 * 2.1 )).xx;
           		float2 uv45_g47 = IN.ase_texcoord1.xy * temp_cast_7 + float2( 0,0 );
           		float2 panner49_g47 = ( 1.0 * _Time.y * float2( -0.01,0.01 ) + uv45_g47);
           		float4 clampResult663_g47 = clamp( ( clampResult562_g47 * _FoamTint * tex2D( _FoamMap, panner49_g47 ) ) , float4( 0,0,0,0 ) , float4( 1,1,1,0 ) );
           		float4 lerpResult328_g47 = lerp( clampResult663_g47 , float4( 0,0,0,0 ) , ( 1.0 - _FoamOpacity ));
           		float4 _FoamAlbedo314_g47 = saturate( lerpResult328_g47 );
           		float4 _Albedo105_g47 = saturate( ( clampResult692_g47 + _FoamAlbedo314_g47 ) );

           		float3 ase_worldTangent = IN.ase_texcoord2.xyz;
           		float3 ase_worldNormal = IN.ase_texcoord3.xyz;
           		float3 ase_worldBitangent = IN.ase_texcoord4.xyz;
           		float3 tanToWorld0 = float3( ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x );
           		float3 tanToWorld1 = float3( ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y );
           		float3 tanToWorld2 = float3( ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z );
           		float3 ase_worldPos = IN.ase_texcoord5.xyz;
           		float3 ase_worldViewDir = ( _WorldSpaceCameraPos.xyz - ase_worldPos );
           		ase_worldViewDir = normalize(ase_worldViewDir);
           		float3 worldRefl54_g47 = reflect( -ase_worldViewDir, float3( dot( tanToWorld0, _Normal25_g47 ), dot( tanToWorld1, _Normal25_g47 ), dot( tanToWorld2, _Normal25_g47 ) ) );
           		float3 tanNormal29_g47 = _Normal25_g47;
           		float3 worldNormal29_g47 = float3(dot(tanToWorld0,tanNormal29_g47), dot(tanToWorld1,tanNormal29_g47), dot(tanToWorld2,tanNormal29_g47));
           		float dotResult35_g47 = dot( worldNormal29_g47 , _MainLightPosition.xyz );
           		float temp_output_116_0_g47 = 1.0;
           		float _FakeShadow99_g47 = ( 1.0 - saturate( (dotResult35_g47*temp_output_116_0_g47 + temp_output_116_0_g47) ) );
           		float4 lerpResult143_g47 = lerp( texCUBE( SkyboxReflection, worldRefl54_g47 ) , float4( 1,1,1,0 ) , _FakeShadow99_g47);
           		float4 _Reflections95_g47 = saturate( lerpResult143_g47 );
           		float clampResult310 = clamp( ( 1.0 - 1.0 ) , 0.0 , 1.0 );

           		float clampResult556_g47 = clamp( distanceDepth555_g47 , 0.0 , 1.0 );
           		float _EdgeBlend490_g47 = clampResult556_g47;


		        float3 Albedo = _Albedo105_g47.rgb;
				float3 Emission = ( _Reflections95_g47 * clampResult310 ).rgb;
				float Alpha = _EdgeBlend490_g47;
				float AlphaClipThreshold = 0;

         #if _AlphaClip
        		clip(Alpha - AlphaClipThreshold);
        #endif

                MetaInput metaInput = (MetaInput)0;
                metaInput.Albedo = Albedo;
                metaInput.Emission = Emission;

                return MetaFragment(metaInput);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
	//CustomEditor "ASEMaterialInspector"


}
/*ASEBEGIN
Version=16200
344.8;0.8;1010;752;1077.851;740.717;1.522356;True;False
Node;AmplifyShaderEditor.CommentaryNode;265;-1541.605,-1234.942;Float;False;1808.274;3302.058;Main Setup;38;302;310;38;47;51;34;539;75;666;426;79;596;230;469;597;351;245;53;70;629;69;261;681;668;73;185;670;262;476;610;39;667;44;665;435;190;439;736;Main Setup;0,0.5448275,1,1;0;0
Node;AmplifyShaderEditor.RangedFloatNode;439;-1511.87,11.1601;Float;False;Constant;_ShallowDepth;Shallow Depth;9;0;Create;True;0;0;False;0;0;30;0;30;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;190;-938.8583,289.8095;Float;False;Constant;_ReflectionAmount;Reflection Amount;21;0;Create;True;0;0;False;0;1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;435;-1505.986,-220.1141;Float;False;Property;_SurfaceOpacity;Surface Opacity;2;0;Create;True;0;0;False;0;1;0.97;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;665;-1515.244,125.6636;Float;False;Constant;_DeepDepth;Deep Depth;11;0;Create;True;0;0;False;0;0;30;0;30;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;44;-1511.087,327.8101;Float;False;Constant;_ShallowFalloff;Shallow Falloff;10;0;Create;True;0;0;False;0;1;1;0;5;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;667;-1509.707,450.4643;Float;False;Constant;_DeepFalloff;Deep Falloff;13;0;Create;True;0;0;False;0;1;5;0;5;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;39;-1522.381,1679.864;Float;False;Constant;_FoamFalloff;Foam Falloff;17;0;Create;True;0;0;False;0;3.5;3.5;0;4;0;1;FLOAT;0
Node;AmplifyShaderEditor.ClampOpNode;610;-1202.584,1632.066;Float;False;3;0;FLOAT;0;False;1;FLOAT;2;False;2;FLOAT;4;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;476;-1518.762,-1160.099;Float;False;Constant;_DeepColorBlend;Deep Color Blend;9;0;Create;True;0;0;False;0;1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.TexturePropertyNode;262;-1494.886,-865.0838;Float;True;Property;_WaterNormal;Water Normal;3;0;Create;True;0;0;False;0;None;dd2fd2df93418444c8e280f1d34deeb5;True;white;Auto;Texture2D;0;1;SAMPLER2D;0
Node;AmplifyShaderEditor.RangedFloatNode;670;-1517.476,733.6425;Float;False;Constant;_ColorBlendingAmount;Color Blending Amount;11;0;Create;True;0;0;False;0;1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.TexturePropertyNode;185;-1528.364,1773.411;Float;True;Global;SkyboxReflection;Skybox Reflection;13;0;Create;True;0;0;False;0;None;None;False;white;LockedToCube;Cube;0;1;SAMPLERCUBE;0
Node;AmplifyShaderEditor.RangedFloatNode;73;-1525.754,1492.516;Float;False;Constant;_FoamSpecular;Foam Specular;17;0;Create;True;0;0;False;0;1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.ClampOpNode;668;-1211.534,437.4506;Float;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;5;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;53;-1523.442,838.1867;Float;False;Property;_Distortion;Distortion;9;0;Create;True;0;0;False;0;0.2;0.25;0;2;0;1;FLOAT;0
Node;AmplifyShaderEditor.ClampOpNode;681;-1179.958,-263.3964;Float;False;3;0;FLOAT;0;False;1;FLOAT;0.5;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.TexturePropertyNode;261;-1514.407,931.3614;Float;True;Property;_FoamMap;Foam Map;10;0;Create;True;0;0;False;0;None;d01457b88b1c5174ea4235d140b5fab8;False;white;Auto;Texture2D;0;1;SAMPLER2D;0
Node;AmplifyShaderEditor.OneMinusNode;629;-595.9492,299.3329;Float;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;70;-1524.733,638.6342;Float;False;Property;_WaterSpecular;Water Specular;7;0;Create;True;0;0;False;0;0.1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;69;-1524.101,557.4289;Float;False;Property;_WaterSmoothness;Water Smoothness;8;0;Create;True;0;0;False;0;0.9;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.Vector2Node;245;-1478.323,-119.3994;Float;False;Property;_WaveSpeed;Wave Speed;1;0;Create;True;0;0;False;0;-0.04,0.045;-0.05,0.05;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.ColorNode;351;-1520.862,1134.512;Float;False;Property;_FoamTint;Foam Tint;11;0;Create;True;0;0;False;0;1,1,1,0;0.5294118,0.5294118,0.5294118,1;False;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;34;-1496.335,-671.2239;Float;False;Property;_NormalScale;Normal Scale;4;0;Create;True;0;0;False;0;0.4;0.2;0.025;2;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;469;-1516.762,-1059.099;Float;False;Property;_SurfaceColorBlend;Surface Color Blend;6;0;Create;True;0;0;False;0;0.9;0.31;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;230;-1526.817,1967.628;Float;False;Constant;_ShadowDepth;Shadow Depth;19;0;Create;True;0;0;False;0;1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.ClampOpNode;596;-1215.514,282.2962;Float;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;5;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;79;-1517.524,-949.1722;Float;False;Property;_GlobalTiling;Global Tiling;0;0;Create;True;0;0;False;0;50;2048;0;32768;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;426;-1522.069,1314.222;Float;False;Property;_FoamOpacity;Foam Opacity;12;0;Create;True;0;0;False;0;1;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.ClampOpNode;666;-1221.596,62.85124;Float;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;30;False;1;FLOAT;0
Node;AmplifyShaderEditor.ClampOpNode;597;-1218.222,-51.65228;Float;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;30;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;75;-1515.994,1584.157;Float;False;Constant;_FoamSmoothness;Foam Smoothness;18;0;Create;True;0;0;False;0;1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;539;-1515.507,226.6118;Float;False;Constant;_ShorelineAmount;Shoreline Amount;24;0;Create;True;0;0;False;0;1;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;51;-1488.671,-586.8487;Float;False;Property;_SurfaceColor;Surface Color;5;0;Create;True;0;0;False;0;0.4329584,0.5616246,0.6691177,1;0.2980391,0.4392156,0.5568628,1;False;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.ColorNode;47;-1491.281,-415.8536;Float;False;Constant;_DeepColor;Deep Color;9;0;Create;True;0;0;False;0;0.05201113,0.1105556,0.1911763,1;0.05201113,0.1105556,0.1911763,1;False;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;38;-1526.971,1405.014;Float;False;Constant;_FoamDepth;Foam Depth;19;0;Create;True;0;0;False;0;0.4941176;0.4;0;2;0;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;735;-950.627,-469.7546;Float;False;Simple Water Sample;-1;;47;f2f2c9b193fabb4458e37ad6b3ec204c;0;27;595;FLOAT;0;False;625;FLOAT;0;False;132;FLOAT;256;False;131;SAMPLER2D;;False;130;FLOAT;0.2;False;628;COLOR;0.4329584,0.5616246,0.6691177,1;False;611;COLOR;0.05201113,0.1105556,0.1911763,1;False;330;FLOAT;0;False;137;FLOAT2;-0.04,0.045;False;630;FLOAT;0;False;594;FLOAT;0;False;558;FLOAT;1;False;626;FLOAT;0;False;590;FLOAT;0;False;122;FLOAT;0.97;False;123;FLOAT;1;False;655;FLOAT;0;False;119;FLOAT;0.2;False;138;SAMPLER2D;;False;234;COLOR;0.4313726,0.4313726,0.4313726,0;False;320;FLOAT;0.5;False;124;FLOAT;2.8;False;125;FLOAT;2;False;120;FLOAT;1;False;121;FLOAT;1;False;117;SAMPLERCUBE;;False;116;FLOAT;0.025;False;7;COLOR;0;FLOAT3;106;COLOR;107;FLOAT;108;FLOAT;109;FLOAT;674;FLOAT;146
Node;AmplifyShaderEditor.ClampOpNode;310;-369.1227,-26.34986;Float;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;302;-199.3212,-116.4392;Float;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;737;4.082899,-352.3193;Float;False;False;2;Float;ASEMaterialInspector;0;1;Hidden/Templates/LightWeightSRPPBR;1976390536c6c564abb90fe41f6ee334;0;1;ShadowCaster;0;False;False;False;True;0;False;-1;False;False;False;False;False;True;3;RenderPipeline=LightweightPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;True;2;0;False;False;False;False;False;False;True;1;False;-1;True;3;False;-1;False;True;1;LightMode=ShadowCaster;False;0;;0;0;Standard;0;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;738;4.082899,-352.3193;Float;False;False;2;Float;ASEMaterialInspector;0;1;Hidden/Templates/LightWeightSRPPBR;1976390536c6c564abb90fe41f6ee334;0;2;DepthOnly;0;False;False;False;True;0;False;-1;False;False;False;False;False;True;3;RenderPipeline=LightweightPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;True;2;0;False;False;False;False;True;False;False;False;False;0;False;-1;False;True;1;False;-1;False;False;True;1;LightMode=DepthOnly;False;0;;0;0;Standard;0;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;739;4.082899,-352.3193;Float;False;False;2;Float;ASEMaterialInspector;0;1;Hidden/Templates/LightWeightSRPPBR;1976390536c6c564abb90fe41f6ee334;0;3;Meta;0;False;False;False;True;0;False;-1;False;False;False;False;False;True;3;RenderPipeline=LightweightPipeline;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;True;2;0;False;False;False;True;2;False;-1;False;False;False;False;False;True;1;LightMode=Meta;False;0;;0;0;Standard;0;6;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT;0;False;3;FLOAT;0;False;4;FLOAT3;0,0,0;False;5;FLOAT3;0,0,0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;736;4.082899,-352.3193;Float;False;True;2;Float;ASEMaterialInspector;0;2;Procedural Worlds/Simple Water LW;1976390536c6c564abb90fe41f6ee334;0;0;Base;11;False;False;False;True;2;False;-1;False;False;False;False;False;True;3;RenderPipeline=LightweightPipeline;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;True;2;0;True;2;5;False;-1;10;False;-1;0;1;False;-1;0;False;-1;False;False;False;True;True;True;True;True;0;False;-1;True;False;255;False;-1;255;False;-1;255;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;1;False;-1;True;3;False;-1;True;True;0;False;-1;0;False;-1;True;1;LightMode=LightweightForward;False;0;;0;0;Standard;1;_FinalColorxAlpha;0;11;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;9;FLOAT3;0,0,0;False;3;FLOAT;0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT;0;False;7;FLOAT;0;False;8;FLOAT3;0,0,0;False;10;FLOAT3;0,0,0;False;0
WireConnection;610;0;39;0
WireConnection;668;0;667;0
WireConnection;681;0;435;0
WireConnection;629;0;190;0
WireConnection;596;0;44;0
WireConnection;666;0;665;0
WireConnection;597;0;439;0
WireConnection;735;595;476;0
WireConnection;735;625;469;0
WireConnection;735;132;79;0
WireConnection;735;131;262;0
WireConnection;735;130;34;0
WireConnection;735;628;51;0
WireConnection;735;611;47;0
WireConnection;735;330;681;0
WireConnection;735;137;245;0
WireConnection;735;630;597;0
WireConnection;735;594;666;0
WireConnection;735;558;539;0
WireConnection;735;626;596;0
WireConnection;735;590;668;0
WireConnection;735;122;69;0
WireConnection;735;123;70;0
WireConnection;735;655;670;0
WireConnection;735;119;53;0
WireConnection;735;138;261;0
WireConnection;735;234;351;0
WireConnection;735;320;426;0
WireConnection;735;124;38;0
WireConnection;735;125;610;0
WireConnection;735;120;73;0
WireConnection;735;121;75;0
WireConnection;735;117;185;0
WireConnection;735;116;230;0
WireConnection;310;0;629;0
WireConnection;302;0;735;107
WireConnection;302;1;310;0
WireConnection;736;0;735;0
WireConnection;736;1;735;106
WireConnection;736;2;302;0
WireConnection;736;3;735;108
WireConnection;736;4;735;109
WireConnection;736;5;735;674
WireConnection;736;6;735;146
ASEEND*/
//CHKSM=1D28C5BCC9E882DCDF82280E82B35D077221BA3D
