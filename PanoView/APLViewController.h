/*
     File: APLViewController.h
 Abstract: This view controller handles the UI to load panographic video for playback using AVFoundation. It also sets up the AVPlayerItemVideoOutput, from which CVPixelBuffers are pulled out and sent to the shaders for rendering.
  Version: 1.0
 
 */

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface APLViewController : UIViewController <AVPlayerItemOutputPullDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverControllerDelegate, UIGestureRecognizerDelegate> {
    IBOutlet UISegmentedControl * viewChoice;
}
@property (nonatomic, retain) NSURL * theMovieURL;
-(IBAction)changeView;


@end
