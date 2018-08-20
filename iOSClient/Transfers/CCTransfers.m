//
//  CCTransfers.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 12/04/17.
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

#import "CCTransfers.h"
#import "AppDelegate.h"
#import "CCMain.h"
#import "CCDetail.h"
#import "CCSection.h"
#import "CCCellMainTransfer.h"
#import "NCBridgeSwift.h"

#define download 1
#define downloadwwan 2
#define upload 3
#define uploadwwan 4

@interface CCTransfers ()
{
    AppDelegate *appDelegate;

    // Datasource
    CCSectionDataSourceMetadata *sectionDataSource;
}
@end

@implementation CCTransfers

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:@"NotificationProgressTask" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
        
        appDelegate.activeTransfers = self;
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    // Custom Cell
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMain" bundle:nil] forCellReuseIdentifier:@"CellMain"];
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMainTransfer" bundle:nil] forCellReuseIdentifier:@"CellMainTransfer"];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [NCBrandColor sharedInstance].backgroundView;
    
    self.title = NSLocalizedString(@"_transfers_", nil);
    
    [self reloadDatasource:nil action:k_action_NULL];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
        
    // Color
    [appDelegate aspectNavigationControllerBar:self.navigationController.navigationBar online:[appDelegate.reachability isReachable] hidden:NO];
    [appDelegate aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.001 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        [self reloadDatasource:nil action:k_action_NULL];
    });
}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [appDelegate changeTheming:self];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource ====
#pragma --------------------------------------------------------------------------------------------

- (CGFloat)spaceHeightForEmptyDataSet:(UIScrollView *)scrollView
{
    return 0.0f;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIColor whiteColor];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"loadNoRecord"] multiplier:2 color:[NCBrandColor sharedInstance].graySoft];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = [NSString stringWithFormat:@"%@", NSLocalizedString(@"_no_transfer_", nil)];
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:20.0f], NSForegroundColorAttributeName:[UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = [NSString stringWithFormat:@"%@", NSLocalizedString(@"_no_transfer_sub_", nil)];
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0], NSForegroundColorAttributeName: [UIColor lightGrayColor], NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download Thumbnail ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadThumbnail:(tableMetadata *)metadata serverUrl:(NSString *)serverUrl indexPath:(NSIndexPath *)indexPath
{
    CGFloat width = [[NCUtility sharedInstance] getScreenWidthForPreview];
    CGFloat height = [[NCUtility sharedInstance] getScreenHeightForPreview];
    
    OCnetworking *ocNetworking = [[OCnetworking alloc] initWithDelegate:nil metadataNet:nil withUser:appDelegate.activeUser withUserID:appDelegate.activeUserID withPassword:appDelegate.activePassword withUrl:appDelegate.activeUrl];
    
    [ocNetworking downloadPreviewWithMetadata:metadata serverUrl:serverUrl withWidth:width andHeight:height completion:^(NSString *message, NSInteger errorCode) {
        if (errorCode == 0 && [[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]] && [[NCMainCommon sharedInstance] isValidIndexPath:indexPath tableView:self.tableView]) {
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        }
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ===== Progress & Task Button =====
#pragma --------------------------------------------------------------------------------------------

- (void)triggerProgressTask:(NSNotification *)notification
{
    [[NCMainCommon sharedInstance] triggerProgressTask:notification sectionDataSourceFileIDIndexPath:sectionDataSource.fileIDIndexPath tableView:self.tableView];
}

- (void)cancelTaskButton:(id)sender withEvent:(UIEvent *)event
{
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:self.tableView];
    NSIndexPath * indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    if (indexPath) {
        
        NSString *fileID = [[sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID]];
        
        if (metadata)
            [[NCMainCommon sharedInstance] cancelTransferMetadata:metadata reloadDatasource:true];
    }
}

- (void)cancelAllTask:(id)sender
{
    CGPoint location = [sender locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_all_task_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[NCMainCommon sharedInstance] cancelAllTransfer];
    }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { }]];
    
    alertController.popoverPresentationController.sourceView = self.tableView;
    alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Datasource ====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadDatasource:(NSString *)fileID action:(NSInteger)action
{
    // test
    if (appDelegate.activeAccount.length == 0 || self.view.window == nil)
        return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSArray *recordsTableMetadata = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND ((session CONTAINS 'upload') OR (session CONTAINS 'download'))", appDelegate.activeAccount] sorted:@"sessionTaskIdentifier" ascending:NO];
        
        CCSectionDataSourceMetadata *sectionDataSourceTemp = [CCSectionDataSourceMetadata new];
        
        sectionDataSourceTemp  = [CCSectionMetadata creataDataSourseSectionMetadata:recordsTableMetadata listProgressMetadata:appDelegate.listProgressMetadata groupByField:@"session" filterFileID:appDelegate.filterFileID filterTypeFileImage:NO filterTypeFileVideo:NO activeAccount:appDelegate.activeAccount];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            sectionDataSource = sectionDataSourceTemp;
            [self.tableView reloadData];
        });
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Table ====
#pragma --------------------------------------------------------------------------------------------

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[sectionDataSource.sectionArrayRow allKeys] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:section]] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 13.0f;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIVisualEffectView *visualEffectView;
    
    NSString *titleSection, *numberTitle;
    NSInteger typeOfSession = 0;
    
    NSInteger queueDownload = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND (session == %@ OR session == %@)", appDelegate.activeAccount, k_download_session, k_download_session_foreground] sorted:nil ascending:NO] count];
    NSInteger queueDownloadWWan = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND session == %@", appDelegate.activeAccount, k_download_session_wwan] sorted:nil ascending:NO] count];

    NSInteger queueUpload = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND (session == %@ OR session == %@)", appDelegate.activeAccount, k_upload_session, k_upload_session_foreground] sorted:nil ascending:NO] count];
    NSInteger queueUploadWWan = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND session == %@", appDelegate.activeAccount, k_upload_session_wwan] sorted:nil ascending:NO] count];
    
    if ([[sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSString class]]) titleSection = [sectionDataSource.sections objectAtIndex:section];
    if ([[sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSDate class]]) titleSection = [CCUtility getTitleSectionDate:[sectionDataSource.sections objectAtIndex:section]];
    
    NSArray *metadatas = [sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:section]];
    NSUInteger rowsCount = [metadatas count];
    
    visualEffectView = [[UIVisualEffectView alloc] init];
    visualEffectView.backgroundColor = [UIColor clearColor];
    
    // title section
    if ([titleSection isEqualToString:@"_none_"]) {
        titleSection = @"";
    } else if ([titleSection containsString:@"download"] && ![titleSection containsString:@"wwan"]) {
        typeOfSession = download;
        titleSection = NSLocalizedString(@"_title_section_download_",nil);
    } else if ([titleSection containsString:@"download"] && [titleSection containsString:@"wwan"]) {
        typeOfSession = downloadwwan;
        titleSection = [NSLocalizedString(@"_title_section_download_",nil) stringByAppendingString:@" Wi-Fi"];
    } else if ([titleSection containsString:@"upload"] && ![titleSection containsString:@"wwan"]) {
        typeOfSession = upload;
        titleSection = NSLocalizedString(@"_title_section_upload_",nil);
    } else if ([titleSection containsString:@"upload"] && [titleSection containsString:@"wwan"]) {
        typeOfSession = uploadwwan;
        titleSection = [NSLocalizedString(@"_title_section_upload_",nil) stringByAppendingString:@" Wi-Fi"];
    } else {
        titleSection = NSLocalizedString(titleSection,nil);
    }
    
    // title label on left
    UILabel *titleLabel=[[UILabel alloc]initWithFrame:CGRectMake(8, 3, 0, 13)];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.font = [UIFont systemFontOfSize:9];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.text = titleSection;
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [visualEffectView.contentView addSubview:titleLabel];
    
    // element (s) on right
    UILabel *elementLabel=[[UILabel alloc]initWithFrame:CGRectMake(-8, 3, 0, 13)];
    elementLabel.textColor = [UIColor blackColor];
    elementLabel.font = [UIFont systemFontOfSize:9];
    elementLabel.textAlignment = NSTextAlignmentRight;
    elementLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    if ((typeOfSession == download && queueDownload > rowsCount) || (typeOfSession == downloadwwan && queueDownloadWWan > rowsCount) ||
        (typeOfSession == upload   && queueUpload > rowsCount)   || (typeOfSession == uploadwwan && queueUploadWWan > rowsCount)) {
        numberTitle = [NSString stringWithFormat:@"%lu+", (unsigned long)rowsCount];
    } else {
        numberTitle = [NSString stringWithFormat:@"%lu", (unsigned long)rowsCount];
    }
    
    if (rowsCount > 1)
        elementLabel.text = [NSString stringWithFormat:@"%@ %@", numberTitle, NSLocalizedString(@"_elements_",nil)];
    else
        elementLabel.text = [NSString stringWithFormat:@"%@ %@", numberTitle, NSLocalizedString(@"_element_",nil)];
    
    // view
    [visualEffectView.contentView addSubview:elementLabel];
    
    return visualEffectView;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    NSString *titleSection;
    NSString *element_s;
    
    if ([[sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSString class]]) titleSection = [sectionDataSource.sections objectAtIndex:section];
    
    // Prepare view for title in footer
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    
    UILabel *titleFooterLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 18)];
    titleFooterLabel.textColor = [UIColor blackColor];
    titleFooterLabel.font = [UIFont systemFontOfSize:12];
    titleFooterLabel.textAlignment = NSTextAlignmentCenter;
    
    // Footer Download
    if ([titleSection containsString:@"download"] && ![titleSection containsString:@"wwan"] && titleSection != nil) {
        
        NSInteger queueDownload = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND (session == %@ OR session == %@)", appDelegate.activeAccount, k_download_session, k_download_session_foreground] sorted:nil ascending:NO] count];
        
        // element or elements ?
        if (queueDownload > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Num record to upload
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_download_", nil), queueDownload, element_s]];
        titleFooterLabel.attributedText = stringFooter;
        
        [view addSubview:titleFooterLabel];
        return view;
    }
    
    // Footer Download WWAN
    if ([titleSection containsString:@"download"] && [titleSection containsString:@"wwan"] && titleSection != nil) {
        
        NSInteger queueDownloadWWan = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND session == %@", appDelegate.activeAccount, k_download_session_wwan] sorted:nil ascending:NO] count];
        
        // element or elements ?
        if (queueDownloadWWan > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Add the symbol WiFi and Num record
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        attachment.image = [UIImage imageNamed:@"WiFiSmall"];
        NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:attachment];
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[@" " stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_download_wwan_", nil), queueDownloadWWan, element_s]]];
        [stringFooter insertAttributedString:attachmentString atIndex:0];
        titleFooterLabel.attributedText = stringFooter;
        
        [view addSubview:titleFooterLabel];
        return view;
    }
    
    // Footer Upload
    if ([titleSection containsString:@"upload"] && ![titleSection containsString:@"wwan"] && titleSection != nil) {
        
        NSInteger queueUpload = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND (session == %@ OR session == %@)", appDelegate.activeAccount, k_upload_session, k_upload_session_foreground] sorted:nil ascending:NO] count];
        
        // element or elements ?
        if (queueUpload > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Num record to upload
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_upload_", nil), queueUpload, element_s]];
        titleFooterLabel.attributedText = stringFooter;
        
        [view addSubview:titleFooterLabel];
        return view;
    }
    
    // Footer Upload WWAN
    if ([titleSection containsString:@"upload"] && [titleSection containsString:@"wwan"] && titleSection != nil) {
        
        NSInteger queueUploadWWan = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND session == %@", appDelegate.activeAccount, k_upload_session_wwan] sorted:nil ascending:NO] count];
       
        // element or elements ?
        if (queueUploadWWan > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Add the symbol WiFi and Num record
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        attachment.image = [UIImage imageNamed:@"WiFiSmall"];
        NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:attachment];
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[@" " stringByAppendingString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_upload_wwan_", nil), queueUploadWWan,element_s]]];
        [stringFooter insertAttributedString:attachmentString atIndex:0];
        titleFooterLabel.attributedText = stringFooter;
        
        [view addSubview:titleFooterLabel];
        return view;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    //NSString *titleSection;
    
    //if ([[_sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSString class]])
    //    titleSection = [_sectionDataSource.sections objectAtIndex:section];
    
    //if ([titleSection rangeOfString:@"upload"].location != NSNotFound && [titleSection rangeOfString:@"wwan"].location != NSNotFound && titleSection != nil) return 18.0f;
    //else return 0.0f;
    
    return 18.0f;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [sectionDataSource.sections indexOfObject:title];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *fileID = [[sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
    tableMetadata *metadata = [sectionDataSource.allRecordsDataSource objectForKey:fileID];
    if (metadata == nil || [[NCManageDatabase sharedInstance] isTableInvalidated:metadata]) {
        return [CCCellMainTransfer new];
    }
    
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    if (serverUrl == nil) {
        return [CCCellMainTransfer new];
    }
    
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, serverUrl]];
    if (directory == nil) {
        return [CCCellMainTransfer new];
    }
    
    tableMetadata *metadataFolder = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", directory.fileID]];
    
    // Download thumbnail
    if (metadata.thumbnailExists && !metadataFolder.e2eEncrypted && ![CCUtility fileProviderStorageIconExists:metadata.fileID fileNameView:metadata.fileNameView]) {
        [self downloadThumbnail:metadata serverUrl:serverUrl indexPath:indexPath];
    }
  
    UITableViewCell *cell = [[NCMainCommon sharedInstance] cellForRowAtIndexPath:indexPath tableView:tableView metadata:metadata metadataFolder:metadataFolder serverUrl:serverUrl autoUploadFileName:@"" autoUploadDirectory:@""];
    
    // TRANSFER
    
    if ([cell isKindOfClass:[CCCellMainTransfer class]]) {
        
        // gesture Transfer
        [((CCCellMainTransfer *)cell).transferButton.stopButton addTarget:self action:@selector(cancelTaskButton:withEvent:) forControlEvents:UIControlEventTouchUpInside];
        
        UILongPressGestureRecognizer *stopLongGesture = [UILongPressGestureRecognizer new];
        [stopLongGesture addTarget:self action:@selector(cancelAllTask:)];
        [((CCCellMainTransfer *)cell).transferButton.stopButton addGestureRecognizer:stopLongGesture];
    }
    
    return cell;
}


@end

