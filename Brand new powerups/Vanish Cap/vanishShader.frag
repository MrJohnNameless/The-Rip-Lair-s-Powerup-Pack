#version 120
#extension GL_EXT_gpu_shader4 : enable

uniform sampler2D iChannel0;

// Resolution of the checkerboard
uniform int x_scale_factor = 1024;
uniform int y_scale_factor = 1024;

//Do your per-pixel shader logic here.
void main()
{
	vec2 uv = gl_TexCoord[0].xy;
	vec4 color = texture2D(iChannel0, uv);

	int xuv = int(uv.x * x_scale_factor);
	int yuv = int(uv.y * y_scale_factor);

	int horizontal_checkerboard_strip = xuv % 2;
	int vertical_checkerboard_strip = yuv % 2;
	int checkerboard_mix = horizontal_checkerboard_strip ^ vertical_checkerboard_strip;

	gl_FragColor = mix(color, vec4(0), checkerboard_mix);
}