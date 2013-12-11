/*
     File: Shader64.fsh
 Abstract:  Fragment shader that adjusts the luminance value based on the input sliders and renders the input texture. 
  Version: 1.1
 
 */

#define PI 3.14159265
// #define SCALE 1.0

varying highp vec2 texCoordVarying;
precision mediump float;

uniform float longitude;
uniform float lattitude;
uniform float scale;
uniform float whratio;
uniform int viewChoice;
uniform sampler2D SamplerY;
uniform sampler2D SamplerUV;
uniform mat3 colorConversionMatrix;

uniform float cos_theta;
uniform float cos_alpha;
uniform float sin_theta;
uniform float sin_alpha;


void pano()
{
	mediump vec3 yuv;
	lowp vec3 rgb;

	float twopi = PI * 2.0;
	float u = (0.5 - texCoordVarying.x) * (1920.0 / 1080.0);
	float v = texCoordVarying.y - 0.5;
	
	float x = scale * cos_theta * cos_alpha + u * sin_alpha - v * sin_theta * cos_alpha;
	float y = scale * cos_theta * sin_alpha - u * cos_alpha - v * sin_theta * sin_alpha;
	float z = scale * sin_theta + v * cos_theta;
	
	float s_ = sqrt (x*x+y*y+z*z);
	float theta_ = atan( z / (sqrt(x*x + y*y)) );
	float alpha_ = atan( y / x );
	if (x < 0.0 )
		alpha_ += PI;
	else if ( y < 0.0 )
		alpha_ += twopi;

	vec2 texCoord;
	texCoord.x = alpha_ / twopi ;
	texCoord.y = (theta_ + PI / 2.0 ) / PI ;
	
	yuv.x = (texture2D(SamplerY, texCoord).r - (16.0/255.0));
	yuv.yz = (texture2D(SamplerUV, texCoord).rg - vec2(0.5, 0.5));

	rgb = colorConversionMatrix * yuv;
	
	gl_FragColor = vec4(rgb,1);
}

void littleplanet()
{
	mediump vec3 yuv;
	lowp vec3 rgb;
	
	float R = 1.0;
	float twopi = PI * 2.0;
	float alpha = longitude * twopi;
	
	float u = (texCoordVarying.x - 0.5) * 8.0 * (1920.0 / 1080.0);
	float v = (texCoordVarying.y - 0.5) * 8.0;
	
	float rho = sqrt( u * u + v * v);
	float c = 2.0 * atan( rho / 2.0 / R);
	float sinc = sin(c);
	float cosc = cos(c);

	float theta_ = asin(cosc*sin_theta + v*sinc*cos_theta / rho);
	float y = u*sinc;
	float x = (rho * cos_theta * cosc - v * sin_theta * sinc );
	float alpha_ = alpha + atan(y/x);
	if ( x < 0.0 )
		alpha_ += PI;

	vec2 texCoord;
	// normalize
	texCoord.x = alpha_ / twopi ;
	texCoord.y = (theta_ + PI / 2.0 ) / PI ;
	texCoord.x = texCoord.x - floor(texCoord.x); 

	yuv.x = (texture2D(SamplerY, texCoord).r - (16.0/255.0));
	yuv.yz = (texture2D(SamplerUV, texCoord).rg - vec2(0.5, 0.5));
	
	rgb = colorConversionMatrix * yuv;
	
	gl_FragColor = vec4(rgb,1);
}

void origView()
{
	mediump vec3 yuv;
	lowp vec3 rgb;
	yuv.x = (texture2D(SamplerY, texCoordVarying).r - (16.0/255.0));
	yuv.yz = (texture2D(SamplerUV, texCoordVarying).rg - vec2(0.5, 0.5));
	rgb = colorConversionMatrix * yuv;
	gl_FragColor = vec4(rgb,1);
	
}

void main()
{
 //   pano();
 
	if (viewChoice == 0)
		pano();	
	else if (viewChoice == 1)
		littleplanet();
	else if (viewChoice == 2)
		origView();

 }
