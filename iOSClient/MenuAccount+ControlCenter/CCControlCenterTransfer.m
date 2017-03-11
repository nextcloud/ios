//
//  CCControlCenterPageContent.m
//  Nextcloud
//
//  Created by Marino Faggiana on 01/03/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "CCControlCenterTransfer.h"

#import "AppDelegate.h"
#import "CCMain.h"
#import "CCDetail.h"
#import "CCSection.h"
#import "CCMetadata.h"
#import "CCControlCenterTransferCell.h"

#define download 1
#define downloadwwan 2
#define upload 3
#define uploadwwan 4

@interface CCControlCenterTransfer ()
{    
    // Datasource
    CCSectionDataSourceMetadata *_sectionDataSource;
}
@end

@implementation CCControlCenterTransfer

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        app.controlCenterTransfer = self;
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    // Custom Cell
    [_tableView registerNib:[UINib nibWithNibName:@"CCControlCenterTransferCell" bundle:nil] forCellReuseIdentifier:@"ControlCenterTransferCell"];
    
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = [UIColor clearColor];
    
    [self reloadDatasource];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    app.controlCenter.labelMessageNoRecord.hidden = YES;
}

// E' arrivato
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self reloadDatasource];
    
    // update Badge
    [app updateApplicationIconBadgeNumber];
}

- (void)didReceiveMemoryWarning {
    
    [super didReceiveMemoryWarning];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ===== Progress & Task Button =====
#pragma --------------------------------------------------------------------------------------------

- (void)progressTask:(NSString *)fileID serverUrl:(NSString *)serverUrl cryptated:(BOOL)cryptated progress:(float)progress;
{
    // Chech
    if (!fileID)
        return;
    
    [app.listProgressMetadata setObject:[NSNumber numberWithFloat:progress] forKey:fileID];
    
    NSIndexPath *indexPath = [_sectionDataSource.fileIDIndexPath objectForKey:fileID];
    
    if (indexPath && indexPath.row == 0) {
        
        CCControlCenterTransferCell *cell = (CCControlCenterTransferCell *)[_tableView cellForRowAtIndexPath:indexPath];
        
        if (cryptated) cell.progressView.progressTintColor = COLOR_CRYPTOCLOUD;
        else cell.progressView.progressTintColor = COLOR_TEXT_ANTHRACITE;
        
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
        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
        
        if (metadata)
            [app.activeMain reloadTaskButton:metadata];
    }
}

- (void)reloadAllTask
{
    if (app.activeMain == nil)
        return;
    
    for (NSString *key in _sectionDataSource.allRecordsDataSource.allKeys) {
        
        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:key];
        
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
        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
        
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
        
        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:key];
        
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
        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
        
        if (metadata)
            [app.activeMain stopTaskButton:metadata];
    }
}

- (void)stopAllTask
{
    if (app.activeMain == nil)
        return;
    
    for (NSString *key in _sectionDataSource.allRecordsDataSource.allKeys) {
        
        CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:key];
        
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
#pragma mark - ==== Datasource ====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadDatasource
{
    // test
    if (app.activeAccount.length == 0)
        return;
    
    if (app.controlCenter.isOpen) {
        
        NSArray *recordsTableMetadata = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND ((session CONTAINS 'upload') OR (session CONTAINS 'download' AND (sessionSelector != 'loadPlist')))", app.activeAccount] fieldOrder:@"sessionTaskIdentifier" filterFileName:@"" ascending:YES];
        
        _sectionDataSource  = [CCSectionMetadata creataDataSourseSectionMetadata:recordsTableMetadata listProgressMetadata:app.listProgressMetadata groupByField:@"session" replaceDateToExifDate:NO activeAccount:app.activeAccount];
        
        if ([[app.controlCenter getActivePage] isEqualToString:k_pageControlCenterTransfer]) {
            
            if ([_sectionDataSource.allRecordsDataSource count] == 0) {
                
                app.controlCenter.labelMessageNoRecord.text = NSLocalizedString(@"_no_transfer_",nil);
                app.controlCenter.labelMessageNoRecord.hidden = NO;
            
            } else {
            
                app.controlCenter.labelMessageNoRecord.hidden = YES;
            }
        }
    }
    
    [_tableView reloadData];
    
    [app updateApplicationIconBadgeNumber];
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
    titleLabel.textColor = COLOR_TEXT_ANTHRACITE;
    titleLabel.font = [UIFont systemFontOfSize:9];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.text = titleSection;
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [visualEffectView addSubview:titleLabel];
    
    // element (s) on right
    UILabel *elementLabel=[[UILabel alloc]initWithFrame:CGRectMake(-8, 3, 0, 13)];
    elementLabel.textColor = COLOR_TEXT_ANTHRACITE;
    elementLabel.font = [UIFont systemFontOfSize:9];
    elementLabel.textAlignment = NSTextAlignmentRight;
    elementLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    if ((typeOfSession == download && app.queueNunDownload > rowsCount) || (typeOfSession == downloadwwan && app.queueNumDownloadWWan > rowsCount) ||
        (typeOfSession == upload   && app.queueNumUpload > rowsCount)   || (typeOfSession == uploadwwan && app.queueNumUploadWWan > rowsCount)) {
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
    titleFooterLabel.textColor = COLOR_TEXT_ANTHRACITE;
    titleFooterLabel.font = [UIFont systemFontOfSize:12];
    titleFooterLabel.textAlignment = NSTextAlignmentCenter;
    
    // Footer Download
    if ([titleSection containsString:@"download"] && ![titleSection containsString:@"wwan"] && titleSection != nil) {
        
        // element or elements ?
        if (app.queueNunDownload > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Num record to upload
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_download_", nil), app.queueNunDownload, element_s]];
        titleFooterLabel.attributedText = stringFooter;
        
        [view addSubview:titleFooterLabel];
        return view;
    }
    
    // Footer Download WWAN
    if ([titleSection containsString:@"download"] && [titleSection containsString:@"wwan"] && titleSection != nil) {
        
        // element or elements ?
        if (app.queueNumDownloadWWan > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Add the symbol WiFi and Num record
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        attachment.image = [UIImage imageNamed:image_WiFiSmall];
        NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:attachment];
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_download_wwan_", nil), app.queueNumDownloadWWan, element_s]];
        [stringFooter insertAttributedString:attachmentString atIndex:0];
        titleFooterLabel.attributedText = stringFooter;
        
        [view addSubview:titleFooterLabel];
        return view;
    }
    
    // Footer Upload
    if ([titleSection containsString:@"upload"] && ![titleSection containsString:@"wwan"] && titleSection != nil) {
        
        // element or elements ?
        if (app.queueNumUpload > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Num record to upload
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_upload_", nil), app.queueNumUpload, element_s]];
        titleFooterLabel.attributedText = stringFooter;
        
        [view addSubview:titleFooterLabel];
        return view;
    }
    
    // Footer Upload WWAN
    if ([titleSection containsString:@"upload"] && [titleSection containsString:@"wwan"] && titleSection != nil) {
        
        // element or elements ?
        if (app.queueNumUploadWWan > 1) element_s = NSLocalizedString(@"_elements_",nil);
        else element_s = NSLocalizedString(@"_element_",nil);
        
        // Add the symbol WiFi and Num record
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        attachment.image = [UIImage imageNamed:image_WiFiSmall];
        NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:attachment];
        NSMutableAttributedString *stringFooter= [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"_tite_footer_upload_wwan_", nil), app.queueNumUploadWWan,element_s]];
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
    CCMetadata *metadata = [_sectionDataSource.allRecordsDataSource objectForKey:fileID];
    
    CCControlCenterTransferCell *cell = (CCControlCenterTransferCell *)[tableView dequeueReusableCellWithIdentifier:@"ControlCenterTransferCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    // ----------------------------------------------------------------------------------------------------------
    // DEFAULT
    // ----------------------------------------------------------------------------------------------------------
    
    cell.fileImageView.image = nil;
    cell.statusImageView.image = nil;
    
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
        cell.labelTitle.textColor = COLOR_CRYPTOCLOUD;
        cell.labelInfoFile.textColor = [UIColor blackColor];
    } else {
        cell.labelTitle.textColor = COLOR_TEXT_ANTHRACITE;
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
        
        cell.fileImageView.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
        
    } else {
        
        cell.fileImageView.image = [UIImage imageNamed:metadata.iconName];
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // Image Status cyptated & Lock Passcode
    // ----------------------------------------------------------------------------------------------------------
    
    // File Cyptated
    if (metadata.cryptated && metadata.directory == NO && [metadata.type isEqualToString: k_metadataType_template] == NO) {
        
        cell.statusImageView.image = [UIImage imageNamed:image_lock];
    }
    
    // ----------------------------------------------------------------------------------------------------------
    // downloadFile
    // ----------------------------------------------------------------------------------------------------------
    
    if ([metadata.session length] > 0 && [metadata.session rangeOfString:@"download"].location != NSNotFound) {
        
        if (metadata.cryptated) cell.statusImageView.image = [UIImage imageNamed:image_statusdownloadcrypto];
        else cell.statusImageView.image = [UIImage imageNamed:image_statusdownload];
        
        // Fai comparire il RELOAD e lo STOP solo se non è un Task Plist
        if (metadata.sessionTaskIdentifierPlist == k_taskIdentifierDone) {
            
            if (metadata.cryptated)[cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:image_stoptaskcrypto] forState:UIControlStateNormal];
            else [cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:image_stoptask] forState:UIControlStateNormal];
            
            cell.cancelTaskButton.hidden = NO;
            
            if (metadata.cryptated)[cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:image_reloadtaskcrypto] forState:UIControlStateNormal];
            else [cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:image_reloadtask] forState:UIControlStateNormal];
            
            cell.reloadTaskButton.hidden = NO;
        }
        
        cell.labelInfoFile.text = [NSString stringWithFormat:@"%@", lunghezzaFile];
        
        float progress = [[app.listProgressMetadata objectForKey:metadata.fileID] floatValue];
        if (progress > 0) {
            
            if (metadata.cryptated) cell.progressView.progressTintColor = COLOR_CRYPTOCLOUD;
            else cell.progressView.progressTintColor = COLOR_TEXT_ANTHRACITE;
            
            cell.progressView.progress = progress;
            cell.progressView.hidden = NO;
        }
        
        // ----------------------------------------------------------------------------------------------------------
        // downloadFile Error
        // ----------------------------------------------------------------------------------------------------------
        
        if (metadata.sessionTaskIdentifier == k_taskIdentifierError || metadata.sessionTaskIdentifierPlist == k_taskIdentifierError) {
            
            cell.statusImageView.image = [UIImage imageNamed:image_statuserror];
            
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
        
        if (metadata.cryptated) cell.statusImageView.image = [UIImage imageNamed:image_statusuploadcrypto];
        else cell.statusImageView.image = [UIImage imageNamed:image_statusupload];
        
        if (metadata.cryptated)[cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:image_removetaskcrypto] forState:UIControlStateNormal];
        else [cell.cancelTaskButton setBackgroundImage:[UIImage imageNamed:image_removetask] forState:UIControlStateNormal];
        cell.cancelTaskButton.hidden = NO;
        
        if (metadata.sessionTaskIdentifier == k_taskIdentifierStop) {
            
            if (metadata.cryptated)[cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:image_reloadtaskcrypto] forState:UIControlStateNormal];
            else [cell.reloadTaskButton setBackgroundImage:[UIImage imageNamed:image_reloadtask] forState:UIControlStateNormal];
            
            if (metadata.cryptated) cell.statusImageView.image = [UIImage imageNamed:image_statusstopcrypto];
            else cell.statusImageView.image = [UIImage imageNamed:image_statusstop];
            
            cell.reloadTaskButton.hidden = NO;
            cell.stopTaskButton.hidden = YES;
            
        } else {
            
            if (metadata.cryptated)[cell.stopTaskButton setBackgroundImage:[UIImage imageNamed:image_stoptaskcrypto] forState:UIControlStateNormal];
            else [cell.stopTaskButton setBackgroundImage:[UIImage imageNamed:image_stoptask] forState:UIControlStateNormal];
            
            cell.stopTaskButton.hidden = NO;
            cell.reloadTaskButton.hidden = YES;
        }
        
        // se non c'è una preview in bianconero metti l'immagine di default
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]] == NO)
            cell.fileImageView.image = [UIImage imageNamed:image_uploaddisable];
        
        cell.labelTitle.enabled = NO;
        cell.labelInfoFile.text = [NSString stringWithFormat:@"%@", lunghezzaFile];
        
        float progress = [[app.listProgressMetadata objectForKey:metadata.fileID] floatValue];
        if (progress > 0) {
            
            if (metadata.cryptated) cell.progressView.progressTintColor = COLOR_CRYPTOCLOUD;
            else cell.progressView.progressTintColor = COLOR_TEXT_ANTHRACITE;
            
            cell.progressView.progress = progress;
            cell.progressView.hidden = NO;
        }
        
        // ----------------------------------------------------------------------------------------------------------
        // uploadFileError
        // ----------------------------------------------------------------------------------------------------------
        
        if (metadata.sessionTaskIdentifier == k_taskIdentifierError || metadata.sessionTaskIdentifierPlist == k_taskIdentifierError) {
            
            cell.labelTitle.enabled = NO;
            cell.statusImageView.image = [UIImage imageNamed:image_statuserror];
            
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

