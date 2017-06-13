//
//  CCPatenteGuida.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 25/11/14.
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

#import "CCPatenteGuida.h"
#import "XLFormViewController.h"
#import "XLForm.h"
#import "AppDelegate.h"
#import "NCBridgeSwift.h"

@interface CCPatenteGuida()
{
    XLFormDescriptor *form ;
    NSTimer* myTimer;
    NSMutableDictionary *field;
    CCTemplates *templates;
    NSString *_saveEtag;
}
@end

@implementation CCPatenteGuida

- (id)initWithDelegate:(id <CCPatenteGuidaDelegate>)delegate fileName:(NSString *)fileName uuid:(NSString *)uuid fileID:(NSString *)fileID isLocal:(BOOL)isLocal serverUrl:(NSString *)serverUrl
{
    self = [super init];
    
    if (self){
        
        self.delegate = delegate;
        self.fileName = fileName;
        self.isLocal = isLocal;
        self.fileID = fileID;
        self.uuid = uuid;
        self.serverUrl = serverUrl;
        
        // if fileName read Crypto File
        if (fileName)
            field = [[CCCrypto sharedManager] getDictionaryEncrypted:fileName uuid:uuid isLocal:isLocal directoryUser:app.directoryUser];
   
        //XLFormDescriptor * form ;
        XLFormSectionDescriptor * section;
        XLFormRowDescriptor * row;
  
        // Information - Section
        form = [XLFormDescriptor formDescriptor];
        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_title_", nil)];
        [form addFormSection:section];
        if (!fileName) form.assignFirstResponderOnShow = YES;
        
        // Titolo
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"titolo" rowType:XLFormRowDescriptorTypeText];
        [row.cellConfig setObject:[NCBrandColor sharedInstance].cryptocloud forKey:@"textField.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textField.font"];
        row.value = [field objectForKey:@"titolo"];
        row.required = YES;
        [section addFormRow:row];

        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_driving_license_", nil)];
        [form addFormSection:section];
        
        // Nome Cognome
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"comecognome" rowType:XLFormRowDescriptorTypeText title:NSLocalizedString(@"_name_surname:_", nil)];
        [row.cellConfig setObject:[UIColor blackColor] forKey:@"textField.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textField.font"];
        row.value = [field objectForKey:@"comecognome"];
        [section addFormRow:row];
        
        // Numero
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"numero" rowType:XLFormRowDescriptorTypeText title:NSLocalizedString(@"_license_number:_", nil)];
        [row.cellConfig setObject:[UIColor blackColor] forKey:@"textField.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textField.font"];
        row.value = [field objectForKey:@"numero"];
        [section addFormRow:row];

        // Data di rilascio
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"datarilascio" rowType:XLFormRowDescriptorTypeText title:NSLocalizedString(@"_date_of_issue:_", nil)];
        [row.cellConfig setObject:[UIColor blackColor] forKey:@"textField.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textField.font"];
        row.value = [field objectForKey:@"datarilascio"];
        [section addFormRow:row];
        
        // Data di scadenza
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"datascadenza" rowType:XLFormRowDescriptorTypeText title:NSLocalizedString(@"_date_of_expiry:_", nil)];
        [row.cellConfig setObject:[UIColor blackColor] forKey:@"textField.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textField.font"];
        row.value = [field objectForKey:@"datascadenza"];
        [section addFormRow:row];
        
        // Tipi di veicolo
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"tipiveicolo" rowType:XLFormRowDescriptorTypeText title:NSLocalizedString(@"_vehicle_types:_", nil)];
        [row.cellConfig setObject:[UIColor blackColor] forKey:@"textField.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textField.font"];
        row.value = [field objectForKey:@"tipiveicolo"];
        [section addFormRow:row];

        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_notes_", nil)];
        [form addFormSection:section];
        
        // Note
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"note" rowType:XLFormRowDescriptorTypeTextView];
        row.value = [field objectForKey:@"note"];
        [row.cellConfig setObject:[UIColor blackColor] forKey:@"textView.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textView.font"];
        [section addFormRow:row];
    
        self.form = form;
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelPressed:)];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(savePressed:)];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    templates = [[CCTemplates alloc] init];
    [templates setImageTitle:NSLocalizedString(@"_driving_license_", nil) conNavigationItem:self.navigationItem reachability:[app.reachability isReachable]];
        
    // Color
    [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.fileName && !field) [self performSelector:@selector(cancelPressed:) withObject:nil afterDelay:0.5];
}

- (void)didSelectFormRow:(XLFormRowDescriptor *)formRow
{
    [super didSelectFormRow:formRow];
    
    if ([formRow.tag isEqual:@"mytag"]) {
        // do your thing for your row.
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== IBAction ====
#pragma --------------------------------------------------------------------------------------------

- (IBAction)cancelPressed:(UIBarButtonItem * __unused)button
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)savePressed:(UIBarButtonItem * __unused)button
{
    NSString *fileNameModel;
    
    NSArray *validationErrors = [self formValidationErrors];
    if (validationErrors.count > 0){
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_enter_title_", nil) delegate:self cancelButtonTitle:NSLocalizedString(@"_ok_", nil) otherButtonTitles:nil];
        [alertView show];
        return;
    }
    [self.tableView endEditing:YES];
    
    fileNameModel = [templates salvaForm:form fileName:self.fileName uuid:self.uuid modello:@"patenteguida" icona:@"patenteguida"];
    
    if (fileNameModel) {
        
        XLFormRowDescriptor *titolo = [self.form formRowWithTag:@"titolo"];
        
        CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
        
        metadataNet.action = actionUploadTemplate;
        metadataNet.serverUrl = self.serverUrl;
        metadataNet.fileName = [CCUtility trasformedFileNamePlistInCrypto:fileNameModel];
        metadataNet.fileNamePrint = titolo.value;
        metadataNet.pathFolder = NSTemporaryDirectory();
        metadataNet.session = k_upload_session_foreground;
        metadataNet.taskStatus = k_taskStatusResume;
        
        [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
    }
}

- (void)uploadFileFailure:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector message:(NSString *)message errorCode:(NSInteger)errorCode
{
    if (![_saveEtag isEqualToString:fileID]) {
        
        _saveEtag = fileID;
        
        [app messageNotification:@"_upload_file_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
        
        // remove the file
        [[NCManageDatabase sharedInstance] deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID = %@", fileID] clearDateReadDirectoryID:nil];
        
        [self.delegate readFolder:self.serverUrl];
    }
}

- (void)uploadFileSuccess:(CCMetadataNet *)metadataNet fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector selectorPost:(NSString *)selectorPost
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
