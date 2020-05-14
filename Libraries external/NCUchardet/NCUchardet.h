//
//  NCUchardet.h
//  Nextcloud
//
//  Created by Marino Faggiana on 16/08/17.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

// wrapper for library C++ https://cgit.freedesktop.org/uchardet/uchardet/ the universal charset detection library by Mozilla

#import <Foundation/Foundation.h>

@interface NCUchardet : NSObject

+ (NCUchardet *)sharedNUCharDet;

- (NSString *)encodingStringDetectWithData:(NSData *)data;
- (CFStringEncoding)encodingCFStringDetectWithData:(NSData *)data;

@end
