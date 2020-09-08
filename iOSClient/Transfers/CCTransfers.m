//
//  CCTransfers.m
//  Nextcloud
//
//  Created by Marino Faggiana on 12/04/17.
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

#import "CCTransfers.h"
#import "AppDelegate.h"
#import "CCMain.h"
#import "CCSection.h"
#import "NCBridgeSwift.h"

#define download 1
#define upload 2
#define uploadwwan 3

@interface CCTransfers ()
{
    AppDelegate *appDelegate;

    // Datasource
    CCSectionDataSourceMetadata *sectionDataSource;
    tableMetadata *metadataForRecognizer;
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
        appDelegate.activeTransfers = self;
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"_transfers_", nil);

    // Custom Cell
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMain" bundle:nil] forCellReuseIdentifier:@"CellMain"];
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMainTransfer" bundle:nil] forCellReuseIdentifier:@"CellMainTransfer"];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
    
    // long press recognizer TableView
    UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressTableView:)];
    [self.tableView addGestureRecognizer:longPressRecognizer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:k_notificationCenter_progressTask object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDatasource) name:k_notificationCenter_uploadedFile object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDatasource) name:k_notificationCenter_downloadedFile object:nil];

    [self changeTheming];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
        
    [self reloadDatasource];
}

- (void)changeTheming
{
    [appDelegate changeTheming:self tableView:self.tableView collectionView:nil form:false];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource ====
#pragma --------------------------------------------------------------------------------------------

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView
{
    CGFloat height = self.tabBarController.tabBar.frame.size.height;
    return -height;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return NCBrandColor.sharedInstance.backgroundView;
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"load"] width:300 height:300 color:NCBrandColor.sharedInstance.graySoft];
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
#pragma mark ===== Long Press Recognized Table View =====
#pragma --------------------------------------------------------------------------------------------

- (void)onLongPressTableView:(UILongPressGestureRecognizer*)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        
        CGPoint touchPoint = [recognizer locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:touchPoint];
        
        metadataForRecognizer = [[NCMainCommon shared] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
        
        [self becomeFirstResponder];

        UIMenuController *menuController = [UIMenuController sharedMenuController];
        
        UIMenuItem *startTaskItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_force_start_", nil) action:@selector(startTask:)];

        [menuController setMenuItems:[NSArray arrayWithObjects:startTaskItem, nil]];

        [menuController setTargetRect:CGRectMake(touchPoint.x, touchPoint.y, 0.0f, 0.0f) inView:self.tableView];
        [menuController setMenuVisible:YES animated:YES];
    }
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (@selector(startTask:) != action) return NO;
    if (metadataForRecognizer == nil) return NO;
    
    // Detect E2EE
    NSString *saveserverUrl = @"";
    NSArray *metadatasForE2EE = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"status != %d", k_metadataStatusNormal] page:0 limit:0 sorted:@"serverUrl" ascending:NO];
    for (tableMetadata *metadata in metadatasForE2EE) {
        if (![saveserverUrl isEqualToString:metadata.serverUrl]) {
            saveserverUrl = metadata.serverUrl;
            if ([[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND e2eEncrypted == 1", metadata.account, metadata.serverUrl]] != nil) {
                return NO;
            }
        }
    }
    
    if ((metadataForRecognizer.status == k_metadataStatusWaitUpload || metadataForRecognizer.status == k_metadataStatusInUpload || metadataForRecognizer.status == k_metadataStatusUploading)) {
        return YES;
    }
    
    return NO;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ===== Progress & Task Button =====
#pragma --------------------------------------------------------------------------------------------

- (void)triggerProgressTask:(NSNotification *)notification
{
    if (sectionDataSource.ocIdIndexPath != nil) {
        [[NCMainCommon shared] triggerProgressTask:notification sectionDataSourceocIdIndexPath:sectionDataSource.ocIdIndexPath tableView:self.tableView viewController:self serverUrlViewController:nil];
    }
}

- (void)cancelTaskButton:(id)sender withEvent:(UIEvent *)event
{
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    if (indexPath) {
        
        NSString *ocId = [[sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId = %@", ocId]];
        
        if (metadata)
            [[NCMainCommon shared] cancelTransferMetadata:metadata uploadStatusForcedStart:false];
    }
}

- (void)cancelAllTask:(id)sender
{
    CGPoint location = [sender locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_all_task_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[NCMainCommon shared] cancelAllTransfer];
    }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { }]];
    
    alertController.popoverPresentationController.sourceView = self.tableView;
    alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)startTask:(id)sender
{
    if (metadataForRecognizer.status == k_metadataStatusUploading) {
        [[NCMainCommon shared] cancelTransferMetadata:metadataForRecognizer uploadStatusForcedStart:true];
    } else {
        tableMetadata *metadata = [[NCManageDatabase sharedInstance] copyObjectWithMetadata:metadataForRecognizer];
        metadata.status = k_metadataStatusInUpload;
        metadata.session = NCNetworking.shared.sessionIdentifierBackground;
       
        [[NCManageDatabase sharedInstance] addMetadata:metadata];
        [[NCNetworking shared] uploadWithMetadata:metadata background:true completion:^(NSInteger errorCode, NSString *errorDescription) { }];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Datasource ====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadDatasource
{
    // test
    if (appDelegate.account.length == 0 || self.view.window == nil) {
        return;
    }
    
    NSArray *recordsTableMetadata = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"(session CONTAINS 'upload') OR (session CONTAINS 'download')"] page:1 limit:100 sorted:@"sessionTaskIdentifier" ascending:NO];
    CCSectionDataSourceMetadata *sectionDataSourceTemp = [CCSectionDataSourceMetadata new];
        
    sectionDataSourceTemp  = [CCSectionMetadata creataDataSourseSectionMetadata:recordsTableMetadata listProgressMetadata:appDelegate.listProgressMetadata groupBy:@"session" filterTypeFileImage:NO filterTypeFileVideo:NO filterLivePhoto:NO sort:@"fileName" ascending:YES directoryOnTop:NO account:appDelegate.account];
        
    sectionDataSource = sectionDataSourceTemp;
    [self.tableView reloadData];
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
    NSString *sessionDownload = [[NCCommunicationCommon shared] sessionIdentifierDownload];

    NSInteger queueDownload = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"session == %@", sessionDownload] page:0 limit:0 sorted:@"fileName" ascending:NO] count];

    NSInteger queueUpload = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"session == %@", NCNetworking.shared.sessionIdentifierBackground] page:0 limit:0 sorted:@"fileName" ascending:NO] count];
    NSInteger queueUploadWWan = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"session == %@", NCNetworking.shared.sessionIdentifierBackgroundWWan] page:0 limit:0 sorted:@"fileName" ascending:NO] count];
    
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
    
    if ((typeOfSession == download && queueDownload > rowsCount) || (typeOfSession == upload   && queueUpload > rowsCount) || (typeOfSession == uploadwwan && queueUploadWWan > rowsCount)) {
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
    if ([titleSection containsString:@"download"] && titleSection != nil) {
        
        NSString *session = [[NCCommunicationCommon shared] sessionIdentifierDownload];
        NSInteger queueDownload = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"session == %@", session] page:0 limit:0 sorted:@"fileName" ascending:NO] count];
        
        // element or elements ?
        if (queueDownload > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Num record to upload
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_download_", nil), queueDownload, element_s]];
        titleFooterLabel.attributedText = stringFooter;
        
        [view addSubview:titleFooterLabel];
        return view;
    }
    
    // Footer Upload
    if ([titleSection containsString:@"upload"] && ![titleSection containsString:@"wwan"] && titleSection != nil) {
        
        NSInteger queueUpload = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"session == %@", NCNetworking.shared.sessionIdentifierBackground] page:0 limit:0 sorted:@"fileName" ascending:NO] count];
        
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
        
        NSInteger queueUploadWWan = [[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"session == %@", NCNetworking.shared.sessionIdentifierBackgroundWWan] page:0 limit:0 sorted:@"fileName" ascending:NO] count];
       
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
    NSString *ocId = [[sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
    tableMetadata *metadata = [sectionDataSource.allRecordsDataSource objectForKey:ocId];
    if (metadata == nil || [[NCManageDatabase sharedInstance] isTableInvalidated:metadata]) {
        return [CCCellMainTransfer new];
    }
    
    UITableViewCell *cell = [[NCMainCommon shared] cellForRowAtIndexPath:indexPath tableView:tableView metadata:metadata metadataFolder:nil serverUrl:metadata.serverUrl autoUploadFileName:@"" autoUploadDirectory:@"" tableShare:nil livePhoto:false];
    
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

- (BOOL)indexPathIsValid:(NSIndexPath *)indexPath
{
    if (!indexPath)
        return NO;
    
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    
    NSInteger lastSectionIndex = [self numberOfSectionsInTableView:self.tableView] - 1;
    
    if (section > lastSectionIndex || lastSectionIndex < 0)
        return NO;
    
    NSInteger rowCount = [self.tableView numberOfRowsInSection:indexPath.section] - 1;
    
    if (rowCount < 0)
        return NO;
    
    return row <= rowCount;
}


@end

