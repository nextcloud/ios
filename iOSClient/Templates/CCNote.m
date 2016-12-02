//
//  CCNoteViewController.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 25/11/14.
//  Copyright (c) 2014 TWS. All rights reserved.
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

#import "CCNote.h"

#import "AppDelegate.h"

@interface CCNote()
{
    NSMutableDictionary *field;
    CCTemplates *templates;
    
    NSString *initHtml;
}
@end

@implementation CCNote

- (id)initWithDelegate:(id <CCNoteDelegate>)delegate fileName:(NSString *)fileName uuid:(NSString *)uuid rev:(NSString *)rev fileID:(NSString *)fileID modelReadOnly:(BOOL)modelReadOnly isLocal:(BOOL)isLocal
{
    self = [super init];
    
    if (self){
        
        self.delegate = delegate;
        self.fileName = fileName;
        self.isLocal = isLocal;
        self.rev = rev;
        self.fileID = fileID;
        self.uuid = uuid;
        
        CCCrypto *crypto = [[CCCrypto alloc] init];
        
        // if fileName read Crypto File
        if (fileName)
            field = [crypto getDictionaryEncrypted:fileName uuid:uuid isLocal:isLocal directoryUser:app.directoryUser];
   
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelPressed:)];
        
        if (modelReadOnly) self.navigationItem.rightBarButtonItem = nil;
        else self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(savePressed:)];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([field objectForKey:@"titolo"]) {
        
        self.titolo = [field objectForKey:@"titolo"];
        self.shouldShowKeyboard = NO;
        
    } else {
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH-mm-ss"];
        self.titolo =  [NSString stringWithFormat:@"Note %@", [formatter stringFromDate:[NSDate date]]];
        self.shouldShowKeyboard = YES;
    }

    //
    [self setHTML:[field objectForKey:@"note"]];
    
    //
    self.toolbarItemTintColor = COLOR_BRAND;
    
    templates = [[CCTemplates alloc] init];
    [templates setImageTitle:self.titolo conNavigationItem:self.navigationItem reachability:[app.reachability isReachable]];
        
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    initHtml = [self getHTML];
    
    if (self.fileName && !field) [self performSelector:@selector(cancelPressed:) withObject:nil afterDelay:0.5];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== IBAction ====
#pragma --------------------------------------------------------------------------------------------

- (IBAction)cancelPressed:(UIBarButtonItem * __unused)button
{
    if ([initHtml isEqualToString:[self getHTML]] == NO) {
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_info_", nil) message:NSLocalizedString(@"_save_exit_", nil) preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_yes_", nil)
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *action) {
                                                               [self dismissViewControllerAnimated:YES completion:nil];
                                                           }]];
        
        [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_no_", nil)
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *action) {
                                                               return;
                                                           }]];

        [self presentViewController:alertController animated:YES completion:nil];
        
    } else
        [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)savePressed:(UIBarButtonItem * __unused)button
{
    NSString *fileNameModel;
    NSString *html = [self getHTML];
    
    if ([html length] > 0) {
    
        fileNameModel = [templates salvaNote:html titolo:self.titolo fileName:self.fileName uuid:self.uuid];
    
        if (fileNameModel) {
            
            CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
            
            metadataNet.action = actionUploadTemplate;
            metadataNet.serverUrl = app.serverUrl;
            metadataNet.fileName = [CCUtility trasformedFileNamePlistInCrypto:fileNameModel];
            metadataNet.fileNamePrint = _titolo;
            metadataNet.pathFolder = NSTemporaryDirectory();
            metadataNet.rev = self.rev;
            metadataNet.session = upload_session_foreground;
            metadataNet.taskStatus = taskStatusResume;
            
            // 2
            [app addNetworkingOperationQueue:app.netQueue delegate:self.delegate metadataNet:metadataNet oneByOne:YES];
            
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

@end
