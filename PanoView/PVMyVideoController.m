//
//  PVMyVideoController.m
//  PanoView
//
//  Created by Li Hao on 25/8/13.
//  Copyright (c) 2013 PanoGraphic. All rights reserved.
//

#import "PVMyVideoController.h"
#import "PVAppDelegate.h"

@interface SizableImageCell : UITableViewCell{}
@end
@implementation SizableImageCell
- (void) layoutSubviews {
    [super layoutSubviews];
    float desiredWidth = 100;
    float w = self.imageView.frame.size.width;
    float widthSub = w - desiredWidth;
    self.imageView.frame = CGRectMake(self.imageView.frame.origin.x+2,self.imageView.frame.origin.y,desiredWidth,self.imageView.frame.size.height);
    self.textLabel.frame = CGRectMake(self.textLabel.frame.origin.x-widthSub,self.textLabel.frame.origin.y,self.textLabel.frame.size.width+widthSub,self.textLabel.frame.size.height);
    self.detailTextLabel.frame = CGRectMake(self.detailTextLabel.frame.origin.x-widthSub,self.detailTextLabel.frame.origin.y,self.detailTextLabel.frame.size.width+widthSub,self.detailTextLabel.frame.size.height);
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
}
@end

@implementation PVMyVideoController
{
    NSMutableArray *myVideoList;
    NSString *docPath;
    APLViewController *vplayer;
}

- (void) reloadVideoFiles
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    docPath = [paths objectAtIndex:0];
    myVideoList = [[[NSFileManager defaultManager] subpathsOfDirectoryAtPath:docPath error:nil] mutableCopy];
    if (self.view)
        [self.tableView reloadData];
}

- (void) viewDidLoad
{
    [self reloadVideoFiles];
    vplayer = [self.storyboard instantiateViewControllerWithIdentifier:@"APLViewController"];
    [super viewDidLoad];
}

- (NSInteger) tableView:(UITableView *)tableview numberOfRowsInSection:(NSInteger)section
{
    return [myVideoList count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *myVideoIdentifier = @"MyVideoItem";
    SizableImageCell *cell = [tableView dequeueReusableCellWithIdentifier:myVideoIdentifier];
    if (cell == nil) {
        cell = [[SizableImageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:myVideoIdentifier ];
    }

    NSString *videoFileName = [myVideoList objectAtIndex:indexPath.row];
    cell.textLabel.text = [videoFileName stringByDeletingPathExtension];

    NSURL *videoURL = [NSURL fileURLWithPath:[docPath stringByAppendingPathComponent:videoFileName]];
    
    {
        
        MPMoviePlayerController *player = [[MPMoviePlayerController alloc] initWithContentURL:videoURL];
        cell.imageView.image = [player thumbnailImageAtTime:1.0 timeOption:MPMovieTimeOptionNearestKeyFrame];
        //Player autoplays audio on init
        [player stop];
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *videoFileName = [myVideoList objectAtIndex:indexPath.row];
    NSURL *videoURL = [NSURL fileURLWithPath:[docPath stringByAppendingPathComponent:videoFileName]];
    
    vplayer.theMovieURL = videoURL;
    vplayer.needRotation = self.interfaceOrientation == UIInterfaceOrientationPortrait;
    [self presentViewController:vplayer animated:YES completion:nil];

    // [self.navigationController pushViewController:vplayer animated:YES];
}

- (BOOL)tableView:(UITableView *) tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        NSString *videoFileName = [docPath stringByAppendingPathComponent:[myVideoList objectAtIndex:indexPath.row]];        
        // Delete item in the list
        [myVideoList removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        // Delete the file in Documents folder
        [[NSFileManager defaultManager] removeItemAtPath:videoFileName error:NULL];
    }

}

-(id) initWithCoder:(NSCoder *)aDecoder
{
    PVAppDelegate *appDelegate = (PVAppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.vcMyVideo = self;
    return [super initWithCoder:aDecoder];
}

@end

