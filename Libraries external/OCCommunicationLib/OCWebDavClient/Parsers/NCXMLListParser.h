//
//  NCXMLListParser.h
//  Nextcloud
//
//  Created by Marino Faggiana on 17/08/19.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

#import <Foundation/Foundation.h>
#import "OCFileDto.h"

@interface NCXMLListParser : NSObject <NSXMLParserDelegate> {
    
    BOOL isNotFirstFileOfList;
}

@property BOOL controlFirstFileOfList;

@property (nonatomic, strong) NSMutableArray *list;
@property (nonatomic, strong) OCFileDto *currentFile;

@property (nonatomic, strong) NSMutableString *xmlChars;
@property (nonatomic, strong) NSString *status;

- (void)initParserWithData:(NSData *)data controlFirstFileOfList:(BOOL)controlFirstFileOfList;

@end
