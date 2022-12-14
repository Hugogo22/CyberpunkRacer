#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

// This is a neat trick to work around a bug in the shader graph when
// enabling shadow keywords. Created by @cyanilux
// https://github.com/Cyanilux/URP_ShaderGraphCustomLighting
#ifndef SHADERGRAPH_PREVIEW
    #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
    #if (SHADERPASS != SHADERPASS_FORWARD)
        #undef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
    #endif
#endif

SamplerState sampler_point_clamp;

struct CustomLightingData {
    // Position and orientation
    float3 positionWS;
    float3 normalWS;
    float3 viewDirectionWS;
    float4 shadowCoord;

    // Surface attributes
    float3 albedo;
    float smoothness;
};

// Translate a [0, 1] smoothness value to an exponent 
float GetSmoothnessPower(float rawSmoothness) {
    return exp2(10 * rawSmoothness + 1);
}

#ifndef SHADERGRAPH_PREVIEW
float3 CustomLightHandling(CustomLightingData d, Light light) {

    float attenuation = light.distanceAttenuation * light.shadowAttenuation;

    float4 _SampleTexture2DLOD_RGBA = SAMPLE_TEXTURE2D_LOD(_ToonRamp, sampler_point_clamp, float2(attenuation, 0), 0);
    float toonAttenuation = _SampleTexture2DLOD_RGBA.r;

    float3 radiance = light.color * toonAttenuation;

    float diffuse = saturate(dot(d.normalWS, light.direction));

    
    _SampleTexture2DLOD_RGBA = SAMPLE_TEXTURE2D_LOD(_ToonRamp, sampler_point_clamp, float2(diffuse, 1), 0);
    float toonDiffuse = _SampleTexture2DLOD_RGBA.r;

    float specularDot = saturate(dot(d.normalWS, normalize(light.direction + d.viewDirectionWS)));
    float specular = pow(specularDot, GetSmoothnessPower(d.smoothness)) * diffuse;

    _SampleTexture2DLOD_RGBA = SAMPLE_TEXTURE2D_LOD(_ToonRamp, sampler_point_clamp, float2(specular, 1), 0);
    float toonSpecular = _SampleTexture2DLOD_RGBA.r;

    float3 color = d.albedo * radiance * (toonDiffuse + toonSpecular);

    return color;
}
#endif

float3 CalculateCustomLighting(CustomLightingData d) {
#ifdef SHADERGRAPH_PREVIEW
    // In preview, estimate diffuse + specular
    float3 lightDir = float3(0.5, 0.5, 0);
    float intensity = saturate(dot(d.normalWS, lightDir)) +
        pow(saturate(dot(d.normalWS, normalize(d.viewDirectionWS + lightDir))), GetSmoothnessPower(d.smoothness));
    return d.albedo * intensity;
#else
    // Get the main light. Located in URP/ShaderLibrary/Lighting.hlsl
    Light mainLight = GetMainLight(d.shadowCoord, d.positionWS, 1);

    float3 color = 0;
    // Shade the main light
    color += CustomLightHandling(d, mainLight);

    #ifdef _ADDITIONAL_LIGHTS
        // Shade additional cone and point lights. Functions in URP/ShaderLibrary/Lighting.hlsl
        uint numAdditionalLights = GetAdditionalLightsCount();
        for (uint lightI = 0; lightI < numAdditionalLights; lightI++) {
            Light light = GetAdditionalLight(lightI, d.positionWS, 1);
            color += CustomLightHandling(d, light);
        }
    #endif

    return color;
#endif
}

void CalculateCustomLighting_float(float3 Position, float3 Normal, float3 ViewDirection,
    float3 Albedo, float Smoothness,
    out float3 Color) {

    CustomLightingData d;
    d.positionWS = Position;
    d.normalWS = Normal;
    d.viewDirectionWS = ViewDirection;
    d.albedo = Albedo;
    d.smoothness = Smoothness;

#ifdef SHADERGRAPH_PREVIEW
    // In preview, there's no shadows or bakedGI
    d.shadowCoord = 0;
#else
    // Calculate the main light shadow coord
    // There are two types depending on if cascades are enabled
    float4 positionCS = TransformWorldToHClip(Position);
    #if SHADOWS_SCREEN
        d.shadowCoord = ComputeScreenPos(positionCS);
    #else
        d.shadowCoord = TransformWorldToShadowCoord(Position);
    #endif
#endif

    Color = CalculateCustomLighting(d);
}

#endif
