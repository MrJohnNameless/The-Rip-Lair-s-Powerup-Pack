// Makes an image a solid color.

#version 120
uniform sampler2D iChannel0;

uniform vec4 color;

void main()
{
	vec4 c = texture2D(iChannel0, gl_TexCoord[0].xy);
	
	c.rgb = color.rgb*c.a;

	gl_FragColor = c*gl_Color;
}