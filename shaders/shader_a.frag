#version 460 core
#include <flutter/runtime_effect.glsl>
precision mediump float;

uniform sampler2D iChannel0;
uniform vec2 iResolution;

out vec4 fragColor;


void main() {
	fragColor = vec4(texture(iChannel0, FlutterFragCoord().xy/iResolution.xy).xyz, 1.0);
}