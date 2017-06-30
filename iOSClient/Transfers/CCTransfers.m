//
//  CCTransfers.m
//  Crypto Cloud Technology Nextcloud
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
#import "CCTransfersCell.h"
#import "NCBridgeSwift.h"

#define download 1
#define downloadwwan 2
#define upload 3
#define uploadwwan 4

@interface CCTransfers ()
{    
    // Datasource
    CCSectionDataSourceMetadata *_sectionDataSource;
}
@end

@implementation CCTransfers

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:@"NotificationProgressTask" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
        
        app.activeTransfers = self;
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    // Custom Cell
    [_tableView registerNib:[UINib nibWithNibName:@"CCTransfersCell" bundle:nil] forCellReuseIdentifier:@"Cell"];
    
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.emptyDataSetDelegate = self;
    _tableView.emptyDataSetSource = self;
    
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = [NCBrandColor sharedInstance].tableBackground;
    
    self.title = NSLocalizedString(@"_transfers_", nil);
    
    [self reloadDatasource];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
        
    // Color
    [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];
    [app aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    [self reloadDatasource];

}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [app changeTheming:self];
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
    return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"transfersNoRecord"] color:[NCBrandColor sharedInstance].brand];
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
#pragma mark - ===== Progress & Task Button =====
#pragma --------------------------------------------------------------------------------------------

- (void)triggerProgressTask:(NSNotification *)notification
{
    NSDictionary *dict = notification.userInfo;
    NSString *fileID = [dict valueForKey:@"fileID"];
    BOOL cryptated = [[dict valueForKey:@"cryptated"] boolValue];
    float progress = [[dict valueForKey:@"progress"] floatValue];
    
    // Check
    if (!fileID)
        return;
    
    [app.listProgressMetadata setObject:[NSNumber numberWithFloat:progress] forKey:fileID];
    
    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:fileID];
    
    if (indexPath && indexPath.row == 0) {
        
        CCTransfersCell *cell = (CCTransfersCell *)[_tableView cellForRowAtIndexPath:indexPath];
        
        if (cryptated) cell.progressView.progressTintColor = [NCBrandColor sharedInstance].cryptocloud;
        else cell.progressView.progressTintColor = [UIColor blackColor];
        
        cell.progressView.hidden = NO;
        [cell.progressView setProgress:progress];
        
    } else {
        
        [self reloadDatasource];
    }
}

- (void)reloadTaskButton:(id)sender withEvent:(UIEvent *)event
{
    if (app.activeMain == nil)
        return;
    
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:_tableView];
    NSIndexPath * indexPath = [_tableView indexPathForRowAtPoint:location];
    
    if (indexPath) {
        
        NSString *fileID = [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
        tableMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
        
        if (metadata)
            [app.activeMain reloadTaskButton:metadata];
    }
}

- (void)reloadAllTask
{
    if (app.activeMain == nil)
        return;
    
    for (NSString *key in _sectionDataSource.allRecordsDataSource.allKeys) {
        
        tableMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:key];
        
        if ([metadata.session containsString:@"download"] && (metadata.sessionTaskIdentifierPlist != k_taskIdentifierDone))
            continue;
        
        if ([metadata.session containsString:@"upload"] && (metadata.sessionTaskIdentifier != k_taskIdentifierStop))
            continue;
        
        [app.activeMain reloadTaskButton:metadata];
    }
}

- (void)cancelTaskButton:(id)sender withEvent:(UIEvent *)event
{
    if (app.activeMain == nil)
        return;
    
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:_tableView];
    NSIndexPath * indexPath = [_tableView indexPathForRowAtPoint:location];
    
    if (indexPath) {
        
        NSString *fileID = [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
        tableMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
        
        if (metadata)
            [app.activeMain cancelTaskButton:metadata reloadTable:YES];
    }
}

- (void)cancelAllTask
{
    if (app.activeMain == nil)
        return;
    
    BOOL lastAndRefresh = NO;
    
    for (NSString *key in _sectionDataSource.allRecordsDataSource.allKeys) {
        
        if ([key isEqualToString:[_sectionDataSource.allRecordsDataSource.allKeys lastObject]])
            lastAndRefresh = YES;
        
        tableMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:key];
        
        if ([metadata.session containsString:@"upload"] && metadata.cryptated && ((metadata.sessionTaskIdentifier == k_taskIdentifierDone && metadata.sessionTaskIdentifierPlist >= 0) || (metadata.sessionTaskIdentifier >= 0 && metadata.sessionTaskIdentifierPlist == k_taskIdentifierDone)))
            continue;
        
        [app.activeMain cancelTaskButton:metadata reloadTable:lastAndRefresh];
    }
}

- (void)stopTaskButton:(id)sender withEvent:(UIEvent *)event
{
    if (app.activeMain == nil)
        return;
    
    UITouch * touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:_tableView];
    NSIndexPath * indexPath = [_tableView indexPathForRowAtPoint:location];
    
    if (indexPath) {
        
        NSString *fileID = [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
        tableMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
        
        if (metadata)
            [app.activeMain stopTaskButton:metadata];
    }
}

- (void)stopAllTask
{
    if (app.activeMain == nil)
        return;
    
    for (NSString *key in _sectionDataSource.allRecordsDataSource.allKeys) {
        
        tableMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:key];
        
        if ([metadata.session containsString:@"download"]) {
            [app.activeMain cancelTaskButton:metadata reloadTable:YES];
            continue;
        }
        
        if ([metadata.session containsString:@"upload"] && metadata.cryptated && ((metadata.sessionTaskIdentifier == k_taskIdentifierDone && metadata.sessionTaskIdentifierPlist >= 0) || (metadata.sessionTaskIdentifier >= 0 && metadata.sessionTaskIdentifierPlist == k_taskIdentifierDone)))
            continue;
        
        [app.activeMain stopTaskButton:metadata];
    }    
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== download Thumbnail ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadThumbnailSuccess:(CCMetadataNet *)metadataNet
{
    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:metadataNet.fileID];
    
    if (indexPath && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadataNet.fileID]]) {
        
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Datasource ====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadDatasource
{
    // test
    if (app.activeAccount.length == 0)
        return;
    
    NSArray *recordsTableMetadata = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND ((session CONTAINS 'upload') OR (session CONTAINS 'download' AND (sessionSelector != 'loadPlist')))", app.activeAccount] sorted:@"sessionTaskIdentifier" ascending:YES];
    
    _sectionDataSource  = [CCSectionMetadata creataDataSourseSectionMetadata:recordsTableMetadata listProgressMetadata:app.listProgressMetadata groupByField:@"session" replaceDateToExifDate:NO activeAccount:app.activeAccount];
        
    [_tableView reloadData];    
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Table ====
#pragma --------------------------------------------------------------------------------------------

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[_sectionDataSource.sectionArrayRow allKeys] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:section]] count];
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
    
    NSInteger queueDownload = [app getNumberDownloadInQueues] + [[NCManageDatabase sharedInstance] countAutoUploadWithSession:k_download_session];
    NSInteger queueDownloadWWan = [app getNumberDownloadInQueuesWWan] + [[NCManageDatabase sharedInstance] countAutoUploadWithSession:k_download_session_wwan];
    NSInteger queueUpload = [app getNumberUploadInQueues] + [[NCManageDatabase sharedInstance] countAutoUploadWithSession:k_upload_session];
    NSInteger queueUploadWWan = [app getNumberUploadInQueuesWWan] + [[NCManageDatabase sharedInstance] countAutoUploadWithSession:k_upload_session_wwan];
    
    if ([[_sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSString class]]) titleSection = [_sectionDataSource.sections objectAtIndex:section];
    if ([[_sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSDate class]]) titleSection = [CCUtility getTitleSectionDate:[_sectionDataSource.sections objectAtIndex:section]];
    
    NSArray *metadatas = [_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:section]];
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
    [visualEffectView addSubview:titleLabel];
    
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
    [visualEffectView addSubview:elementLabel];
    
    return visualEffectView;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    NSString *titleSection;
    NSString *element_s;
    
    if ([[_sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSString class]]) titleSection = [_sectionDataSource.sections objectAtIndex:section];
    
    // Prepare view for title in footer
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    
    UILabel *titleFooterLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 18)];
    titleFooterLabel.textColor = [UIColor blackColor];
    titleFooterLabel.font = [UIFont systemFontOfSize:12];
    titleFooterLabel.textAlignment = NSTextAlignmentCenter;
    
    // Footer Download
    if ([titleSection containsString:@"download"] && ![titleSection containsString:@"wwan"] && titleSection != nil) {
        
        NSInteger queueDownload = [app getNumberDownloadInQueues] + [[NCManageDatabase sharedInstance] countAutoUploadWithSession:k_download_session];
        
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
        
        NSInteger queueDownloadWWan = [app getNumberDownloadInQueuesWWan] + [[NCManageDatabase sharedInstance] countAutoUploadWithSession:k_download_session_wwan];
        
        // element or elements ?
        if (queueDownloadWWan > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Add the symbol WiFi and Num record
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        attachment.image = [UIImage imageNamed:@"WiFiSmall"];
        NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:attachment];
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_download_wwan_", nil), queueDownloadWWan, element_s]];
        [stringFooter insertAttributedString:attachmentString atIndex:0];
        titleFooterLabel.attributedText = stringFooter;
        
        [view addSubview:titleFooterLabel];
        return view;
    }
    
    // Footer Upload
    if ([titleSection containsString:@"upload"] && ![titleSection containsString:@"wwan"] && titleSection != nil) {
        
        NSInteger queueUpload = [app getNumberUploadInQueues] + [[NCManageDatabase sharedInstance] countAutoUploadWithSession:k_upload_session];
        
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
        
        NSInteger queueUploadWWan = [app getNumberUploadInQueuesWWan] + [[NCManageDatabase sharedInstance] countAutoUploadWithSession:k_upload_session_wwan];
        
        // element or elements ?
        if (queueUploadWWan > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Add the symbol WiFi and Num record
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        attachment.image = [UIImage imageNamed:@"WiFiSmall"];
        NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:attachment];
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_upload_wwan_", nil), queueUploadWWan,element_s]];
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
    return [_sectionDataSource.sections indexOfObject:title];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *dataFile;
    NSString *lunghezzaFile;
    
    NSString *fileID = [[_sectionDataSource.sectionArrayRow objectForKey:[_sectionDataSource.sections objectAtIndex:indexPath.section]] objectAtIndex:indexPath.row];
    tableMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
    
    CCTransfersCell *cell = (CCTransfersCell *)[tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    // ----------------------------------------------------------------------------------------------------------
    // DEFAULT
    // ----------------------------------------------------------------------------------------------------------
    
    cell.file.image = nil;
    cell.status.image = nil;
    
    cell.labelTitle.enabled = YES;
    cell.labelTitle.text = @"";
    cell.labelInfoFile.enabled = YES;
    cell.labelInfoFile.text = @"";
    
    cell.progressView.progress = 0.0;
    cell.progressView.hidden = YES;
    
    cell.cancelTaskButton.hidden = YES;
    cell.reloadTaskButton.hidden = YES;
    cell.stopTaskButton.hidden = YES;
    
    // colori e font
    if (metadata.cryptated) {
        cell.labelTitle.textColor = [NCBrandColor sharedInstance].cryptocloud;
        cell.labelInfoFile.textColor = [UIColor blackColor];
    } else {
        cell.labelTitle.textColor = [UIColor blackColor];
        cell.labelInfoFile.textColor = [UIColor blackColor];
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // File Name & Folder
    // ----------------------------------------------------------------------------------------------------------
    
    // nome del file
    cell.labelTitle.text = metadata.fileNamePrint;
    
    // è una directory
    if (metadata.directory) {
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.labelInfoFile.text = [CCUtility dateDiff:metadata.date];
        
        lunghezzaFile = @" ";
        
    } else {
        
        // è un file
        
        dataFile = [CCUtility dateDiff:metadata.date];
        lunghezzaFile = [CCUtility transformedSize:metadata.size];
        
        // Plist ancora da scaricare
        if (metadata.cryptated && [metadata.title length] == 0) {
            
            dataFile = @" ";
            lunghezzaFile = @" ";
        }
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // File Image View
    // ----------------------------------------------------------------------------------------------------------
    
    // assegnamo l'immagine anteprima se esiste, altrimenti metti quella standars
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]]) {
        
        cell.file.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
        
    } else {
        
        cell.file.image = [UIImage imageNamed:metadata.iconName];
        
        if (metadata.thumbnailExists)
            [[CCActions sharedInstance] downloadTumbnail:metadata delegate:self];
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // Image Status cyptated & Lock Passcode
    // ----------------------------------------------------------------------------------------------------------
    
    // File Cyptated
    if (metadata.cryptated && metadata.directory == NO && [metadata.type isEqualToString: k_metadataType_template] == NO) {
        
        cell.status.image = [UIImage imageNamed:@"lock"];
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // downloadFile
    // ----------------------------------------------------------------------------------------------------------
    
    if ([metadata.session length] > 0 && [metadata.session rangeOfString:@"download"].location != NSNotFound) {
        
        if (metadata.cryptated) cell.status.image = [UIImage imageNamed:@"statusdownloadcrypto"];
        else cell.status.image = [UIImage imageNamed:@"statusdownload"];
        
        // Fai comparire il RELOAD e lo STOP solo se non è un Task Plist
        if (metadata.sessionTaskIdentifierPlist == k_taskIdentifierDone) {
            
            if (metadata.cryptated)[cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:@"stoptaskcrypto"] forState:UIControlStateNormal];
            else [cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:@"stoptask"] forState:UIControlStateNormal];
            
            cell.cancelTaskButton.hidden = NO;
            
            if (metadata.cryptated)[cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:@"reloadtaskcrypto"] forState:UIControlStateNormal];
            else [cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:@"reloadtask"] forState:UIControlStateNormal];
            
            cell.reloadTaskButton.hidden = NO;
        }
        
        cell.labelInfoFile.text = [NSString stringWithFormat:@"%@", lunghezzaFile];
        
        float progress = [[app.listProgressMetadata objectForKey:metadata.fileID] floatValue];
        if (progress > 0) {
            
            if (metadata.cryptated) cell.progressView.progressTintColor = [NCBrandColor sharedInstance].cryptocloud;
            else cell.progressView.progressTintColor = [UIColor blackColor];
            
            cell.progressView.progress = progress;
            cell.progressView.hidden = NO;
        }
        
        // ----------------------------------------------------------------------------------------------------------
        // downloadFile Error
        // ----------------------------------------------------------------------------------------------------------
        
        if (metadata.sessionTaskIdentifier == k_taskIdentifierError || metadata.sessionTaskIdentifierPlist == k_taskIdentifierError) {
            
            cell.status.image = [UIImage imageNamed:@"statuserror"];
            
            if ([metadata.sessionError length] == 0)
                cell.labelInfoFile.text = [NSString stringWithFormat:@"%@, %@", NSLocalizedString(@"_error_",nil), NSLocalizedString(@"_file_not_downloaded_",nil)];
            else
                cell.labelInfoFile.text = [CCError manageErrorKCF:[metadata.sessionError integerValue] withNumberError:NO];
        }
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // uploadFile
    // ----------------------------------------------------------------------------------------------------------
    
    if ([metadata.session length] > 0 && [metadata.session rangeOfString:@"upload"].location != NSNotFound) {
        
        if (metadata.cryptated) cell.status.image = [UIImage imageNamed:@"statusuploadcrypto"];
        else cell.status.image = [UIImage imageNamed:@"statusupload"];
        
        if (metadata.cryptated)[cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:@"removetaskcrypto"] forState:UIControlStateNormal];
        else [cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:@"removetask"] forState:UIControlStateNormal];
        cell.cancelTaskButton.hidden = NO;
        
        if (metadata.sessionTaskIdentifier == k_taskIdentifierStop) {
            
            if (metadata.cryptated)[cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:@"reloadtaskcrypto"] forState:UIControlStateNormal];
            else [cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:@"reloadtask"] forState:UIControlStateNormal];
            
            if (metadata.cryptated) cell.status.image = [UIImage imageNamed:@"statusstopcrypto"];
            else cell.status.image = [UIImage imageNamed:@"statusstop"];
            
            cell.reloadTaskButton.hidden = NO;
            cell.stopTaskButton.hidden = YES;
            
        } else {
            
            if (metadata.cryptated)[cell.stopTaskButton setBackgroundImage:[UIImage imageNamed:@"stoptaskcrypto"] forState:UIControlStateNormal];
            else [cell.stopTaskButton setBackgroundImage:[UIImage imageNamed:@"stoptask"] forState:UIControlStateNormal];
            
            cell.stopTaskButton.hidden = NO;
            cell.reloadTaskButton.hidden = YES;
        }
        
        // se non c'è una preview in bianconero metti l'immagine di default
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]] == NO)
            cell.file.image = [UIImage imageNamed:@"uploaddisable"];
        
        cell.labelTitle.enabled = NO;
        cell.labelInfoFile.text = [NSString stringWithFormat:@"%@", lunghezzaFile];
        
        float progress = [[app.listProgressMetadata objectForKey:metadata.fileID] floatValue];
        if (progress > 0) {
            
            if (metadata.cryptated) cell.progressView.progressTintColor = [NCBrandColor sharedInstance].cryptocloud;
            else cell.progressView.progressTintColor = [UIColor blackColor];
            
            cell.progressView.progress = progress;
            cell.progressView.hidden = NO;
        }
        
        // ----------------------------------------------------------------------------------------------------------
        // uploadFileError
        // ----------------------------------------------------------------------------------------------------------
        
        if (metadata.sessionTaskIdentifier == k_taskIdentifierError || metadata.sessionTaskIdentifierPlist == k_taskIdentifierError) {
            
            cell.labelTitle.enabled = NO;
            cell.status.image = [UIImage imageNamed:@"statuserror"];
            
            if ([metadata.sessionError length] == 0)
                cell.labelInfoFile.text = [NSString stringWithFormat:@"%@, %@", NSLocalizedString(@"_error_",nil), NSLocalizedString(@"_file_not_uploaded_",nil)];
            else
                cell.labelInfoFile.text = [CCError manageErrorKCF:[metadata.sessionError integerValue] withNumberError:NO];
        }
    }
    
    [cell.reloadTaskButton addTarget:self action:@selector(reloadTaskButton:withEvent:) forControlEvents:UIControlEventTouchUpInside];
    [cell.cancelTaskButton addTarget:self action:@selector(cancelTaskButton:withEvent:) forControlEvents:UIControlEventTouchUpInside];
    [cell.stopTaskButton addTarget:self action:@selector(stopTaskButton:withEvent:) forControlEvents:UIControlEventTouchUpInside];
    
    return cell;
}


@end

