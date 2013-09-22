//
//  PVDownloadViewController.m
//  PanoView
//
//  Created by Li Hao on 6/9/13.
//  Copyright (c) 2013 PanoGraphic. All rights reserved.
//

#import "PVDownloadViewController.h"
#import "ASIHTTPRequest.h"
#import "PVAppDelegate.h"
#import "PVMyVideoController.h"

@interface ProgressTableViewCell : UITableViewCell
{
}
- (CGRect) progressRect;
@end
@implementation ProgressTableViewCell

- (void) layoutSubviews {
    [super layoutSubviews];
    CGRect textFrame = self.textLabel.frame;
    self.textLabel.frame = CGRectMake( textFrame.origin.x, textFrame.origin.y - 10
                                     , textFrame.size.width, textFrame.size.height );
    self.textLabel.font = [UIFont systemFontOfSize:18];
    
    CGRect detailFrame = self.detailTextLabel.frame;
    self.detailTextLabel.frame = CGRectMake ( detailFrame.origin.x, textFrame.origin.y - 10
                                             , detailFrame.size.width, textFrame.size.height );
    self.detailTextLabel.font = [UIFont systemFontOfSize:12];
    
    /*
    float desiredWidth = 100;
    float w = self.imageView.frame.size.width;
    float widthSub = w - desiredWidth;
    self.imageView.frame = CGRectMake(self.imageView.frame.origin.x,self.imageView.frame.origin.y,desiredWidth,self.imageView.frame.size.height);
    self.textLabel.frame = CGRectMake(self.textLabel.frame.origin.x-widthSub,self.textLabel.frame.origin.y,self.textLabel.frame.size.width+widthSub,self.textLabel.frame.size.height);
    self.detailTextLabel.frame = CGRectMake(self.detailTextLabel.frame.origin.x-widthSub,self.detailTextLabel.frame.origin.y,self.detailTextLabel.frame.size.width+widthSub,self.detailTextLabel.frame.size.height);
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
     */
}

- (CGRect) progressRect
{
    return CGRectMake(10, 30, 270, 20);
}

@end


@interface PVDownloadViewController ()


@end

@implementation PVDownloadViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        /*
         NSURL *url = [NSURL URLWithString:@"https://dl.dropboxusercontent.com/u/585032/Marinabay.mp4"];
         ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
         [request setDelegate:self];
         [request setDownloadDestinationPath:[docPath stringByAppendingPathComponent:@"Marinabay2.mp4"]];
         [request startAsynchronous];
         NSError *error = [request error];
         if(error)
         {
         NSLog(@"error");
         }
         */
    }
    return self;
}

- (IBAction) fetchSampleVideo:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"https://dl.dropboxusercontent.com/u/585032/Marinabay.mp4"];
    [self addURLToQueue:url];
}

- (void)addURLToQueue:(NSURL *)url
{
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    NSString *filename = [[url path] lastPathComponent];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docPath = [paths objectAtIndex:0];
	[request setDownloadDestinationPath:[docPath
                                         stringByAppendingPathComponent:filename]];
	[networkQueue addOperation:request];
    [self reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
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
    return networkQueue.requestsCount;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
            
    ProgressTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    // ProgressTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[ProgressTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier ];
    }
    ASIHTTPRequest *request = [[networkQueue operations] objectAtIndex:indexPath.row];
    NSString *download = [[request downloadDestinationPath] lastPathComponent];
    cell.textLabel.text = [download stringByDeletingPathExtension];
    cell.detailTextLabel.text = @"---";
    // Configure the cell...
    UIProgressView *progress;
    progress = [[UIProgressView alloc] initWithFrame:cell.progressRect];
    [cell.contentView addSubview:progress];
    [request setDownloadProgressDelegate:progress];
    
    NSInteger size = [request.responseHeaders objectForKey:@"Content-length"];
    if (size > 0)
    {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.02f MB"
                                         , size / 1024 / 1024.0 ];
    }
    return cell;
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
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50;
}

-(id) initWithCoder:(NSCoder *)aDecoder
{
    PVAppDelegate *appDelegate = (PVAppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.vcDownload = self;
    if (!networkQueue) {
        networkQueue = [[ASINetworkQueue alloc] init];
        [networkQueue setMaxConcurrentOperationCount:1];
        [networkQueue setShowAccurateProgress:YES];
        [networkQueue setDelegate:self];
        [networkQueue setRequestDidReceiveResponseHeadersSelector:@selector(request:receivedResponseHeaders:)];
        [networkQueue setRequestDidFinishSelector:@selector(requestFinished:)];
        [networkQueue setRequestDidFailSelector:@selector(requestFailed:)];
        [networkQueue go];
    }
    return [super initWithCoder:aDecoder];
}

-(void)reloadData
{
    [self.tableView reloadData];
    if (networkQueue.requestsCount > 0)
    {
        NSString * numQs = [NSString stringWithFormat:@"%i",networkQueue.requestsCount];
        [self.navigationController.tabBarItem setBadgeValue:numQs];
    }
    else
        [self.navigationController.tabBarItem setBadgeValue:nil];
}

-(void)request:(ASIHTTPRequest *)request receivedResponseHeaders:(NSDictionary *)responseHeaders{
    // if header says it is not video, then cancel the request
    if (![[responseHeaders objectForKey:@"Content-type"] isEqualToString:@"video/mp4"])
        [request failWithError:nil];
    if (self.view != nil)
        [self reloadData];
}
-(void)requestFinished:(ASIHTTPRequest *)request
{
    if (self.view != nil)
        [self reloadData];
    PVAppDelegate *appDelegate = (PVAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.vcMyVideo reloadVideoFiles];
}


-(void)requestFailed:(ASIHTTPRequest *) request
{
    if ([[request error] domain] != NetworkRequestErrorDomain || [[request error] code] != ASIRequestCancelledErrorType) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Download failed" message:@"Failed to download video" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
    }
}

@end
