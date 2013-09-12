/*
     File: APLViewController.h
 Abstract: This view controller handles the UI to load panographic video for playback using AVFoundation. It also sets up the AVPlayerItemVideoOutput, from which CVPixelBuffers are pulled out and sent to the shaders for rendering.
  Version: 1.0
 
 */

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMotion/CoreMotion.h>

@interface APLViewController : UIViewController <AVPlayerItemOutputPullDelegate, UINavigationControllerDelegate, UIPopoverControllerDelegate, UIGestureRecognizerDelegate> {
    IBOutlet UISegmentedControl * viewChoice;
    IBOutlet UIBarButtonItem * mPlayButton;
    IBOutlet UIBarButtonItem * mStopButton;
    IBOutlet UIToolbar *mToolbar;
    IBOutlet UIToolbar *mTopBar;
    IBOutlet UISlider* mScrubber;
    IBOutlet UILabel *mCurrentTime;
    IBOutlet UILabel *mDuration;
    
}
@property (nonatomic, retain) NSURL * theMovieURL;
@property (atomic) BOOL needRotation;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *mPlayButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *mStopButton;
@property (nonatomic, retain) IBOutlet UIToolbar *mToolbar;
@property (nonatomic, retain) IBOutlet UIToolbar *mTopBar;
@property (nonatomic, retain) IBOutlet UISlider *mScrubber;
@property (nonatomic, retain) IBOutlet UILabel *mCurrentTime;
@property (nonatomic, retain) IBOutlet UILabel *mDuration;
-(IBAction)changeView;


@end
