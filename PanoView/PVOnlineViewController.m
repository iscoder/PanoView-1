//
//  PVOnlineViewController.m
//  PanoView
//
//  Created by Li Hao on 8/9/13.
//  Copyright (c) 2013 PanoGraphic. All rights reserved.
//

#import "PVOnlineViewController.h"
#import "ASIHTTPRequest.h"
#import "PVAppDelegate.h"
#import "PVDownloadViewController.h"

@interface SizableImageCell2 : UITableViewCell{}
@end
@implementation SizableImageCell2
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

@interface PVOnlineViewController()
{
    NSMutableArray *urlList;
    NSMutableArray *thumbnailList;
}
-(IBAction)reloadURLs;
@end

@implementation PVOnlineViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupLib];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)initLists
{
    if (urlList == nil)
        urlList = [[NSMutableArray alloc] init];
    else
        [urlList removeAllObjects];
    
    if (thumbnailList == nil)
        thumbnailList = [[NSMutableArray alloc] init];
    else
        [thumbnailList removeAllObjects];
}

-(IBAction)reloadURLs
{
    [self setupLib];
}

- (void)setupLib
{
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    spinner.center = CGPointMake(160, 200);
    
    [self.view addSubview:spinner];
    [spinner startAnimating];

    NSURL *url = [NSURL URLWithString:@"https://dl.dropboxusercontent.com/u/585032/PanoView/videolist.txt"];
    __block ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setCompletionBlock:^{
        NSString *dd = [request responseString];
        NSMutableArray* lines = [NSMutableArray arrayWithArray:[dd componentsSeparatedByString:@"|"]];
        for ( int i = 0; i < [lines count]; i ++)
        {
            NSString* str = [lines objectAtIndex:i];
            [lines replaceObjectAtIndex:i withObject:[str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        }
        [self initLists];
        [lines removeObject:@""];
        if ([lines count]%3 == 0)
        {
            for ( int i = 0; i < [lines count] / 3; i++ )
            {
                NSURL* url = [NSURL URLWithString:[lines objectAtIndex:(i*3+1)]];
                [urlList addObject:url];
                NSURL* thumbnail = [NSURL URLWithString:[lines objectAtIndex:(i*3+2)]];
                
                ASIHTTPRequest *rq = [ASIHTTPRequest requestWithURL:thumbnail];
                [rq startSynchronous];
                UIImage* img = [UIImage imageWithData:[rq responseData]];
                if (img != nil)
                    [thumbnailList addObject:img];
                else
                {
                    [thumbnailList addObject:[UIImage imageNamed:@"first.png"]];
                }
            }
        }
        if (self.view)
            [self.tableView reloadData];
        [spinner stopAnimating];
    }];
    [request setFailedBlock:^{
        // NSError *error = [request error];
        [spinner stopAnimating];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Network failed" message:@"Failed to load online library" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
    }];
    [request startAsynchronous];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

/*
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
#warning Potentially incomplete method implementation.
    // Return the number of sections.
    return 0;
}
 */

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [urlList count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"LibCell";
    SizableImageCell2 *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[SizableImageCell2 alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier ];
    }
    
    // NSString *urlFileName = [[[urlList objectAtIndex:indexPath.row] absoluteString] lastPathComponent];
    NSString *urlFileName = [[[urlList objectAtIndex:indexPath.row] path] lastPathComponent];
    cell.textLabel.text = [urlFileName stringByDeletingPathExtension];
    
    cell.imageView.image = [thumbnailList objectAtIndex:indexPath.row];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
        return 62;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
    
    PVAppDelegate *appDelegate = (PVAppDelegate *)[[UIApplication sharedApplication] delegate];
    NSURL *url = [urlList objectAtIndex:indexPath.row];
    [appDelegate.vcDownload addURLToQueue:url];
    // to flash the selection
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
}


@end
