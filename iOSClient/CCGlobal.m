//
//  CCGlobal.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 13/10/14.
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

#import "CCGlobal.h"

// Directory on Group
NSString *const appApplicationSupport = @"Library/Application Support";
NSString *const appDatabase = @"Library/Application Support/Crypto Cloud";
NSString *const appCertificates = @"Library/Application Support/Certificates";

// webDAV & DAV
NSString *const webDAV = @"/remote.php/webdav";
NSString *const dav = @"/remote.php/dav";

#define COLOR_NAVIGATIONBAR                     [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:1.0] 
#define COLOR_NAVIGATIONBAR_TEXT                [UIColor whiteColor]
#define COLOR_CRYPTOCLOUD                       [UIColor colorWithRed:241.0/255.0 green:90.0/255.0 blue:34.0/255.0 alpha:1.0]
#define COLOR_TEXT_NO_CONNECTION                [UIColor colorWithRed:204.0/255.0 green:204.0/255.0 blue:204.0/255.0 alpha:1.0]
#define COLOR_TABBAR                            [UIColor whiteColor]
#define COLOR_TABBAR_TEXT                       [UIColor colorWithRed:0.0/255.0 green:130.0/255.0 blue:201.0/255.0 alpha:1.0]

@implementation CCAspect

+ (void)aspectNavigationControllerBar:(UINavigationBar *)nav encrypted:(BOOL)encrypted online:(BOOL)online hidden:(BOOL)hidden
{
    nav.translucent = NO;
    nav.barTintColor = COLOR_NAVIGATIONBAR;
    nav.tintColor = COLOR_NAVIGATIONBAR_TEXT;
    [nav setTitleTextAttributes:@{NSForegroundColorAttributeName : COLOR_NAVIGATIONBAR_TEXT}];

    if (encrypted)
        [nav setTitleTextAttributes:@{NSForegroundColorAttributeName : COLOR_CRYPTOCLOUD}];
    
    if (!online)
        [nav setTitleTextAttributes:@{NSForegroundColorAttributeName : COLOR_TEXT_NO_CONNECTION}];

    nav.hidden = hidden;
    
    [nav setAlpha:1];
}

+ (void)aspectTabBar:(UITabBar *)tab hidden:(BOOL)hidden
{    
    tab.translucent = NO;
    tab.barTintColor = COLOR_TABBAR;
    tab.tintColor = COLOR_TABBAR_TEXT;
    
    tab.hidden = hidden;
    
    [tab setAlpha:1];
}

@end
