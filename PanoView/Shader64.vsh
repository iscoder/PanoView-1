/*
     File: Shader64.vsh
 Abstract:  Vertex shader that passes attributes through to fragment shader. 
  Version: 1.1

 */

#define PI 3.14159265
#define TWOPI 6.2831853
#define SCALE 0.8

attribute vec4 position;
attribute vec2 texCoord;
uniform float preferredRotation;

varying vec2 texCoordVarying;

void main()
{
	mat4 rotationMatrix = mat4( cos(preferredRotation), -sin(preferredRotation), 0.0, 0.0,
							    sin(preferredRotation),  cos(preferredRotation), 0.0, 0.0,
												   0.0,					    0.0, 1.0, 0.0,
												   0.0,					    0.0, 0.0, 1.0);
	gl_Position = position * rotationMatrix;
	texCoordVarying = texCoord;
}

