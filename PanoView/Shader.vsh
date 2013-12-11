/*
     File: Shader.vsh
 Abstract:  Vertex shader that passes attributes through to fragment shader. 
  Version: 1.1

 */

#define PI 3.14159265
#define TWOPI 6.2831853
#define SCALE 0.8

attribute vec4 position;
attribute vec2 texCoord;
uniform float preferredRotation;

uniform float cos_theta;
uniform float cos_alpha;
uniform float sin_theta;
uniform float sin_alpha;

uniform float longitude;
uniform float lattitude;
uniform float scale;
uniform int viewChoice;

varying vec2 texCoordVarying;
varying lowp float bdry;
varying float wrapR;


void pano()
{
    float u = (0.5 - texCoord.x) * 1.77778; // (1920.0 / 1080.0);
    float v = texCoord.y - 0.5;
 
    float x = scale * cos_theta * cos_alpha + u * sin_alpha - v * sin_theta * cos_alpha;
	float y = scale * cos_theta * sin_alpha - u * cos_alpha - v * sin_theta * sin_alpha;
	float z = scale * sin_theta + v * cos_theta;

    float theta_ = atan ( z / (sqrt(x*x + y * y)));
    float alpha_ = atan ( y / x );
    float xc = clamp(sign(x), 0.0, 1.0);
    float yc = clamp(sign(y), 0.0, 1.0);
    alpha_ = mix(alpha_+PI, alpha_, xc) + xc * (1.0 - yc) * TWOPI;
    texCoordVarying.x = alpha_ / TWOPI ;
    texCoordVarying.y = theta_ / PI + 0.5;
    bdry = clamp(sign(0.1 - texCoordVarying.x), 0.0, 1.0);
    wrapR = clamp(sign(0.2 - texCoordVarying.x), 0.0, 1.0);
}

void littleplanet()
{
    
	float alpha = longitude * TWOPI;
	
	float u = (texCoord.x - 0.5) * 8.0 * 1.77778; // (1920.0 / 1080.0);
	float v = (texCoord.y - 0.5) * 8.0;
    
	float rho = sqrt( u * u + v * v);
	float c = 2.0 * atan( rho / 2.0 / (SCALE*1.25)); // SCALE is the radius
	float sinc = sin(c);
	float cosc = cos(c);
 
	float theta_ = asin(cosc*sin_theta + v*sinc*cos_theta / rho);
	float y = u*sinc;
	float x = (rho * cos_theta * cosc - v * sin_theta * sinc );
	float alpha_ = alpha + atan(y/x);
	if ( x < 0.0 )
        alpha_ += PI;
    
	// normalize
	texCoordVarying.x = alpha_ / TWOPI ;
	texCoordVarying.y = (theta_ + PI / 2.0 ) / PI ;
	texCoordVarying.x = texCoordVarying.x - floor(texCoordVarying.x);
   
    bdry = clamp(sign(0.1 - texCoordVarying.x), 0.0, 1.0);
    wrapR = clamp(sign(0.2 - texCoordVarying.x), 0.0, 1.0);
}

void origView()
{
    texCoordVarying = texCoord;
    bdry = 0.0;
    wrapR = 0.0;
}

void main()
{
	mat4 rotationMatrix = mat4( cos(preferredRotation), -sin(preferredRotation), 0.0, 0.0,
							    sin(preferredRotation),  cos(preferredRotation), 0.0, 0.0,
												   0.0,					    0.0, 1.0, 0.0,
												   0.0,					    0.0, 0.0, 1.0);
	gl_Position = position * rotationMatrix;
    
    if (viewChoice == 0)
        pano();
	else if (viewChoice == 1)
        littleplanet();
	else
        origView();
}

/*
void main()
{
	mat4 rotationMatrix = mat4( cos(preferredRotation), -sin(preferredRotation), 0.0, 0.0,
    sin(preferredRotation),  cos(preferredRotation), 0.0, 0.0,
    0.0,					    0.0, 1.0, 0.0,
    0.0,					    0.0, 0.0, 1.0);
	gl_Position = position * rotationMatrix;
	texCoordVarying = texCoord;
}
*/
