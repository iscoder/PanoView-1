//
//  PVDownloadViewController.h
//  PanoView
//
//  Created by Li Hao on 6/9/13.
//  Copyright (c) 2013 PanoGraphic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ASINetworkQueue.h"

@interface PVDownloadViewController : UITableViewController
{
    ASINetworkQueue *networkQueue;
    NSMutableArray *urlList;
    IBOutlet UIBarButtonItem * mretryButton;
}

- (IBAction)fetchSampleVideo:(id)sender;
- (void)addURLToQueue:(NSURL *)url;

@end
