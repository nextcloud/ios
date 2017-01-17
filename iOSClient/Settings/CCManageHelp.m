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
    row.action.formSelector = @selector(intro:);
    [section addFormRow:row];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"switchuser" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_help_switch_user_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    row.action.formSelector = @selector(switchUser:);
    [section addFormRow:row];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"controlcenter" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_help_control_center_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    row.action.formSelector = @selector(controlCenter:);
    [section addFormRow:row];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"copypaste" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_help_copy_paste_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    row.action.formSelector = @selector(copypaste:);
    [section addFormRow:row];

    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // Intro
    self.intro = [[CCIntro alloc] initWithDelegate:self delegateView:self.splitViewController.view];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
}

- (void)intro:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [self.intro showIntroCryptoCloud:0.1];
}

- (void)share:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [self.intro showIntroVersion:@"1.91" duration:0.1 review:YES];
}

- (void)itunesshare:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [self.intro showIntroVersion:@"1.94" duration:0.1 review:YES];
}

- (void)shareExt:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [self.intro showIntroVersion:@"1.96" duration:0.1 review:YES];
}

- (void)switchUser:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [self.intro showIntroVersion:@"1.99" duration:0.1 review:YES];
}

- (void)controlCenter:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [self.intro showIntroVersion:@"2.0" duration:0.1 review:YES];
}

- (void)copypaste:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [self.intro showIntroVersion:@"2.10" duration:0.1 review:YES];
}

@end
