//
//  NSString+TruncateToWidth.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 06/04/16.
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

#import "NSString+TruncateToWidth.h"

#define ellipsis @"…"

@implementation NSString (TruncateToWidth)

- (NSString*)stringByTruncatingToWidth:(CGFloat)width withFont:(UIFont *)font atEnd:(BOOL)atEnd
{
    // Create copy that will be the returned result
    NSMutableString *truncatedString = [self mutableCopy];
    
    // Make sure string is longer than requested width
    if ([self widthWithFont:font] > width)
    {
        // Accommodate for ellipsis we'll tack on the beginning
        width -= [ellipsis widthWithFont:font];
        
        // Loop, deleting characters until string fits within width
        while ([truncatedString widthWithFont:font] > width)
        {
            NSRange range;
            
            if (atEnd) {
                range.location = [truncatedString length] -1;
                range.length = 1;
            }else {
                range.location = 0;
                range.length = 1;
            }
            
            // Delete character
            [truncatedString deleteCharactersInRange:range];
        }
        
        // Append ellipsis
        if (atEnd) truncatedString = (NSMutableString *)[truncatedString stringByAppendingString:ellipsis];
        else [truncatedString replaceCharactersInRange:NSMakeRange(0, 0) withString:ellipsis];
    }
    
    return truncatedString;
}

- (CGFloat)widthWithFont:(UIFont *)font
{
    return [self sizeWithAttributes:@{NSFontAttributeName:font}].width;    
}

@end

