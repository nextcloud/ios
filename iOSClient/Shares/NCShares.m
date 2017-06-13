//
//  NCShares.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 05/06/17.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "NCShares.h"
#import "NCSharesCell.h"
#import "AppDelegate.h"
#import "NCBridgeSwift.h"

@interface NCShares ()
{
    AppDelegate *appDelegate;
    NSArray *_dataSource;
    
    CCHud *_hudDeterminate;
}
@end

@implementation NCShares

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:@"NotificationProgressTask" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDatasource) name:@"SharesReloadDatasource" object:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // Custom Cell
    [self.tableView registerNib:[UINib nibWithNibName:@"NCSharesCell" bundle:nil] forCellReuseIdentifier:@"Cell"];

    // dataSource
    _dataSource = [NSMutableArray new];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 1)];
    self.tableView.separatorColor = [NCBrandColor sharedInstance].seperator;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;
    self.tableView.delegate = self;
    
    // Title
    self.title = NSLocalizedString(@"_list_shares_", nil);
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[appDelegate.reachability isReachable] hidden:NO];
    [app aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // Plus Button
    [app plusButtonVisibile:true];
    
    [self reloadDatasource];
}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [app changeTheming:self];
    
    // Reload Table View
    [self.tableView reloadData];
}

- (void)triggerProgressTask:(NSNotification *)notification
{
    NSDictionary *dict = notification.userInfo;
    float progress = [[dict valueForKey:@"progress"] floatValue];
    
    if (progress == 0)
        [self.navigationController cancelCCProgress];
    else
        [self.navigationController setCCProgressPercentage:progress*100 andTintColor:[NCBrandColor sharedInstance].navigationBarProgress];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource ====
#pragma --------------------------------------------------------------------------------------------

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIColor whiteColor];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIImage imageNamed:@"sharesNoFiles"];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = [NSString stringWithFormat:@"%@", NSLocalizedString(@"_list_shares_no_files_", nil)];
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:20.0f], NSForegroundColorAttributeName:[UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = [NSString stringWithFormat:@"\n%@", NSLocalizedString(@"_tutorial_list_shares_view_", nil)];
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0], NSForegroundColorAttributeName: [UIColor lightGrayColor], NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download Thumbnail <Delegate> ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadThumbnailSuccess:(CCMetadataNet *)metadataNet
{
    [self reloadDatasource];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Read File <Delegate> ====
#pragma --------------------------------------------------------------------------------------------

- (void)readFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    NSLog(@"Failure");
}

- (void)readFileSuccess:(CCMetadataNet *)metadataNet metadata:(tableMetadata *)metadata
{
    (void)[[NCManageDatabase sharedInstance] addMetadata:metadata activeUrl:appDelegate.activeUrl serverUrl:metadataNet.serverUrl];
    
    [self reloadDatasource];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== unShare <Delegate> ====
#pragma --------------------------------------------------------------------------------------------

- (void)unShareSuccess:(CCMetadataNet *)metadataNet
{
    NSArray *result = [[NCManageDatabase sharedInstance] unShare:metadataNet.share fileName:metadataNet.fileName serverUrl:metadataNet.serverUrl sharesLink:appDelegate.sharesLink sharesUserAndGroup:appDelegate.sharesUserAndGroup];
    
    appDelegate.sharesLink = result[0];
    appDelegate.sharesUserAndGroup = result[1];
    
    [self reloadDatasource];
}

- (void)removeShares:(tableMetadata *)metadata tableShare:(tableShare *)tableShare
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
 
    metadataNet.action = actionUnShare;
    metadataNet.fileID = metadata.fileID;
    metadataNet.fileName = metadata.fileName;
    metadataNet.fileNamePrint = metadata.fileNamePrint;
    metadataNet.selector = selectorUnshare;
    metadataNet.serverUrl = tableShare.serverUrl;
    
    // Unshare Link
    if (tableShare.shareLink.length > 0) {
   
        metadataNet.share = tableShare.shareLink;
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
    
    // Unshare User&Group
    NSArray *shareUserAndGroup = [tableShare.shareUserAndGroup componentsSeparatedByString:@","];
    for (NSString *share in shareUserAndGroup) {
        
        metadataNet.share = [share stringByReplacingOccurrencesOfString:@" " withString:@""];
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Swipe Tablet -> menu =====
#pragma --------------------------------------------------------------------------------------------

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NSLocalizedString(@"_delete_", nil);
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    tableMetadata *metadata;
    tableShare *table = [_dataSource objectAtIndex:indexPath.row];
    
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:table.serverUrl];
    if (directoryID.length > 0)
        metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND fileName = %@", appDelegate.activeAccount, directoryID, table.fileName]];
    
    if (metadata) return YES;
    else return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        tableShare *table = [_dataSource objectAtIndex:indexPath.row];
        
        NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:table.serverUrl];
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND fileName = %@", appDelegate.activeAccount, directoryID, table.fileName]];
        
        [self removeShares:metadata tableShare:table];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Table ====
#pragma --------------------------------------------------------------------------------------------

- (tableMetadata *)setSelfMetadataFromIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *record = [_dataSource objectAtIndex:indexPath.row];
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", [record valueForKey:@"fileID"]]];

    return metadata;
}

- (void)readFolder:(NSString *)serverUrl
{
    [self reloadDatasource];
}

- (void)reloadDatasource
{
    _dataSource = [[NCManageDatabase sharedInstance] getTableShares];
    
    [self.tableView reloadData];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataSource count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NCSharesCell *cell = (NCSharesCell *)[tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    tableMetadata *metadata;
    
    // separator
    cell.separatorInset = UIEdgeInsetsMake(0.f, 60.f, 0.f, 0.f);
    
    // Initialize
    cell.statusImageView.image = nil;
    cell.offlineImageView.image = nil;
        
    // change color selection
    UIView *selectionColor = [[UIView alloc] init];
    selectionColor.backgroundColor = [[NCBrandColor sharedInstance] getColorSelectBackgrond];
    cell.selectedBackgroundView = selectionColor;
    
    tableShare *table = [_dataSource objectAtIndex:indexPath.row];
    
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:table.serverUrl];
    
    if (directoryID.length > 0)
         metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND fileName = %@", appDelegate.activeAccount, directoryID, table.fileName]];
    
    if (metadata) {
        
        if (metadata.directory) {
            
            cell.fileImageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:metadata.iconName] color:[NCBrandColor sharedInstance].brand];
        
        } else {
            
            cell.fileImageView.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", appDelegate.directoryUser, metadata.fileID]];

            if (cell.fileImageView.image == nil) {
                
                if (metadata.thumbnailExists)
                    [[CCActions sharedInstance] downloadTumbnail:metadata delegate:self];
                else
                    cell.fileImageView.image = [UIImage imageNamed:metadata.iconName];
            }
        }
        
    } else {
        
        cell.fileImageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"file"] color:[NCBrandColor sharedInstance].brand];
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:appDelegate.activeAccount];
            
        metadataNet.action = actionReadFile;
        metadataNet.fileName = table.fileName;
        metadataNet.fileNamePrint = table.fileName;
        metadataNet.serverUrl = table.serverUrl;
        
        [appDelegate addNetworkingOperationQueue:appDelegate.netQueue delegate:self metadataNet:metadataNet];
    }
    
    cell.labelTitle.text = table.fileName;
    
    if ([table.serverUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl]])
        cell.labelInfoFile.text = @"/";
    else
        cell.labelInfoFile.text = [table.serverUrl stringByReplacingOccurrencesOfString:[CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl] withString:@""];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // deselect row
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    tableMetadata *metadata;
    tableShare *table = [_dataSource objectAtIndex:indexPath.row];

    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:table.serverUrl];
    if (directoryID.length > 0)
        metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND fileName = %@", appDelegate.activeAccount, directoryID, table.fileName]];

    if (metadata) {
        
        [appDelegate.activeMain openWindowShare:metadata];
    }
}

@end
