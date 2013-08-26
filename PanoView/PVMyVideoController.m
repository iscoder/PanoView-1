//
//  PVMyVideoController.m
//  PanoView
//
//  Created by Li Hao on 25/8/13.
//  Copyright (c) 2013 PanoGraphic. All rights reserved.
//

#import "PVMyVideoController.h"

@implementation PVMyVideoController
{
    NSArray *myVideoList;
    NSString *docPath;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    // get all files from Document directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    docPath = [paths objectAtIndex:0];
    myVideoList = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:docPath error:nil];
}

- (NSInteger) tableView:(UITableView *)tableview numberOfRowsInSection:(NSInteger)section
{
    return [myVideoList count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *myVideoIdentifier = @"MyVideoItem";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:myVideoIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:myVideoIdentifier ];
    }

    NSString *videoFileName = [myVideoList objectAtIndex:indexPath.row];
    cell.textLabel.text = videoFileName;

    NSURL *videoURL = [NSURL fileURLWithPath:[docPath stringByAppendingPathComponent:videoFileName]];
    
    MPMoviePlayerController *player = [[MPMoviePlayerController alloc] initWithContentURL:videoURL];
    
    cell.imageView.image = [player thumbnailImageAtTime:1.0 timeOption:MPMovieTimeOptionNearestKeyFrame];
    
    //Player autoplays audio on init
    [player stop];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *videoFileName = [myVideoList objectAtIndex:indexPath.row];
    NSURL *videoURL = [NSURL fileURLWithPath:[docPath stringByAppendingPathComponent:videoFileName]];
    APLViewController *vplayer = [self.storyboard instantiateViewControllerWithIdentifier:@"APLViewController"];
    vplayer.theMovieURL = videoURL;
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *vertShaderURL = [bundle URLForResource:@"Shader" withExtension:@"vsh"];
    [self.view addSubview: [vplayer view]];
    // [self.navigationController pushViewController:vplayer animated:YES];
}

@end

