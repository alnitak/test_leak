#version 460 core
#include <flutter/runtime_effect.glsl>
precision mediump float;

uniform sampler2D iChannel0;
uniform vec2 iResolution;
uniform float iTime;

out vec4 fragColor;


void main() {
    vec2 uv = FlutterFragCoord().xy/iResolution.xy;
    vec4 c = texture(iChannel0, uv);
    float dist = distance(uv, vec2(0.5, 0.5));
    fragColor = vec4(
        dist,
        sin(iTime) / 3.14159265,
        cos(iTime) / 3.14159265, 
        1.0);
}