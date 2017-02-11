//
//  CCSecurityOptions.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 31/03/16.
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

#import "CCSecurityOptions.h"

#import "AppDelegate.h"

@interface CCSecurityOptions()
{
    NSTimer* myTimer;
    NSMutableDictionary *field;
}
@end

@implementation CCSecurityOptions

- (id)initWithDelegate:(id <CCSecurityOptionsDelegate>)delegate
{    
    self = [super init];
    
    if (self){
        
        self.delegate = delegate;
        
        XLFormDescriptor * form ;
        XLFormSectionDescriptor *section;
        XLFormRowDescriptor *row;
        
        // form mail
        form = [XLFormDescriptor formDescriptor];
        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_security_init_required_mail_", nil)];
        [form addFormSection:section];
        form.assignFirstResponderOnShow = YES;
        form.rowNavigationOptions = XLFormRowNavigationOptionNone;
        
        // mail
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"mail" rowType:XLFormRowDescriptorTypeEmail title:NSLocalizedString(@"_email_", nil)];
        [row.cellConfig setObject:COLOR_GRAY forKey:@"textField.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textField.font"];
        [section addFormRow:row];
        
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
        
        // Send aes-256 password via mail
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sendmailencryptpass" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_encryptpass_by_email_", nil)];
        [row.cellConfig setObject:@(NSTextAlignmentCenter) forKey:@"textLabel.textAlignment"];
        [row.cellConfig setObject:COLOR_ENCRYPTED forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIImage imageNamed:image_settingsKeyMail] forKey:@"imageView.image"];
        row.action.formSelector = @selector(sendMailEncryptPass:);
        //row.disabled = @1;
        [section addFormRow:row];

        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_security_init_required_hint_", nil)];
        [form addFormSection:section];
        
        // hint
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"hint" rowType:XLFormRowDescriptorTypeText title:NSLocalizedString(@"_hint_", nil)];
        [row.cellConfig setObject:COLOR_GRAY forKey:@"textField.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textField.font"];
        [section addFormRow:row];

        self.form = form;
    
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(donePressed)];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = NSLocalizedString(@"_title_form_security_init_", nil);
    
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
}

-(void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Done ====
#pragma --------------------------------------------------------------------------------------------

- (void)donePressed
{
    XLFormRowDescriptor *rowMail = [self.form formRowWithTag:@"mail"];
    XLFormRowDescriptor *rowHint = [self.form formRowWithTag:@"hint"];
    
    if ([CCUtility isValidEmail:rowMail.value])
        [CCUtility setEmail:(NSString *)rowMail.value];
    else
        [CCUtility setEmail:@""];
    
    if ([rowHint.value length] >0)
        [CCUtility setHint:(NSString *)rowHint.value];
    else
        [CCUtility setHint:@""];
     
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Mail ===
#pragma --------------------------------------------------------------------------------------------

- (void) mailComposeController:(MFMailComposeViewController *)vc didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result) {
            
        case MFMailComposeResultCancelled:
            [app messageNotification:@"_info_" description:@"_mail_deleted_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
            break;
        case MFMailComposeResultSaved:
            [app messageNotification:@"_info_" description:@"_mail_saved_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
            break;
        case MFMailComposeResultSent:
            [app messageNotification:@"_info_" description:@"_mail_sent_" visible:YES  delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
            break;
        case MFMailComposeResultFailed: {
            NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"_mail_failure_", nil), [error localizedDescription]];
            [app messageNotification:@"_error_" description:msg visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError];
        }
            break;
        default:
            break;
    }
    
    // Close the Mail Interface
    [self dismissViewControllerAnimated:YES completion:NULL];
    
    // Close 
    [self donePressed];
}

- (void)sendMailEncryptPass:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    XLFormRowDescriptor *row = [self.form formRowWithTag:@"mail"];
    
    [CCUtility sendMailEncryptPass:row.value validateEmail:YES form:self];
}

@end
