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

// DAV
NSString *const webDAV = @"/remote.php/webdav";

// BKPasscode
NSString *const BKPasscodeKeychainServiceName = @"Crypto Cloud";

@implementation CCAspect

+ (void)aspectNavigationControllerBar:(UINavigationBar *)nav hidden:(BOOL)hidden
{
    nav.translucent = NO;
    nav.barTintColor = COLOR_BAR;
    nav.tintColor = COLOR_BRAND;
    
    nav.hidden = hidden;
    
    [nav setAlpha:1];
}

+ (void)aspectTabBar:(UITabBar *)tab hidden:(BOOL)hidden
{    
    tab.translucent = NO;
    tab.barTintColor = COLOR_BAR;
    tab.tintColor = COLOR_BRAND;
    
    tab.hidden = hidden;
    
    [tab setAlpha:1];
}

@end
