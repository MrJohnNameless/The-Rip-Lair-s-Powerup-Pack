#version 120
uniform sampler2D iChannel0;
uniform int enabled;

//Do your per-pixel shader logic here.
void main()
{

	vec4 c = texture2D(iChannel0, gl_TexCoord[0].xy);

	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));

	if(enabled+0.5>=1){
		gl_FragColor = vec4(vec3(gray), c.a);
	}

}