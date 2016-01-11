#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "ScreenPos.glsl"
#include "Fog.glsl"
#include "Lighting.glsl"

varying vec4 vTexCoord;
varying vec4 vWorldPos;

#ifdef WEIGHTMASK
    varying vec2 vMaskTexCoord;
#endif

#ifdef VERTEXCOLOR
    varying vec4 vColor;
#endif

#ifdef COMPILEVS

void VS()
{
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));
    #ifdef SSPRT
        vec4 sc = GetScreenPos(gl_Position);
        vTexCoord = sc;
        #ifdef WEIGHTMASK
            vMaskTexCoord = GetTexCoord(iTexCoord);
        #endif
    #else
            vTexCoord = GetTexCoord(iTexCoord);
    #endif

    #ifdef VERTEXCOLOR
        vColor = iColor;
    #endif
}
#endif

#ifdef COMPILEPS

uniform float cBlurriness;

void PS()
{
    // Get material diffuse albedo
    #ifdef DIFFMAP
        vec4 blurredRT = texture2DProj(sEnvMap, vTexCoord);
        vec4 viewportRT = texture2DProj(sDiffMap, vTexCoord);
        
        #ifdef WEIGHTMASK
            vec4 weightColor = texture2D(sSpecMap, vMaskTexCoord);
            float weight = GetIntensity(weightColor.xyz);
            float factor = min(max(cBlurriness * weight, 0.0), 1.0);
            vec4 finalColor = mix(viewportRT, blurredRT, factor);
            vec4 diffColor = mix(vec4(1,1,1,1), cMatDiffColor, factor) * finalColor;
        #else
            vec4 finalColor = mix(viewportRT, blurredRT, min(max(cBlurriness, 0.0), 1.0));
            vec4 diffColor = cMatDiffColor * finalColor;
        #endif
        
        
        
        #ifdef ALPHAMASK
            if (diffColor.a < 0.5)
                discard;
        #endif
    #else
        vec4 diffColor = cMatDiffColor;
    #endif

    #ifdef VERTEXCOLOR
        diffColor *= vColor;
    #endif

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(vWorldPos.w, vWorldPos.y);
    #else
        float fogFactor = GetFogFactor(vWorldPos.w);
    #endif

    #if defined(PREPASS)
        // Fill light pre-pass G-Buffer
        gl_FragData[0] = vec4(0.5, 0.5, 0.5, 1.0);
        gl_FragData[1] = vec4(EncodeDepth(vWorldPos.w), 0.0);
    #elif defined(DEFERRED)
        gl_FragData[0] = vec4(GetFog(diffColor.rgb, fogFactor), diffColor.a);
        gl_FragData[1] = vec4(0.0, 0.0, 0.0, 0.0);
        gl_FragData[2] = vec4(0.5, 0.5, 0.5, 1.0);
        gl_FragData[3] = vec4(EncodeDepth(vWorldPos.w), 0.0);
    #else
        gl_FragColor = vec4(GetFog(diffColor.rgb, fogFactor), diffColor.a);
    #endif
}

#endif
