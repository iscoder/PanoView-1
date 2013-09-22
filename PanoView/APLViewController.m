/*
     File: APLViewController.m
 Abstract: This view controller handles the UI to load assets for playback and for adjusting the luma and chroma values. It also sets up the AVPlayerItemVideoOutput, from which CVPixelBuffers are pulled out and sent to the shaders for rendering.
  Version: 1.0
 
 */

#import "APLViewController.h"
#import "APLEAGLView.h"
#import <MobileCoreServices/MobileCoreServices.h>

# define ONE_FRAME_DURATION 0.03
# define LUMA_SLIDER_TAG 0
# define CHROMA_SLIDER_TAG 1

static void *AVPlayerItemStatusContext = &AVPlayerItemStatusContext;


@interface APLViewController ()
{
	AVPlayer *_player;
	dispatch_queue_t _myVideoOutputQueue;
	id _notificationToken;
    id _timeObserver;
    float mRestoreAfterScrubbingRate;
    bool mViewIsChanging;
    bool mControlModeIsFinger; // true for finger only, false for motion
    
    float motionRefLongitude;
    float motionRefLattitude;
    bool motionRefLongitudeIsSet;
    
    CMMotionManager *motionManager;
    NSTimer *gyroTimer;
}

@property (nonatomic, weak) IBOutlet APLEAGLView *playerView;
@property UIPopoverController *popover;
@property AVPlayerItemVideoOutput *videoOutput;
@property CADisplayLink *displayLink;

- (IBAction)playPlayer:(id)sender;
- (IBAction)goBackToMyVideoList:(id)sender;
- (IBAction)pausePlayer:(id)sender;
- (IBAction)handleTapGesture:(UITapGestureRecognizer *)tapGestureRecognizer;
- (IBAction)beginScrubbing:(id)sender;
- (IBAction)scrub:(id)sender;
- (IBAction)endScrubbing:(id)sender;
- (IBAction)rewind:(id)sender;

- (void)displayLinkCallback:(CADisplayLink *)sender;

@end


@implementation APLViewController

@synthesize theMovieURL, mPlayButton, mStopButton, mToolbar, mTopBar, mScrubber;
@synthesize mCurrentTime, mDuration;

#pragma mark -

- (void)viewDidLoad
{
	[super viewDidLoad];
	
    self.playerView.longitude = 0.5;
    self.playerView.lattitude = 0.5;
    [self.playerView updateInternal];

	_player = [[AVPlayer alloc] init];
    // [self addTimeObserverToPlayer];

	// Setup CADisplayLink which will callback displayPixelBuffer: at every vsync.
	self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
	[[self displayLink] addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	
	
	// Setup AVPlayerItemVideoOutput with the required pixelbuffer attributes.
	NSDictionary *pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
	self.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
	_myVideoOutputQueue = dispatch_queue_create("myVideoOutputQueue", DISPATCH_QUEUE_SERIAL);
	[[self videoOutput] setDelegate:self queue:_myVideoOutputQueue];
    
    
    
    // add scrubber and duration to toolbar
    UIBarButtonItem *scrubberItem = [[UIBarButtonItem alloc] initWithCustomView:self.mScrubber];
    UIBarButtonItem *durationItem = [[UIBarButtonItem alloc] initWithCustomView:self.mDuration];
    [durationItem setWidth:110];
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mToolbar items]];
    [toolbarItems addObject:scrubberItem];
    [toolbarItems addObject:durationItem];
    [toolbarItems addObject:mPlayButton];
    self.mToolbar.items = toolbarItems;
    
    motionManager = [[CMMotionManager alloc] init];
    mViewIsChanging = false;
    mControlModeIsFinger = true;
}

-(void)startGyro {
    [motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical];
    gyroTimer = [NSTimer scheduledTimerWithTimeInterval:1/30.0
												 target:self
											   selector:@selector(doGyroUpdate)
											   userInfo:nil
												repeats:YES];
    motionRefLongitudeIsSet = false;
    mViewIsChanging = true;
}

-(void)stopGyro {
    [motionManager stopDeviceMotionUpdates];
    [gyroTimer invalidate];
    mViewIsChanging = false;
}


-(void)doGyroUpdate {
	CMDeviceMotion *deviceMotion = motionManager.deviceMotion;
    CMAttitude *attitude = deviceMotion.attitude;
    // CMAttitude *invattitude = attitude multiplyByInverseOfAttitude:attitude;
    
    float invm[3][3];
    invm[0][0] = attitude.rotationMatrix.m22 * attitude.rotationMatrix.m33 - attitude.rotationMatrix.m23 * attitude.rotationMatrix.m32;
    invm[0][1] = attitude.rotationMatrix.m13 * attitude.rotationMatrix.m32 - attitude.rotationMatrix.m12 * attitude.rotationMatrix.m33;
    invm[0][2] = attitude.rotationMatrix.m12 * attitude.rotationMatrix.m23 - attitude.rotationMatrix.m13 * attitude.rotationMatrix.m22;
    
    invm[1][0] = attitude.rotationMatrix.m23 * attitude.rotationMatrix.m31 - attitude.rotationMatrix.m21 * attitude.rotationMatrix.m33;
    invm[1][1] = attitude.rotationMatrix.m11 * attitude.rotationMatrix.m33 - attitude.rotationMatrix.m13 * attitude.rotationMatrix.m31;
    invm[1][2] = attitude.rotationMatrix.m13 * attitude.rotationMatrix.m21 - attitude.rotationMatrix.m11 * attitude.rotationMatrix.m23;
    
    invm[2][0] = attitude.rotationMatrix.m21 * attitude.rotationMatrix.m32 - attitude.rotationMatrix.m22 * attitude.rotationMatrix.m31;
    invm[2][1] = attitude.rotationMatrix.m12 * attitude.rotationMatrix.m31 - attitude.rotationMatrix.m11 * attitude.rotationMatrix.m32;
    invm[2][2] = attitude.rotationMatrix.m11 * attitude.rotationMatrix.m22 - attitude.rotationMatrix.m12 * attitude.rotationMatrix.m21;
    
    
    if (!(invm[0][2] == 0.0 && invm[1][2] == 0.0 && invm[0][0] == 0))
    {
        if (!motionRefLongitudeIsSet)
        {
            motionRefLongitude = atan2f(invm[0][2], invm[1][2]);
            motionRefLattitude = asin(invm[2][2]);
            motionRefLongitudeIsSet = true;
        }
        else
        {
            float longy = atan2f(invm[0][2], invm[1][2]);
            self.playerView.longitude += (motionRefLongitude - longy) / M_PI;
            self.playerView.longitude -= floorf(self.playerView.longitude);
            motionRefLongitude = longy;
            
            float latte = asin(invm[2][2]);
            self.playerView.lattitude += (latte - motionRefLattitude) / M_PI;
            self.playerView.lattitude = MAX(0.0, MIN(1.0, self.playerView.lattitude));
            motionRefLattitude = latte;
        }
    }

    [self.playerView updateInternal];

    
/*
    NSLog(@"\n%f %f %f \n%f %f %f\n%f %f %f "
          , attitude.rotationMatrix.m11, attitude.rotationMatrix.m12, attitude.rotationMatrix.m13
          , attitude.rotationMatrix.m21, attitude.rotationMatrix.m22, attitude.rotationMatrix.m23
          , attitude.rotationMatrix.m31, attitude.rotationMatrix.m32, attitude.rotationMatrix.m33);
*/
    /*
    NSLog(@"\n%f %f %f \n%f %f %f\n%f %f %f "
          , invm[0][0], invm[0][1], invm[0][2]
          , invm[1][0], invm[1][1], invm[1][2]
          , invm[2][0], invm[2][1], invm[2][2] );
    */
    
    
  
//    NSLog(@"%f %f %f", attitude.roll, attitude.yaw, attitude.pitch);
//    self.playerView.longitude = attitude.roll;
//    [self.playerView updateInternal];
}


- (void)viewWillAppear:(BOOL)animated
{
	[self addObserver:self forKeyPath:@"player.currentItem.status" options:NSKeyValueObservingOptionNew context:AVPlayerItemStatusContext];
    [self loadMovie];
    
    if (controlChoice.selectedSegmentIndex == 1)
        [self startGyro];
    
   //® [[UIApplication sharedApplication] setStatusBarHidden:YES animated:NO];
    /*
    if (self.needRotation)
    {
        self.view.transform = CGAffineTransformIdentity;
        self.view.transform = CGAffineTransformMakeRotation(M_PI_2);
        self.view.bounds = CGRectMake(0.0, 0.0, 480,320);
    }
     */
}

- (void)viewWillDisappear:(BOOL)animated
{
	[self removeObserver:self forKeyPath:@"player.currentItem.status" context:AVPlayerItemStatusContext];
	[self removeTimeObserverFromPlayer];
    if (controlChoice.selectedSegmentIndex == 1)
        [self stopGyro];
	
	if (_notificationToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_notificationToken name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
		_notificationToken = nil;
	}
}

#pragma mark - Utilities

/* Show the stop button in the movie player controller. */
-(void)showStopButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mToolbar items]];
    [toolbarItems replaceObjectAtIndex:3 withObject:self.mStopButton];
    self.mToolbar.items = toolbarItems;
}

/* Show the play button in the movie player controller. */
-(void)showPlayButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mToolbar items]];
    [toolbarItems replaceObjectAtIndex:3 withObject:self.mPlayButton];
    self.mToolbar.items = toolbarItems;
}

- (IBAction)pausePlayer:(id)sender
{
    [_player pause];
    [self showPlayButton];
}

- (void) loadMovie
{
    // this is for running test on the simulator: load directly Movie.m4u
    [[self displayLink] setPaused:YES];
	[_player pause];
    
	if ([_player currentItem] == nil) {
		[[self playerView] setupGL];
	}
    
    [self setupPlaybackForURL:self.theMovieURL];
    [self initScrubberTimer];
    
    /*
     [[self displayLink] setPaused:YES];
     
     if ([[self popover] isPopoverVisible]) {
     [[self popover] dismissPopoverAnimated:YES];
     }
     
     if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
     self.popover = [[UIPopoverController alloc] initWithContentViewController:videoPicker];
     self.popover.delegate = self;
     [[self popover] presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionDown animated:YES];
     }
     else {
     [self presentViewController:videoPicker animated:YES completion:nil];
     }
     */
    
}

- (IBAction)goBackToMyVideoList:(id)sender
{
    [_player pause];
    [self rewind:nil];
	[[_player currentItem] removeOutput:self.videoOutput];
    [[self displayLink] setPaused:YES];

    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];

    /*
     
     if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
     [self.popover dismissPopoverAnimated:YES];
     }
     else {
     [self dismissViewControllerAnimated:YES completion:nil];
     }
	 */
}

- (IBAction)playPlayer:(id)sender
{
    [_player play];
    [self showStopButton];
}

- (IBAction)handleTapGesture:(UITapGestureRecognizer *)tapGestureRecognizer
{
	self.mToolbar.hidden = !self.mToolbar.hidden;
    self.mTopBar.hidden = !self.mTopBar.hidden;
}

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskLandscape;
}

#pragma mark - Playback setup

- (void)setupPlaybackForURL:(NSURL *)URL
{
	/*
	 Sets up player item and adds video output to it.
	 The tracks property of an asset is loaded via asynchronous key value loading, to access the preferred transform of a video track used to orientate the video while rendering.
	 After adding the video output, we request a notification of media change in order to restart the CADisplayLink.
	 */
	
	// Remove video output from old item, if any.
	[[_player currentItem] removeOutput:self.videoOutput];
    
    AVAsset *avasset = [AVAsset assetWithURL:URL];
    

	AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:avasset];
	AVAsset *asset = [item asset];
	
	[asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
		if ([asset statusOfValueForKey:@"tracks" error:nil] == AVKeyValueStatusLoaded) {
			NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
			if ([tracks count] > 0) {
				// Choose the first video track.
				AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
				[videoTrack loadValuesAsynchronouslyForKeys:@[@"preferredTransform"] completionHandler:^{
					
					if ([videoTrack statusOfValueForKey:@"preferredTransform" error:nil] == AVKeyValueStatusLoaded) {
						CGAffineTransform preferredTransform = [videoTrack preferredTransform];
						
						/*
                         The orientation of the camera while recording affects the orientation of the images received from an AVPlayerItemVideoOutput. Here we compute a rotation that is used to correctly orientate the video.
                         */
						self.playerView.preferredRotation = -1 * atan2(preferredTransform.b, preferredTransform.a);
						
						[self addDidPlayToEndTimeNotificationForPlayerItem:item];
						
						dispatch_async(dispatch_get_main_queue(), ^{
							[item addOutput:self.videoOutput];
							[_player replaceCurrentItemWithPlayerItem:item];
							[self.videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:ONE_FRAME_DURATION];
							// [_player play];
                            [self showPlayButton];
						});
					}
				}];
			}
		}
		
	}];
	
}

- (void)stopLoadingAnimationAndHandleError:(NSError *)error
{
	if (error) {
        NSString *cancelButtonTitle = NSLocalizedString(@"OK", @"Cancel button title for animation load error");
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription] message:[error localizedFailureReason] delegate:nil cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
		[alertView show];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == AVPlayerItemStatusContext) {
		AVPlayerStatus status = [change[NSKeyValueChangeNewKey] integerValue];
		switch (status) {
			case AVPlayerItemStatusUnknown:
				break;
			case AVPlayerItemStatusReadyToPlay:
				self.playerView.presentationRect = [[_player currentItem] presentationSize];
                // add duration display
                [self updateTimeLabel];
				break;
			case AVPlayerItemStatusFailed:
				[self stopLoadingAnimationAndHandleError:[[_player currentItem] error]];
				break;
		}
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)updateTimeLabel
{
    CMTime totalTime = [self playerItemDuration];
    CMTime currentTime = [_player currentTime];
    
    NSUInteger dTotalSeconds = CMTimeGetSeconds(totalTime);
    NSUInteger cTotalSeconds = CMTimeGetSeconds(currentTime);
    
    NSUInteger cHours = floor(cTotalSeconds / 3600);
    NSUInteger cMinutes = floor(cTotalSeconds % 3600 / 60);
    NSUInteger cSeconds = floor(cTotalSeconds % 60);
    
    NSUInteger dHours = floor(dTotalSeconds / 3600);
    NSUInteger dMinutes = floor(dTotalSeconds % 3600 / 60);
    NSUInteger dSeconds = floor(dTotalSeconds % 60);
    
    NSString *durationString = [NSString stringWithFormat:@"%i:%02i:%02i / %i:%02i:%02i"
                                , cHours, cMinutes, cSeconds
                                , dHours, dMinutes, dSeconds
                                ];
    [self.mDuration setText:durationString];
}

- (void)addDidPlayToEndTimeNotificationForPlayerItem:(AVPlayerItem *)item
{
	if (_notificationToken)
		_notificationToken = nil;
	
	/*
     Setting actionAtItemEnd to None prevents the movie from getting paused at item end. A very simplistic, and not gapless, looped playback.
     */
	// _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
	_notificationToken = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:item queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		// Simple item playback rewind.
		[self rewind:nil];
        [self showPlayButton];
	}];
}

- (void)rewind:(id)sender
{
    [[_player currentItem] seekToTime:kCMTimeZero];
    [mScrubber setValue:0];
}

- (void)removeTimeObserverFromPlayer
{
    if (_timeObserver)
    {
        [_player removeTimeObserver:_timeObserver];
        _timeObserver = nil;
    }
}

#pragma mark - CADisplayLink Callback

- (void)displayLinkCallback:(CADisplayLink *)sender
{
	/*
	 The callback gets called once every Vsync.
	 Using the display link's timestamp and duration we can compute the next time the screen will be refreshed, and copy the pixel buffer for that time
	 This pixel buffer can then be processed and later rendered on screen.
	 */
	CMTime outputItemTime = kCMTimeInvalid;
	
	// Calculate the nextVsync time which is when the screen will be refreshed next.
	CFTimeInterval nextVSync = ([sender timestamp] + [sender duration]);
	
	outputItemTime = [[self videoOutput] itemTimeForHostTime:nextVSync];
	
	if ([[self videoOutput] hasNewPixelBufferForItemTime:outputItemTime] || mViewIsChanging) {
		CVPixelBufferRef pixelBuffer = NULL;
		pixelBuffer = [[self videoOutput] copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
		
		[[self playerView] displayPixelBuffer:pixelBuffer];
	}
}

#pragma mark - AVPlayerItemOutputPullDelegate

- (void)outputMediaDataWillChange:(AVPlayerItemOutput *)sender
{
	// Restart display link.
	[[self displayLink] setPaused:NO];
}

# pragma mark - Popover Controller Delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
	// Make sure our playback is resumed from any interruption.
	if ([_player currentItem]) {
		[self addDidPlayToEndTimeNotificationForPlayerItem:[_player currentItem]];
	}
	[[self videoOutput] requestNotificationOfMediaDataChangeWithAdvanceInterval:ONE_FRAME_DURATION];
	[_player play];
	
	self.popover.delegate = nil;
}

#pragma mark - Gesture recognizer delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
	if (touch.view != self.view) {
		// Ignore touch on toolbar.
		return NO;
	}
	return YES;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    self.playerView.touchInit = [[touches anyObject] locationInView:self.playerView];
    
    self.playerView.prevLongitude = self.playerView.longitude;
    self.playerView.prevLattitude = self.playerView.lattitude;
    mViewIsChanging = true;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    CGPoint touchLocation = [[touches anyObject] locationInView:self.playerView];
    float xOffset = (touchLocation.x - self.playerView.touchInit.x) / 2.0;
    float yOffset = (touchLocation.y - self.playerView.touchInit.y) / 2.0;
    
    self.playerView.lattitude = MAX(0.0, MIN(1.0, self.playerView.prevLattitude - yOffset/self.playerView.layer.bounds.size.height));
    self.playerView.longitude = self.playerView.prevLongitude + xOffset / self.playerView.layer.bounds.size.width;
    self.playerView.longitude -= floorf(self.playerView.longitude);
    [self.playerView updateInternal];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    if (mControlModeIsFinger)
        mViewIsChanging = false;
}

-(IBAction)changeView{
    self.playerView.viewChoice = viewChoice.selectedSegmentIndex;
    if (viewChoice.selectedSegmentIndex == 0)
    {
        self.playerView.longitude = 0.5;
        self.playerView.lattitude = 0.5;
    }
    else if (viewChoice.selectedSegmentIndex == 1)
    {
        self.playerView.longitude = 0.5;
        self.playerView.lattitude = 1.0;
    }
    [self.playerView updateInternal];
}

-(IBAction)changeControl{
    if (controlChoice.selectedSegmentIndex == 0)
    {
        [self stopGyro];
        mControlModeIsFinger = true;
    }
    else
    {
        [self startGyro];
        mControlModeIsFinger = false;
    }
}

- (CMTime)playerItemDuration
{
	AVPlayerItem *playerItem = [_player currentItem];
	if (playerItem.status == AVPlayerItemStatusReadyToPlay)
	{
        /*
         NOTE:
         Because of the dynamic nature of HTTP Live Streaming Media, the best practice
         for obtaining the duration of an AVPlayerItem object has changed in iOS 4.3.
         Prior to iOS 4.3, you would obtain the duration of a player item by fetching
         the value of the duration property of its associated AVAsset object. However,
         note that for HTTP Live Streaming Media the duration of a player item during
         any particular playback session may differ from the duration of its asset. For
         this reason a new key-value observable duration property has been defined on
         AVPlayerItem.
         
         See the AV Foundation Release Notes for iOS 4.3 for more information.
         */
        
		return([playerItem duration]);
	}
	
	return(kCMTimeInvalid);
}

/* Requests invocation of a given block during media playback to update the movie scrubber control. */
-(void)initScrubberTimer
{
    if (_timeObserver)
        return;
	/* Update the scrubber during normal playback. */
    __weak APLViewController* weakSelf = self;
	_timeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.1, 10)
                                                                queue:NULL /* If you pass NULL, the main queue is used. */
                                                           usingBlock:^(CMTime time)
                      {
                          [weakSelf syncScrubber];
                      }];
    
}


/* Set the scrubber based on the player current time. */
- (void)syncScrubber
{
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration))
	{
		mScrubber.minimumValue = 0.0;
		return;
	}
    
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		float minValue = [self.mScrubber minimumValue];
		float maxValue = [self.mScrubber maximumValue];
		double time = CMTimeGetSeconds([_player currentTime]);
		
		[self.mScrubber setValue:(maxValue - minValue) * time / duration + minValue];
        [self updateTimeLabel];
	}
}

/* The user is dragging the movie controller thumb to scrub through the movie. */
- (IBAction)beginScrubbing:(id)sender
{
	mRestoreAfterScrubbingRate = [_player rate];
	[_player setRate:0.f];
	/* Remove previous timer. */
	[self removeTimeObserverFromPlayer];
}

/* Set the player current time to match the scrubber position. */
- (IBAction)scrub:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider* slider = sender;
		
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration)) {
			return;
		}
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
            double time = duration * [slider value];
			[_player seekToTime:CMTimeMakeWithSeconds(time, 1)];
            [self updateTimeLabel];
		}
	}
}

/* The user has released the movie thumb control to stop scrubbing through the movie. */
- (IBAction)endScrubbing:(id)sender
{
	if (!_timeObserver)
	{
		[self initScrubberTimer];
	}
    
	if (mRestoreAfterScrubbingRate)
	{
		[_player setRate:mRestoreAfterScrubbingRate];
		mRestoreAfterScrubbingRate = 0.f;
    }
}

@end
