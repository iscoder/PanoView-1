/*
     File: APLEAGLView.h
 Abstract:  This class contains an UIView backed by a CAEAGLLayer. It handles rendering input textures to the view. The object loads, compiles and links the fragment and vertex shader to be used during rendering.
  Version: 1.1
 
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

#import <UIKit/UIKit.h>

#define PI 3.14159265

@interface APLEAGLView : UIView

@property GLfloat preferredRotation;
@property CGSize presentationRect;
@property GLfloat chromaThreshold;
@property GLfloat lumaThreshold;
@property GLfloat lattitude;
@property GLfloat longitude;
@property CGPoint touchInit;
@property GLfloat prevLattitude;
@property GLfloat prevLongitude;
@property GLint   viewChoice;

@property GLfloat sin_theta;
@property GLfloat cos_theta;
@property GLfloat sin_alpha;
@property GLfloat cos_alpha;

- (void)setupGL;
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)updateInternal;

@end
