//
//  CCManageHelp.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 06/11/15.
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

#import "CCManageHelp.h"
#import "CCUtility.h"
#import "AppDelegate.h"

@interface CCManageHelp ()

@end

@implementation CCManageHelp

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        
        [self initializeForm];
    }
    
    return self;
}

- (void)initializeForm
{
    XLFormDescriptor *form ;
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_help_", nil)];
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_help_tutorial_", nil)];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"intro" rowType:XLFormRowDescriptorTypeButton title:[CCUtility localizableBrand:@"_help_intro_" table:nil]];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:COLOR_BRAND forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsIntroduction] forKey:@"imageView.image"];
    row.action.formSelector = @selector(intro:);
    [section addFormRow:row];

    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_help_activity_section_", nil)];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"activityVerboseHigh" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_help_activity_verbose_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsActivityHigh] forKey:@"imageView.image"];
    if ([CCUtility getActivityVerboseHigh]) row.value = @"1";
    else row.value = @"0";
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sendMailActivity" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_help_activity_mail_", nil)];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:COLOR_BRAND forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsSendActivity] forKey:@"imageView.image"];
    row.action.formSelector = @selector(sendMail:);
    [section addFormRow:row];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"clearActivityLog" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_help_activity_clear_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:COLOR_BRAND forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsClearActivity] forKey:@"imageView.image"];
    row.action.formSelector = @selector(clearActivity:);
    [section addFormRow:row];


    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // Intro
    self.intro = [[CCIntro alloc] initWithDelegate:self delegateView:self.splitViewController.view];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
}

- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    if ([rowDescriptor.tag isEqualToString:@"activityVerboseHigh"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            [CCUtility setActivityVerboseHigh:true];
        } else {
            [CCUtility setActivityVerboseHigh:false];
        }
        
        // Clear Date read Activity for force reload datasource
        app.controlCenterActivity.storeDateFirstActivity = nil;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Intro ===
#pragma --------------------------------------------------------------------------------------------

- (void)intro:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [self.intro showIntroCryptoCloud:0.1];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Mail ===
#pragma --------------------------------------------------------------------------------------------

- (void) mailComposeController:(MFMailComposeViewController *)vc didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            [app messageNotification:@"_info_" description:@"_mail_deleted_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
            break;
        case MFMailComposeResultSaved:
            [app messageNotification:@"_info_" description:@"_mail_saved_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
            break;
        case MFMailComposeResultSent:
            [app messageNotification:@"_info_" description:@"_mail_sent_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
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
}

- (void)sendMail:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    // Email Subject
    NSString *emailTitle = NSLocalizedString(@"_information_req_", nil);
    // Email Content
    NSString *messageBody;
    // File Attachment
    NSString *fileAttachment = @"";
    // Email Recipents
    NSArray *toRecipents;
    
    NSArray *activities = [CCCoreData getAllTableActivityWithPredicate:[NSPredicate predicateWithFormat:@"((account == %@) || (account == ''))", app.activeAccount]];
    
    if ([activities count] == 0) {
        
        [app messageNotification:@"_info_" description:@"No activity found" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo];
        return;
    }
    
    for (TableActivity *activity in activities) {
        
        NSString *date, *type, *actionFile, *note;
        
        date = [[NSDateFormatter localizedStringFromDate:activity.date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterMediumStyle] stringByPaddingToLength:22 withString:@" " startingAtIndex:0];
        
        if ([activity.type isEqual: k_activityTypeInfo])    type = @"Info   ";
        if ([activity.type isEqual: k_activityTypeSuccess]) type = @"Success";
        if ([activity.type isEqual: k_activityTypeFailure]) type = @"Failure";
        
        actionFile = [[NSString stringWithFormat:@"%@ %@", activity.action, activity.file] stringByPaddingToLength:100 withString:@" " startingAtIndex:0];
        
        if (activity.idActivity == 0) note = [NSString stringWithFormat:@"%@ Selector: %@", activity.note, activity.selector];
        else note = activity.note;
        note = [note stringByPaddingToLength:200 withString:@" " startingAtIndex:0];
        
        fileAttachment = [fileAttachment stringByAppendingString:[NSString stringWithFormat:@"| %@ | %@ | %@ | %@ |\n", date, type, actionFile, note]];
    }
    
    messageBody = [NSString stringWithFormat:@"\n\n\n%@ Version %@ (%@)", k_brand,[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSError *error;
    
    if ([fileAttachment writeToFile:[documentsDirectory stringByAppendingPathComponent:@"activity.txt"] atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        
        toRecipents = [NSArray arrayWithObject:k_mailMe];
        
        MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
        mc.mailComposeDelegate = self;
        [mc setSubject:emailTitle];
        [mc setMessageBody:messageBody isHTML:NO];
        [mc setToRecipients:toRecipents];
        
        NSData *noteData = [NSData dataWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:@"activity.txt"]];
        [mc addAttachmentData:noteData mimeType:@"text/plain" fileName:@"activity.txt"];
        
        // Present mail view controller on screen
        [self presentViewController:mc animated:YES completion:NULL];
        
    } else {
        
        [app messageNotification:@"_error_" description:@"Impossible create file body" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Clear ===
#pragma --------------------------------------------------------------------------------------------

- (void)clearActivity:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [CCCoreData flushTableActivityAccount:app.activeAccount];
    
    [app.controlCenterActivity reloadDatasource];
}

@end
