//
//  NCShares.m
//  Nextcloud
//
//  Created by Marino Faggiana on 05/06/17.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
}
@end

@implementation NCShares

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    // Custom Cell
    [self.tableView registerNib:[UINib nibWithNibName:@"NCSharesCell" bundle:nil] forCellReuseIdentifier:@"Cell"];

    // dataSource
    _dataSource = [NSMutableArray new];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 1)];
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;
    self.tableView.delegate = self;
    
    // Title
    self.title = NSLocalizedString(@"_list_shares_", nil);
    
    // Register for 3D Touch Previewing if available
    if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)] && (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable)) {
        [self registerForPreviewingWithDelegate:self sourceView:self.view];
    }
    
    // Notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:k_notificationCenter_changeTheming object:nil];
    
    [self changeTheming];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self reloadDatasource];
}

- (void)changeTheming
{
    [appDelegate changeTheming:self tableView:self.tableView collectionView:nil form:false];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource ====
#pragma --------------------------------------------------------------------------------------------

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return NCBrandColor.sharedInstance.backgroundView;
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"share"] width:300 height:300 color:[UIColor grayColor]];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = [NSString stringWithFormat:@"%@", NSLocalizedString(@"_list_shares_no_files_", nil)];
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:20.0f], NSForegroundColorAttributeName:[UIColor grayColor]};
    
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

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Peek & Pop  =====
#pragma --------------------------------------------------------------------------------------------

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location
{
    CGPoint convertedLocation = [self.view convertPoint:location toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:convertedLocation];
    tableShare *table = [_dataSource objectAtIndex:indexPath.row];
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileName == %@", appDelegate.account, table.serverUrl, table.fileName]];
    
    NCSharesCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if (cell) {
        previewingContext.sourceRect = cell.frame;
        CCPeekPop *viewController = [[UIStoryboard storyboardWithName:@"CCPeekPop" bundle:nil] instantiateViewControllerWithIdentifier:@"PeekPopImagePreview"];
        
        viewController.metadata = metadata;
        viewController.imageFile = cell.fileImageView.image;
        viewController.showOpenIn = false;
        viewController.showOpenQuickLook = false;
        viewController.showShare = false;
        
        return viewController;
    }
    
    return nil;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit
{
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:previewingContext.sourceRect.origin];
    
    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== unShare <Delegate> ====
#pragma --------------------------------------------------------------------------------------------

- (void)removeShares:(tableMetadata *)metadata tableShare:(tableShare *)tableShare
{
    [[NCCommunication shared] deleteShareWithIdShare:tableShare.idShare customUserAgent:nil addCustomHeaders:nil completionHandler:^(NSString *account, NSInteger errorCode, NSString *errorDescription) {
        
        if (errorCode == 0 && [account isEqualToString:appDelegate.account]) {
            
            [[NCManageDatabase sharedInstance] deleteTableShareWithAccount:account idShare:tableShare.idShare];
            [self reloadDatasource];
            
        } else if (errorCode != 0) {
            [[NCContentPresenter shared] messageNotification:@"_share_" description:errorDescription delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode forced:true];
        } else {
            NSLog(@"[LOG] It has been changed user during networking process, error.");
        }
    }];
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
    
    if (indexPath.row+1 <= _dataSource.count) {
    
        tableShare *table = [_dataSource objectAtIndex:indexPath.row];
        metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileName = %@", appDelegate.account, table.serverUrl, table.fileName]];
    }
        
    if (metadata) return YES;
    else return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        tableShare *table = [_dataSource objectAtIndex:indexPath.row];
        
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileName == %@", appDelegate.account, table.serverUrl, table.fileName]];
        
        [self removeShares:metadata tableShare:table];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Table ====
#pragma --------------------------------------------------------------------------------------------

- (void)readFolder:(NSString *)serverUrl
{
    [self reloadDatasource];
}

- (void)reloadDatasource
{
    _dataSource = [[NCManageDatabase sharedInstance] getTableSharesWithAccount:appDelegate.account];
    
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
    selectionColor.backgroundColor = NCBrandColor.sharedInstance.select;
    cell.selectedBackgroundView = selectionColor;
    cell.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
    cell.labelTitle.textColor = NCBrandColor.sharedInstance.textView;
    
    tableShare *table = [_dataSource objectAtIndex:indexPath.row];
    
    metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileName == %@", appDelegate.account, table.serverUrl, table.fileName]];
    
    if (metadata) {
        
        if (metadata.directory) {
            
            cell.fileImageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder"] multiplier:2 color:NCBrandColor.sharedInstance.brandElement];
        
        } else {
            
            cell.fileImageView.image = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId etag:metadata.etag]];

            if (cell.fileImageView.image == nil) {
                
                cell.fileImageView.image = [UIImage imageNamed:metadata.iconName];
                
                [[NCOperationQueue shared] downloadThumbnailWithMetadata:metadata urlBase:appDelegate.urlBase view:tableView indexPath:indexPath];
            }
        }
        
    } else {
        
        cell.fileImageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"file"] multiplier:2 color:NCBrandColor.sharedInstance.brandElement];
        
        NSString *serverUrlFileName = [NSString stringWithFormat:@"%@/%@", table.serverUrl, table.fileName];
               
        [[NCNetworking shared] readFileWithServerUrlFileName:serverUrlFileName account:appDelegate.account completion:^(NSString *account, tableMetadata *metadata, NSInteger errorCode, NSString *errorDescription) {
            
            if (errorCode == 0 && [account isEqualToString:appDelegate.account]) {
                [[NCManageDatabase sharedInstance] addMetadata:metadata];
                [self reloadDatasource];
            }
        }];
    }
    
    cell.labelTitle.text = table.fileName;
    
    if ([table.serverUrl isEqualToString:[[NCUtility shared] getHomeServerWithUrlBase:appDelegate.urlBase account:appDelegate.account]])
        cell.labelInfoFile.text = @"/";
    else
        cell.labelInfoFile.text = [table.serverUrl stringByReplacingOccurrencesOfString:[[NCUtility shared] getHomeServerWithUrlBase:appDelegate.urlBase account:appDelegate.account] withString:@""];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // deselect row
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    tableMetadata *metadata;
    tableShare *table = [_dataSource objectAtIndex:indexPath.row];

    if (table.serverUrl) {
        
        metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileName == %@", appDelegate.account, table.serverUrl, table.fileName]];
        if (metadata) {
            [[NCMainCommon shared] openShareWithViewController:self metadata:metadata indexPage:2];
        }
    }
}

@end
