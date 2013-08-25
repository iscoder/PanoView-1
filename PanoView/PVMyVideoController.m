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
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    // get all files from Document directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    myVideoList = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:path error:nil];
    NSLog(@"files array %@", path);
                
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
    cell.textLabel.text = [myVideoList objectAtIndex:indexPath.row];
    return cell;
}

@end
