//  NSDate+NCUtil.m
//  Nextcloud
//
//  Created by James Stout on 12/4/20.
//  Copyright (c) 2020, James Stout (stoutyhk@gmail.com) All rights reserved.
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

#import "NSDate+NCUtil.h"

@implementation NSDate (NCUtil)

/**
 *  Convenience method that returns a formatted string representing the receiver's date formatted to a given style,
 *
 *  @param format    NSString - Desired date formatting style

 *
 *  @return NSString representing the formatted date string
 */
- (NSString *)NC_stringFromDateWithFormat:(NSString*)format {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
    });

    [formatter setDateFormat:format];

    return [formatter stringFromDate:self];
}

@end
