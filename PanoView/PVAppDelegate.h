//
//  PVAppDelegate.h
//  PanoView
//
//  Created by Li Hao on 25/8/13.
//  Copyright (c) 2013 PanoGraphic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PVDownloadViewController.h"
#import "PVMyVideoController.h"

@interface PVAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) PVDownloadViewController *vcDownload;
@property (nonatomic, strong) PVMyVideoController *vcMyVideo;

@end
