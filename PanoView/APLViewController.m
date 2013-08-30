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
}

@property (nonatomic, weak) IBOutlet APLEAGLView *playerView;
@property (nonatomic, weak) IBOutlet UISlider *chromaLevelSlider;
@property (nonatomic, weak) IBOutlet UISlider *lumaLevelSlider;
@property (nonatomic, weak) IBOutlet UILabel *currentTime;
@property (nonatomic, weak) IBOutlet UIView *timeView;
@property (nonatomic, weak) IBOutlet UIToolbar *toolbar;
@property UIPopoverController *popover;

@property AVPlayerItemVideoOutput *videoOutput;
@property CADisplayLink *displayLink;

- (IBAction)updateLevels:(id)sender;
- (IBAction)loadMovieFromCameraRoll:(id)sender;
- (IBAction)goBackToMyVideoList:(id)sender;
- (IBAction)pausePlayer:(id)sender;
- (IBAction)handleTapGesture:(UITapGestureRecognizer *)tapGestureRecognizer;

- (void)displayLinkCallback:(CADisplayLink *)sender;

@end


@implementation APLViewController

@synthesize theMovieURL;
@synthesize mPlayButton;
@synthesize mStopButton;
@synthesize mToolbar;
@synthesize mTopBar;

#pragma mark -

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	//self.playerView.lumaThreshold = [[self lumaLevelSlider] value];
	//self.playerView.chromaThreshold = [[self chromaLevelSlider] value];
    self.playerView.longitude = 0.5;
    self.playerView.lattitude = 0.5;
    [self.playerView updateInternal];

	_player = [[AVPlayer alloc] init];
    [self addTimeObserverToPlayer];
	
	// Setup CADisplayLink which will callback displayPixelBuffer: at every vsync.
	self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
	[[self displayLink] addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[[self displayLink] setPaused:YES];
	
	// Setup AVPlayerItemVideoOutput with the required pixelbuffer attributes.
	NSDictionary *pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
	self.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
	_myVideoOutputQueue = dispatch_queue_create("myVideoOutputQueue", DISPATCH_QUEUE_SERIAL);
	[[self videoOutput] setDelegate:self queue:_myVideoOutputQueue];
    
    [self loadMovie];
}

- (void)viewWillAppear:(BOOL)animated
{
	[self addObserver:self forKeyPath:@"player.currentItem.status" options:NSKeyValueObservingOptionNew context:AVPlayerItemStatusContext];
	[self addTimeObserverToPlayer];
    
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
	
	if (_notificationToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_notificationToken name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
		_notificationToken = nil;
	}
}

#pragma mark - Utilities

- (IBAction)updateLevels:(id)sender
{
	NSInteger tag = [sender tag];
	
	switch (tag) {
		case LUMA_SLIDER_TAG: {
			// self.playerView.longitude = [[self lumaLevelSlider] value];
			break;
		}
		case CHROMA_SLIDER_TAG: {
			// self.playerView.lattitude = [[self chromaLevelSlider] value];
			break;
		}
		default:
			break;
	}
}

/* Show the stop button in the movie player controller. */
-(void)showStopButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mToolbar items]];
    [toolbarItems replaceObjectAtIndex:0 withObject:self.mStopButton];
    self.mToolbar.items = toolbarItems;
}

/* Show the play button in the movie player controller. */
-(void)showPlayButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mToolbar items]];
    [toolbarItems replaceObjectAtIndex:0 withObject:self.mPlayButton];
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
    
	[_player pause];
    
	if ([_player currentItem] == nil) {
		[[self lumaLevelSlider] setEnabled:YES];
		[[self chromaLevelSlider] setEnabled:YES];
		[[self playerView] setupGL];
	}
    
	// Time label shows the current time of the item.
    if (self.timeView.hidden) {
		[self.timeView.layer setBackgroundColor:[UIColor colorWithWhite:0.0 alpha:0.3].CGColor];
		[self.timeView.layer setCornerRadius:5.0f];
		[self.timeView.layer setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.15].CGColor];
		[self.timeView.layer setBorderWidth:1.0f];
		self.timeView.hidden = NO;
		self.currentTime.hidden = NO;
    }
    
    [self setupPlaybackForURL:self.theMovieURL];
    
    
    /*
     [[self displayLink] setPaused:YES];
     
     if ([[self popover] isPopoverVisible]) {
     [[self popover] dismissPopoverAnimated:YES];
     }
     // Initialize UIImagePickerController to select a movie from the camera roll
     APLImagePickerController *videoPicker = [[APLImagePickerController alloc] init];
     videoPicker.delegate = self;
     videoPicker.modalPresentationStyle = UIModalPresentationCurrentContext;
     videoPicker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
     videoPicker.mediaTypes = @[(NSString*)kUTTypeMovie];
     
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
    [self dismissViewControllerAnimated:YES completion:nil];
    /*
     NSURL *theMovieURL = nil;
     NSBundle *bundle = [NSBundle mainBundle];
     if (bundle)
     {
     NSString *moviePath = [bundle pathForResource:@"Hollandvillage" ofType:@"mp4"];
     if (moviePath)
     {
     theMovieURL = [NSURL fileURLWithPath:moviePath];
     }
     }
     
     if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
     [self.popover dismissPopoverAnimated:YES];
     }
     else {
     [self dismissViewControllerAnimated:YES completion:nil];
     }
	 */
}

- (IBAction)loadMovieFromCameraRoll:(id)sender
{
    [_player play];
    [self showStopButton];
}

- (IBAction)handleTapGesture:(UITapGestureRecognizer *)tapGestureRecognizer
{
	self.toolbar.hidden = !self.toolbar.hidden;
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

- (void)addDidPlayToEndTimeNotificationForPlayerItem:(AVPlayerItem *)item
{
	if (_notificationToken)
		_notificationToken = nil;
	
	/*
     Setting actionAtItemEnd to None prevents the movie from getting paused at item end. A very simplistic, and not gapless, looped playback.
     */
	_player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
	_notificationToken = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:item queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		// Simple item playback rewind.
		[[_player currentItem] seekToTime:kCMTimeZero];
	}];
}

- (void)syncTimeLabel
{
	double seconds = CMTimeGetSeconds([_player currentTime]);
	if (!isfinite(seconds)) {
		seconds = 0;
	}
	
	int secondsInt = round(seconds);
	int minutes = secondsInt/60;
	secondsInt -= minutes*60;
	
	self.currentTime.textColor = [UIColor colorWithWhite:1.0 alpha:1.0];
	self.currentTime.textAlignment = NSTextAlignmentCenter;

	self.currentTime.text = [NSString stringWithFormat:@"%.2i:%.2i", minutes, secondsInt];
}

- (void)addTimeObserverToPlayer
{
	/*
	 Adds a time observer to the player to periodically refresh the time label to reflect current time.
	 */
    if (_timeObserver)
        return;
    /*
     Use __weak reference to self to ensure that a strong reference cycle is not formed between the view controller, player and notification block.
     */
    __weak APLViewController* weakSelf = self;
    _timeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 10) queue:dispatch_get_main_queue() usingBlock:
                 ^(CMTime time) {
                     [weakSelf syncTimeLabel];
                 }];
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
	
	if ([[self videoOutput] hasNewPixelBufferForItemTime:outputItemTime]) {
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
    self.playerView.prevLattitude = self.playerView.lattitude;
      self.playerView.prevLongitude = self.playerView.longitude;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    CGPoint touchLocation = [[touches anyObject] locationInView:self.playerView];
    float xOffset = touchLocation.x - self.playerView.touchInit.x;
    float yOffset = touchLocation.y - self.playerView.touchInit.y;
    self.playerView.lattitude = MAX(0.0, MIN(1.0,
            self.playerView.prevLattitude + yOffset/self.playerView.layer.bounds.size.height));
    self.playerView.longitude = self.playerView.prevLongitude - xOffset / self.playerView.layer.bounds.size.width;
    self.playerView.longitude -= floorf(self.playerView.longitude);
    [self.playerView updateInternal];
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

@end
