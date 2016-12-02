//
//  CCShareDB.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 13/11/15.
//  Copyright (c) 2014 TWS. All rights reserved.
//

#import "CCShareDB.h"

#import "AppDelegate.h"

@interface CCShareDB ()

@end

@implementation CCShareDB

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
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
    
    form = [XLFormDescriptor formDescriptor];
    form.rowNavigationOptions = XLFormRowNavigationOptionNone;
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sharelink" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_share_link_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sharelinkbutton" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_share_link_button_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    row.action.formSelector = @selector(shareLinkButton:);
    [section addFormRow:row];

    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // view tint color
    [self.view setTintColor:COLOR_BRAND];
    
    [self reloadData];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, self.metadata.fileID]]) self.fileImageView.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, self.metadata.fileID]];
    else self.fileImageView.image = [UIImage imageNamed:self.metadata.iconName];
    
    self.labelTitle.text = self.metadata.fileNamePrint;
    [self.endButton setTitle:NSLocalizedString(@"_done_", nil) forState:UIControlStateNormal];
    self.endButton.tintColor = [COLOR_BRAND colorWithAlphaComponent:0.8];
    
    self.tableView.tableHeaderView = ({UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 0.1 / UIScreen.mainScreen.scale)];
        line.backgroundColor = self.tableView.separatorColor;
        line;
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Reload Data =====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadData
{
    self.shareLink = [app.sharesLink objectForKey:[self.serverUrl stringByAppendingString:self.metadata.fileName]];

    self.form.delegate = nil;

    XLFormRowDescriptor *rowShareLink = [self.form formRowWithTag:@"sharelink"];
    XLFormRowDescriptor *rowShareLinkButton = [self.form formRowWithTag:@"sharelinkbutton"];
    
    if ([self.shareLink length] > 0) [rowShareLink setValue:@1]; else [rowShareLink setValue:@0];
    
    rowShareLinkButton.hidden = [NSString stringWithFormat:@"$sharelink==0"];
 
    self.form.disabled = NO;
    self.form.delegate = self;
    
    [self.tableView reloadData];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Change Value & Button =====
#pragma --------------------------------------------------------------------------------------------

- (void)shareLinkButton:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    NSString *url = self.shareLink;
    
    NSArray *activityItems = @[[NSString stringWithFormat:@""], [NSURL URLWithString:url]];
    NSArray *applicationActivities = nil;
    
    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:applicationActivities];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) [self presentViewController:activityController animated:YES completion:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        
        UIPopoverController *popup;
        
        popup = [[UIPopoverController alloc] initWithContentViewController:activityController];
        [popup presentPopoverFromRect:CGRectMake(120, 100, 200, 400) inView:self.view permittedArrowDirections:UIPopoverArrowDirectionLeft animated:YES];
    }
}

-(void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    if ([rowDescriptor.tag isEqualToString:@"sharelink"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            
            // share
            [self.delegate share:self.metadata serverUrl:self.serverUrl password:@""];
            [self disableForm];
            
        } else {
            
            // unshare
            [self.delegate unShare:self.shareLink metadata:self.metadata serverUrl:self.serverUrl];
            [self disableForm];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Button =====
#pragma --------------------------------------------------------------------------------------------

- (IBAction)endButtonAction:(id)sender
{
    // reload delegate
    [self.delegate getDataSourceWithReloadTableView:self.metadata.directoryID fileID:nil selector:nil];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Utility =====
#pragma --------------------------------------------------------------------------------------------

-(void)disableForm
{
    self.form.disabled = YES;
    [self.tableView reloadData];
}

@end
