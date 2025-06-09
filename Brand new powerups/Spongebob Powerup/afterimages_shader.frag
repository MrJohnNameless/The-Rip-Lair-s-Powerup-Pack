#version 120
uniform sampler2D iChannel0;
uniform vec4 iCol;
uniform float iAlpha;

void main()
{
    vec4 mask = texture2D(iChannel0, gl_TexCoord[0].xy);
	mask = iCol * mask.a;
	mask *= iAlpha;
	
	gl_FragColor = mask;
}