//
//  NCShares.m
//  Nextcloud iOS
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

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDatasource) name:@"SharesReloadDatasource" object:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
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
    [appDelegate aspectNavigationControllerBar:self.navigationController.navigationBar online:[appDelegate.reachability isReachable] hidden:NO];
    [appDelegate aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // Plus Button
    [appDelegate plusButtonVisibile:true];
    
    [self reloadDatasource];
}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [appDelegate changeTheming:self];
    
    // Reload Table View
    [self.tableView reloadData];
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
    return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"sharesNoFiles"] multiplier:2 color:[NCBrandColor sharedInstance].graySoft];
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
#pragma mark ==== unShare <Delegate> ====
#pragma --------------------------------------------------------------------------------------------

- (void)removeShares:(tableMetadata *)metadata tableShare:(tableShare *)tableShare
{
    NSString *shareString;
    
    // Unshare Link
    if (tableShare.shareLink.length > 0) {
        
        shareString = tableShare.shareLink;
    }
    
    // Unshare User&Group
    NSArray *shareUserAndGroup = [tableShare.shareUserAndGroup componentsSeparatedByString:@","];
    for (NSString *share in shareUserAndGroup) {
        shareString = [share stringByReplacingOccurrencesOfString:@" " withString:@""];
    }
    
    [[OCNetworking sharedManager] unshareAccount:appDelegate.activeAccount shareID:[shareString integerValue] completion:^(NSString *account, NSString *message, NSInteger errorCode) {
        
        if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount]) {
            
            NSArray *result = [[NCManageDatabase sharedInstance] unShare:shareString fileName:metadata.fileName serverUrl:metadata.serverUrl sharesLink:appDelegate.sharesLink sharesUserAndGroup:appDelegate.sharesUserAndGroup account:account];
            
            appDelegate.sharesLink = result[0];
            appDelegate.sharesUserAndGroup = result[1];
            
            [self reloadDatasource];
            
        } if (errorCode == kOCErrorServerUnauthorized) {
            [appDelegate openLoginView:self delegate:appDelegate.activeMain loginType:k_login_Modify_Password selector:k_intro_login];
        } else if (errorCode == NSURLErrorServerCertificateUntrusted) {
            [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:message viewController:self delegate:self];
        } else if (errorCode != 0) {
            [appDelegate messageNotification:@"_share_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
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
        metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileName = %@", appDelegate.activeAccount, table.serverUrl, table.fileName]];
    }
        
    if (metadata) return YES;
    else return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        tableShare *table = [_dataSource objectAtIndex:indexPath.row];
        
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileName == %@", appDelegate.activeAccount, table.serverUrl, table.fileName]];
        
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
    _dataSource = [[NCManageDatabase sharedInstance] getTableSharesWithAccount:appDelegate.activeAccount];
    
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
    
    metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileName == %@", appDelegate.activeAccount, table.serverUrl, table.fileName]];
    
    if (metadata) {
        
        if (metadata.directory) {
            
            cell.fileImageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder"] multiplier:2 color:[NCBrandColor sharedInstance].brandElement];
        
        } else {
            
            cell.fileImageView.image = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]];

            if (cell.fileImageView.image == nil) {
                
                cell.fileImageView.image = [UIImage imageNamed:metadata.iconName];
                
                [[NCNetworkingMain sharedInstance] downloadThumbnailWith:metadata view:tableView indexPath:indexPath];
            }
        }
        
    } else {
        
        cell.fileImageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"file"] multiplier:2 color:[NCBrandColor sharedInstance].brandElement];
        
        [[OCNetworking sharedManager] readFileWithAccount:appDelegate.activeAccount serverUrl:table.serverUrl fileName:table.fileName completion:^(NSString *account, tableMetadata *metadata, NSString *message, NSInteger errorCode) {
            if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount]) {
                (void)[[NCManageDatabase sharedInstance] addMetadata:metadata];
                [self reloadDatasource];
            } 
        }];
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

    if (table.serverUrl) {
        
        metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileName == %@", appDelegate.activeAccount, table.serverUrl, table.fileName]];
        if (metadata) {
            [appDelegate.activeMain readShareWithAccount:appDelegate.activeAccount openWindow:YES metadata:metadata];
        }
    }
}

@end
