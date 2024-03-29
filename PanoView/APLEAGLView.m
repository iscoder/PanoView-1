/*
     File: APLEAGLView.m
 Abstract:  This class contains an UIView backed by a CAEAGLLayer. It handles rendering input textures to the view. The object loads, compiles and links the fragment and vertex shader to be used during rendering.
  Version: 1.1
 
 */

#import "APLEAGLView.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVUtilities.h>
#import <mach/mach_time.h>
#import <sys/utsname.h>

// Uniform index.
enum
{
	UNIFORM_Y,
	UNIFORM_UV,
	UNIFORM_LONGITUDE,
	UNIFORM_LATTITUDE,
    UNIFORM_SCALE,
	UNIFORM_ROTATION_ANGLE,
    UNIFORM_VIEW_CHOICE,
    UNIFORM_SIN_ALPHA,
    UNIFORM_SIN_THETA,
    UNIFORM_COS_ALPHA,
    UNIFORM_COS_THETA,
    UNIFORM_ASRATIO,
	UNIFORM_COLOR_CONVERSION_MATRIX,
	NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
	ATTRIB_VERTEX,
	ATTRIB_TEXCOORD,
	NUM_ATTRIBUTES
};

// Color Conversion Constants (YUV to RGB) including adjustment from 16-235/16-240 (video range)

// BT.601, which is the standard for SDTV.
static const GLfloat kColorConversion601[] = {
		1.164,  1.164, 1.164,
		  0.0, -0.392, 2.017,
		1.596, -0.813,   0.0,
};

// BT.709, which is the standard for HDTV.
static const GLfloat kColorConversion709[] = {
		1.164,  1.164, 1.164,
		  0.0, -0.213, 2.112,
		1.793, -0.533,   0.0,
};

@interface APLEAGLView ()
{
	// The pixel dimensions of the CAEAGLLayer.
	GLint _backingWidth;
	GLint _backingHeight;

	EAGLContext *_context;
	CVOpenGLESTextureRef _lumaTexture;
	CVOpenGLESTextureRef _chromaTexture;
	CVOpenGLESTextureCacheRef _videoTextureCache;
	
	GLuint _frameBufferHandle;
	GLuint _colorBufferHandle;
	
	const GLfloat *_preferredConversion;
    bool use64Shader;
}

@property GLuint program;

- (void)setupBuffers;
- (void)cleanUpTextures;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)URL;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
- (NSString*)machineName;


@end

@implementation APLEAGLView

+ (Class)layerClass
{
	return [CAEAGLLayer class];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder]))
	{
		// Use 2x scale factor on Retßina displays.
		self.contentScaleFactor = [[UIScreen mainScreen] scale];

		// Get and configure the layer.
		CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;

		eaglLayer.opaque = TRUE;
		eaglLayer.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking :[NSNumber numberWithBool:NO],
										  kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8};

		// Set the context into which the frames will be drawn.
		_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

		if (!_context || ![EAGLContext setCurrentContext:_context] || ![self loadShaders]) {
			return nil;
		}
		
		// Set the default conversion to BT.709, which is the standard for HDTV.
		_preferredConversion = kColorConversion709;
        
        
        NSString* deviceName = [self machineName];
        NSLog(@"device Name");
        NSLog(deviceName);

        use64Shader = [deviceName isEqualToString:@"iPhone6,1"] ||      // iPhone 5s
                      [deviceName isEqualToString:@"iPhone6,2"] ||
                      [deviceName isEqualToString:@"iPad4,1"] ||        // iPad Air
                      [deviceName isEqualToString:@"iPad4,2"] ||
                      [deviceName isEqualToString:@"iPad4,4"] ||        // iPad Mini 2nd Gen
                      [deviceName isEqualToString:@"iPad4,5"] ;
	}
	return self;
}

- (NSString*) machineName
{
    struct utsname systemInfo;
    uname(&systemInfo);
    
    return [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];
}

# pragma mark - OpenGL setup

- (void)setupGL
{
	[EAGLContext setCurrentContext:_context];
	[self setupBuffers];
	[self loadShaders];
	
	glUseProgram(self.program);
	
	// 0 and 1 are the texture IDs of _lumaTexture and _chromaTexture respectively.
	glUniform1i(uniforms[UNIFORM_Y], 0);
	glUniform1i(uniforms[UNIFORM_UV], 1);
	glUniform1f(uniforms[UNIFORM_LONGITUDE], self.longitude);
	glUniform1f(uniforms[UNIFORM_LATTITUDE], self.lattitude);
    glUniform1f(uniforms[UNIFORM_SCALE], self.scale);
	glUniform1f(uniforms[UNIFORM_ROTATION_ANGLE], self.preferredRotation);
    glUniform1i(uniforms[UNIFORM_VIEW_CHOICE], self.viewChoice);
    glUniform1f(uniforms[UNIFORM_SIN_ALPHA], self.sin_alpha);
    glUniform1f(uniforms[UNIFORM_COS_ALPHA], self.cos_alpha);
    glUniform1f(uniforms[UNIFORM_SIN_THETA], self.sin_theta);
    glUniform1f(uniforms[UNIFORM_COS_THETA], self.cos_theta);
    glUniform1f(uniforms[UNIFORM_ASRATIO], (float)(_backingWidth) / _backingHeight);
	glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
	
	// Create CVOpenGLESTextureCacheRef for optimal CVPixelBufferRef to GLES texture conversion.
	if (!_videoTextureCache) {
		CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
		if (err != noErr) {
			NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
			return;
		}
	}
}

#pragma mark - Utilities

- (void)setupBuffers
{
	glDisable(GL_DEPTH_TEST);
	
	glEnableVertexAttribArray(ATTRIB_VERTEX);
	glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
	
	glEnableVertexAttribArray(ATTRIB_TEXCOORD);
	glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
	
	glGenFramebuffers(1, &_frameBufferHandle);
	glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
	
	glGenRenderbuffers(1, &_colorBufferHandle);
	glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
	
	[_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);


    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorBufferHandle);
    
    GLenum errorcode = glCheckFramebufferStatus(GL_FRAMEBUFFER);

    switch (errorcode) {
        case GL_FRAMEBUFFER_COMPLETE: // good
            break;
        case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT: // incomplete attachment
            NSLog(@"Failed to make complete framebuffer object: GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT");
            break;
        default:
            NSLog(@"Failed to make complete framebuffer object %x", errorcode);
            break;
    }
/*
	if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
		NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
	}
 */
}

- (void)cleanUpTextures
{
	if (_lumaTexture) {
		CFRelease(_lumaTexture);
		_lumaTexture = NULL;
	}
	
	if (_chromaTexture) {
		CFRelease(_chromaTexture);
		_chromaTexture = NULL;
	}
	
	// Periodic texture cache flush every frame
	CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
}

- (void)dealloc
{
	[self cleanUpTextures];
	
	if(_videoTextureCache) {
		CFRelease(_videoTextureCache);
	}
}

#pragma mark - OpenGLES drawing

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
	CVReturn err;
	if (pixelBuffer != NULL) {
		int frameWidth = CVPixelBufferGetWidth(pixelBuffer);
		int frameHeight = CVPixelBufferGetHeight(pixelBuffer);
		
		if (!_videoTextureCache) {
			NSLog(@"No video texture cache");
			return;
		}
		
		[self cleanUpTextures];
		
		
		/*
		 Use the color attachment of the pixel buffer to determine the appropriate color conversion matrix.
		 */
		CFTypeRef colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
		
		if (colorAttachments == kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
			_preferredConversion = kColorConversion601;
		}
		else {
			_preferredConversion = kColorConversion709;
		}
		
		/*
         CVOpenGLESTextureCacheCreateTextureFromImage will create GLES texture optimally from CVPixelBufferRef.
         */
		
		/*
         Create Y and UV textures from the pixel buffer. These textures will be drawn on the frame buffer Y-plane.
         */
		glActiveTexture(GL_TEXTURE0);
		err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
														   _videoTextureCache,
														   pixelBuffer,
														   NULL,
														   GL_TEXTURE_2D,
														   GL_RED_EXT,
														   frameWidth,
														   frameHeight,
														   GL_RED_EXT,
														   GL_UNSIGNED_BYTE,
														   0,
														   &_lumaTexture);
		if (err) {
			NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
		}
		
		glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		
		// UV-plane.
		glActiveTexture(GL_TEXTURE1);
		err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
														   _videoTextureCache,
														   pixelBuffer,
														   NULL,
														   GL_TEXTURE_2D,
														   GL_RG_EXT,
														   frameWidth / 2,
														   frameHeight / 2,
														   GL_RG_EXT,
														   GL_UNSIGNED_BYTE,
														   1,
														   &_chromaTexture);
		if (err) {
			NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
		}
		
		glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		
		glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
		
		// Set the view port to the entire view.
		glViewport(0, 0, _backingWidth, _backingHeight);
		
		CFRelease(pixelBuffer);
	}
	
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);
	
	// Use shader program.
	glUseProgram(self.program);
	glUniform1f(uniforms[UNIFORM_LONGITUDE], self.longitude);
	glUniform1f(uniforms[UNIFORM_LATTITUDE], self.lattitude);
    glUniform1f(uniforms[UNIFORM_SCALE], self.scale);
	glUniform1f(uniforms[UNIFORM_ROTATION_ANGLE], self.preferredRotation);
    glUniform1i(uniforms[UNIFORM_VIEW_CHOICE], self.viewChoice);
    glUniform1f(uniforms[UNIFORM_SIN_ALPHA], self.sin_alpha);
    glUniform1f(uniforms[UNIFORM_COS_ALPHA], self.cos_alpha);
    glUniform1f(uniforms[UNIFORM_SIN_THETA], self.sin_theta);
    glUniform1f(uniforms[UNIFORM_COS_THETA], self.cos_theta);
    glUniform1f(uniforms[UNIFORM_ASRATIO], (float)_backingWidth / _backingHeight);
	glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
	
	// Set up the quad vertices with respect to the orientation and aspect ratio of the video.
    CGSize tt = CGSizeMake(_backingWidth, _backingHeight);
	CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(tt, self.layer.bounds);
	
	// Compute normalized quad coordinates to draw the frame into.
	CGSize normalizedSamplingSize = CGSizeMake(0.0, 0.0);
	CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/self.layer.bounds.size.width, vertexSamplingRect.size.height/self.layer.bounds.size.height);
	
	// Normalize the quad vertices.
	if (cropScaleAmount.width > cropScaleAmount.height) {
		normalizedSamplingSize.width = 1.0;
		normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
	}
	else {
		normalizedSamplingSize.width = 1.0;
		normalizedSamplingSize.height = cropScaleAmount.width/cropScaleAmount.height;
	}
	
	/*
     The quad vertex data defines the region of 2D plane onto which we draw our pixel buffers.
     Vertex data formed using (-1,-1) and (1,1) as the bottom left and top right coordinates respectively, covers the entire screen.
     */
    if (use64Shader)
    {
        GLfloat quadVertexData [] = {
            -1 * normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
                normalizedSamplingSize.width, -1 * normalizedSamplingSize.height,
            -1 * normalizedSamplingSize.width, normalizedSamplingSize.height,
                normalizedSamplingSize.width, normalizedSamplingSize.height,
        };
	
        // Update attribute values.
        glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, quadVertexData);
        glEnableVertexAttribArray(ATTRIB_VERTEX);

        /*
         The texture vertices are set up such that we flip the texture vertically. This is so that our top left origin buffers match OpenGL's bottom left texture coordinate system.
         */
        CGRect textureSamplingRect = CGRectMake(0, 0, 1, 1);
        GLfloat quadTextureData[] =  {
            CGRectGetMinX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
            CGRectGetMaxX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
            CGRectGetMinX(textureSamplingRect), CGRectGetMinY(textureSamplingRect),
            CGRectGetMaxX(textureSamplingRect), CGRectGetMinY(textureSamplingRect)
        };
	
        glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, 0, 0, quadTextureData);
        glEnableVertexAttribArray(ATTRIB_TEXCOORD);
	
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    else // optimized shader -- used for older devices
    {
        const int panoSampleW = 80;
        const int panoSampleH = 80;
        GLfloat quadVertexData [panoSampleW * panoSampleH * 2];
        GLfloat quadTextureData[panoSampleW * panoSampleH * 2];
        for (int i = 0; i < panoSampleW; i++)
        {
            for ( int j = 0; j < panoSampleH; j++)
            {
                quadVertexData[i*panoSampleH*2+j*2] = ((float)j / (panoSampleH-1) * 2.0 - 1) * normalizedSamplingSize.width;
                quadVertexData[i*panoSampleH*2+j*2+1] = ( (float)i / (panoSampleW-1) * 2.0 - 1) * normalizedSamplingSize.height;
                
                quadTextureData[i*panoSampleH*2+j*2] = (float)j / (panoSampleH-1);
                quadTextureData[i*panoSampleH*2+j*2+1] = 1.0 - (float)i / (panoSampleW-1);
            }
        }
        // Update attribute values.
        glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, quadVertexData);
        glEnableVertexAttribArray(ATTRIB_VERTEX);
        
        glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, 0, 0, quadTextureData);
        glEnableVertexAttribArray(ATTRIB_TEXCOORD);
        
        // glDrawArrays(GL_TRIANGLE_STRIP, 0, panoSample*panoSample);
        GLuint indices [(panoSampleH-1)*(panoSampleW-1)*6];
        for (int i = 1; i < panoSampleH; i++)
        {
            for ( int j = 1; j < panoSampleW; j++)
            {
                int base = ((i-1) * (panoSampleW-1) + (j-1)) * 6;
                indices[base] = (j-1) * panoSampleH + i-1;
                indices[base+1] = (j-1) * panoSampleH + i;
                indices[base+2] = j*panoSampleH + (i-1);
                indices[base+3] = (j-1) * panoSampleH + i;
                indices[base+4] = j*panoSampleH + (i-1);
                indices[base+5] = j*panoSampleH + i;
            }
        }
        glDrawElements(GL_TRIANGLES, (panoSampleH-1)*(panoSampleW-1)*6, GL_UNSIGNED_INT,indices);
    }

	glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
	[_context presentRenderbuffer:GL_RENDERBUFFER];
}


#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
	GLuint vertShader, fragShader;
	NSURL *vertShaderURL, *fragShaderURL;
	
	// Create the shader program.
	self.program = glCreateProgram();
    
    NSString *shaderName = @"Shader";
    if (use64Shader) {
        shaderName = @"Shader64";
    }

	
	// Create and compile the vertex shader.
	vertShaderURL = [[NSBundle mainBundle] URLForResource:shaderName withExtension:@"vsh"];
	if (![self compileShader:&vertShader type:GL_VERTEX_SHADER URL:vertShaderURL]) {
		NSLog(@"Failed to compile vertex shader");
		return NO;
	}
	
	// Create and compile fragment shader.
	fragShaderURL = [[NSBundle mainBundle] URLForResource:shaderName withExtension:@"fsh"];
	if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER URL:fragShaderURL]) {
		NSLog(@"Failed to compile fragment shader");
		return NO;
	}
	
	// Attach vertex shader to program.
	glAttachShader(self.program, vertShader);
	
	// Attach fragment shader to program.
	glAttachShader(self.program, fragShader);
	
	// Bind attribute locations. This needs to be done prior to linking.
	glBindAttribLocation(self.program, ATTRIB_VERTEX, "position");
	glBindAttribLocation(self.program, ATTRIB_TEXCOORD, "texCoord");
	
	// Link the program.
	if (![self linkProgram:self.program]) {
		NSLog(@"Failed to link program: %d", self.program);
		
		if (vertShader) {
			glDeleteShader(vertShader);
			vertShader = 0;
		}
		if (fragShader) {
			glDeleteShader(fragShader);
			fragShader = 0;
		}
		if (self.program) {
			glDeleteProgram(self.program);
			self.program = 0;
		}
		
		return NO;
	}
	
	// Get uniform locations.
	uniforms[UNIFORM_Y] = glGetUniformLocation(self.program, "SamplerY");
	uniforms[UNIFORM_UV] = glGetUniformLocation(self.program, "SamplerUV");
	uniforms[UNIFORM_LONGITUDE] = glGetUniformLocation(self.program, "longitude");
	uniforms[UNIFORM_LATTITUDE] = glGetUniformLocation(self.program, "lattitude");
    uniforms[UNIFORM_SCALE] = glGetUniformLocation(self.program, "scale");
	uniforms[UNIFORM_ROTATION_ANGLE] = glGetUniformLocation(self.program, "preferredRotation");
    uniforms[UNIFORM_VIEW_CHOICE] = glGetUniformLocation(self.program, "viewChoice");
    uniforms[UNIFORM_SIN_ALPHA] = glGetUniformLocation(self.program, "sin_alpha");
    uniforms[UNIFORM_COS_ALPHA] = glGetUniformLocation(self.program, "cos_alpha");
    uniforms[UNIFORM_SIN_THETA] = glGetUniformLocation(self.program, "sin_theta");
    uniforms[UNIFORM_COS_THETA] = glGetUniformLocation(self.program, "cos_theta");
    uniforms[UNIFORM_ASRATIO] = glGetUniformLocation(self.program, "asRatio");
    
	uniforms[UNIFORM_COLOR_CONVERSION_MATRIX] = glGetUniformLocation(self.program, "colorConversionMatrix");
	
	// Release vertex and fragment shaders.
	if (vertShader) {
		glDetachShader(self.program, vertShader);
		glDeleteShader(vertShader);
	}
	if (fragShader) {
		glDetachShader(self.program, fragShader);
		glDeleteShader(fragShader);
	}
	
	return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)URL
{
    NSError *error;
    NSString *sourceString = [[NSString alloc] initWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:&error];
    if (sourceString == nil) {
		NSLog(@"Failed to load vertex shader: %@", [error localizedDescription]);
        return NO;
    }
    
	GLint status;
	const GLchar *source;
	source = (GLchar *)[sourceString UTF8String];
	
	*shader = glCreateShader(type);
	glShaderSource(*shader, 1, &source, NULL);
	glCompileShader(*shader);
	
#if defined(DEBUG)
	GLint logLength;
	glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) {
		GLchar *log = (GLchar *)malloc(logLength);
		glGetShaderInfoLog(*shader, logLength, &logLength, log);
		NSLog(@"Shader compile log:\n%s", log);
		free(log);
	}
#endif
	
	glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
	if (status == 0) {
		glDeleteShader(*shader);
		return NO;
	}
	
	return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
	GLint status;
	glLinkProgram(prog);
	
#if defined(DEBUG)
	GLint logLength;
	glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) {
		GLchar *log = (GLchar *)malloc(logLength);
		glGetProgramInfoLog(prog, logLength, &logLength, log);
		NSLog(@"Program link log:\n%s", log);
		free(log);
	}
#endif
	
	glGetProgramiv(prog, GL_LINK_STATUS, &status);
	if (status == 0) {
		return NO;
	}
	
	return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
	GLint logLength, status;
	
	glValidateProgram(prog);
	glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) {
		GLchar *log = (GLchar *)malloc(logLength);
		glGetProgramInfoLog(prog, logLength, &logLength, log);
		NSLog(@"Program validate log:\n%s", log);
		free(log);
	}
	
	glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
	if (status == 0) {
		return NO;
	}
	
	return YES;
}

- (void)updateInternal
{
	float theta = self.lattitude * PI - PI / 2.0;
	float alpha = self.longitude * 2.0 * PI;
	self.cos_alpha = cos(alpha);
    self.sin_alpha = sin(alpha);
    self.cos_theta = cos(theta);
    self.sin_theta = sin(theta);
}

@end

