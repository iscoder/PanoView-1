/*
     File: Shader.fsh
 Abstract:  Fragment shader that interpolate the uv coordinates (special treatment for the border
  Version: 1.0
 
 */


varying mediump vec2 texCoordVarying;
precision mediump float;
varying lowp float bdry;
varying float wrapR;

uniform sampler2D SamplerY;
uniform sampler2D SamplerUV;
uniform mat3 colorConversionMatrix;

void main()
{
	mediump vec3 yuv;
	lowp vec3 rgb;
    vec2 texCoord = texCoordVarying;
    texCoord.x += wrapR * sign(bdry);
    texCoord = texCoord - floor(texCoord);
	yuv.x = (texture2D(SamplerY, texCoord).r - (16.0/255.0));
	yuv.yz = (texture2D(SamplerUV, texCoord).rg - vec2(0.5, 0.5));
	rgb = colorConversionMatrix * yuv;
	gl_FragColor = vec4(rgb,1);
	
}

/*
 
 #define PI 3.14159265
 #define TWOPI 6.2831853
 #define SCALE 1.0

uniform float longitude;
uniform float lattitude;
uniform int viewChoice;
uniform float cos_theta;
uniform float cos_alpha;
uniform float sin_theta;
uniform float sin_alpha;

void main()
{
    mediump vec3 yuv;
	lowp vec3 rgb;
    
	float u = (texCoordVarying.x - 0.5) * 1.77778; // (1920.0 / 1080.0);
	float v = texCoordVarying.y - 0.5;
	
	float x = cos_theta * cos_alpha + u * sin_alpha - v * sin_theta * cos_alpha;
	float y = cos_theta * sin_alpha - u * cos_alpha - v * sin_theta * sin_alpha;
	float z = sin_theta + v * cos_theta;

    float theta_ = atan ( z / (sqrt(x*x + y * y)));
 	float alpha_ = atan ( y / x );

    float xc = clamp(sign(x), 0.0, 1.0);
    float yc = clamp(sign(y), 0.0, 1.0);
    alpha_ = mix(alpha_+PI, alpha_, xc) + xc * (1.0 - yc) * TWOPI;
    
	vec2 texCoord;
	texCoord.x = alpha_ / TWOPI ;
	texCoord.y = theta_ / PI + 0.5;


	yuv.x = (texture2D(SamplerY, texCoord).r - (16.0/255.0));
	yuv.yz = (texture2D(SamplerUV, texCoord).rg - vec2(0.5, 0.5));
    
	rgb = colorConversionMatrix * yuv;

//    rgb = texture2D(SamplerY, texCoord).rgb;
	
	gl_FragColor = vec4(rgb,1);
}


void pano()
{
	mediump vec3 yuv;
	lowp vec3 rgb;

	float u = (texCoordVarying.x - 0.5) * (1920.0 / 1080.0);
	float v = texCoordVarying.y - 0.5;
	
	float x = SCALE * cos_theta * cos_alpha + u * sin_alpha - v * sin_theta * cos_alpha;
	float y = SCALE * cos_theta * sin_alpha - u * cos_alpha - v * sin_theta * sin_alpha;
	float z = SCALE * sin_theta + v * cos_theta;
	
	float theta_ = atan( z / (sqrt(x*x + y*y)) );
	float alpha_ = atan( y / x );
	if (x < 0.0 )
		alpha_ += PI;
	else if ( y < 0.0 )
		alpha_ += TWOPI;

	vec2 texCoord;
	texCoord.x = alpha_ / TWOPI ;
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
	float alpha = longitude * TWOPI;
	
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
	texCoord.x = alpha_ / TWOPI ;
	texCoord.y = (theta_ + PI / 2.0 ) / PI ;
	texCoord.x = texCoord.x - floor(texCoord.x); 

	yuv.x = (texture2D(SamplerY, texCoord).r - (16.0/255.0));
	yuv.yz = (texture2D(SamplerUV, texCoord).rg - vec2(0.5, 0.5));
	rgb = colorConversionMatrix * yuv;
	gl_FragColor = vec4(rgb,1);
}

void main()
{
    panoWithBuffer();

	if (viewChoice == 0)
		// pano();
        panoWithBuffer();
	else if (viewChoice == 1)
		littleplanet();
	else if (viewChoice == 2)
		origView();

 }
 */
