//
//  CCHud.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 22/02/16.
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

#import "CCHud.h"

@interface CCHud ()
{
    UIView * _view;
}
@end

@implementation CCHud

- (id)initWithView:(id)view
{
    self = [super init];
    
    _view = view;
    return self;
}

// mode :   MBProgressHUDModeDeterminateHorizontalBar
//          MBProgressHUDModeDeterminate
//          MBProgressHUDModeIndeterminate

- (void)visibleHudTitle:(NSString *)title mode:(MBProgressHUDMode)mode color:(UIColor *)color
{
    if (self.hud) return;
    
    self.hud = [MBProgressHUD showHUDAddedTo:_view animated:NO];
    
    if (!self.hud) return;
    
    self.hud.removeFromSuperViewOnHide = YES;
    self.hud.mode = mode ;
    if (title) self.hud.label.text = title;
    self.hud.hidden = NO;
    if (color) self.hud.bezelView.color = color;
}

- (void)visibleIndeterminateHud
{
    [self visibleHudTitle:nil mode:MBProgressHUDModeIndeterminate color:nil];
}

- (void)hideHud
{
    if (self.hud) {
        [self.hud hideAnimated:YES];
        [self.hud removeFromSuperview];
        self.hud = nil;
    }
}

- (void)progress:(float)progress
{
    if (self.hud) self.hud.progress = progress;
}

- (void)AddButtonCancelWithTarget:(id)target selector:(NSString *)selector
{
    [self.hud.button setTitle:NSLocalizedString(@"_cancel_", nil) forState:UIControlStateNormal];
    [self.hud.button addTarget:target action:(NSSelectorFromString(selector)) forControlEvents:UIControlEventTouchUpInside];
}

@end
