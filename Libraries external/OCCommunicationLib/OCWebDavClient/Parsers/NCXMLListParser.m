//
//  NCXMLListParser.m
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

#import "NCXMLListParser.h"

@implementation NCXMLListParser

- (void)initParserWithData:(NSData *)data controlFirstFileOfList:(BOOL)controlFirstFileOfList {
    
    self.list = [NSMutableArray new];
    self.controlFirstFileOfList = controlFirstFileOfList;
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    [parser setDelegate:self];
    [parser parse];
}

#pragma mark - XML Parser Delegate Methods

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    
    if (!self.xmlChars) {
        self.xmlChars = [NSMutableString string];
    }
    
    [self.xmlChars setString:@""];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    if ([elementName isEqualToString:@"d:href"]) {
        
        if ([self.xmlChars hasPrefix:@"http"]) {
            NSURL *junk = [NSURL URLWithString:self.xmlChars];
            BOOL trailingSlash = [_xmlChars hasSuffix:@"/"];
            [self.xmlChars setString:[junk path]];
            if (trailingSlash) {
                [self.xmlChars appendString:@"/"];
            }
        }
        
        if ([self.xmlChars length]) {
            
            self.xmlChars = (NSMutableString *)[_xmlChars stringByReplacingOccurrencesOfString:@"//" withString:@"/"];
            
            //Create FileDto
            self.currentFile = [OCFileDto new];
            self.currentFile.isDirectory = NO;
            
            NSArray *splitedUrl = [self.xmlChars componentsSeparatedByString:@"/"];
            if([self.xmlChars hasSuffix:@"/"]) {
                //It's a folder
                NSInteger fileNameLenght = [((NSString *)[splitedUrl objectAtIndex:[splitedUrl count]-2]) length];
                if ( fileNameLenght > 0) {
                    self.currentFile.filePath = [self.xmlChars substringToIndex:[self.xmlChars length] - (fileNameLenght+1)];
                } else {
                    self.currentFile.filePath = @"/";
                }
            } else {
                //It's a file
                NSInteger fileNameLenght = [((NSString *)[splitedUrl objectAtIndex:[splitedUrl count]-1]) length];
                if (fileNameLenght > 0) {
                    self.currentFile.filePath = [self.xmlChars substringToIndex:[self.xmlChars length] - fileNameLenght];
                }else {
                    self.currentFile.filePath = @"/";
                }
            }
            
            NSArray *foo = [self.xmlChars componentsSeparatedByString: @"/"];
            NSString *lastBit;
            
            if([self.xmlChars hasSuffix:@"/"]) {
                lastBit = [foo objectAtIndex: [foo count]-2];
                lastBit = [NSString stringWithFormat:@"%@/",lastBit];
            } else {
                lastBit = [foo objectAtIndex: [foo count]-1];
            }
            
            if (self.controlFirstFileOfList) {
                if (isNotFirstFileOfList) {
                    self.currentFile.fileName = lastBit;
                }
            } else {
                self.currentFile.fileName = lastBit;
            }
            
            self.currentFile.fileName = [self.currentFile.fileName stringByRemovingPercentEncoding];
            self.currentFile.filePath = [self.currentFile.filePath stringByRemovingPercentEncoding];
            
            isNotFirstFileOfList = true;
        }
        
    } else if ([elementName isEqualToString:@"d:displayname"] && [self.xmlChars length]) {
        
        self.currentFile.displayName = [NSString stringWithString:self.xmlChars];

    } else if ([elementName isEqualToString:@"d:getcontenttype"] && [self.xmlChars length]) {
        
        self.currentFile.contentType = [NSString stringWithString:self.xmlChars];

    } else if ([elementName isEqualToString:@"d:resourcetype"] && [self.xmlChars length]) {
        
        self.currentFile.resourceType = [NSString stringWithString:self.xmlChars];

    } else if ([elementName isEqualToString:@"d:getcontentlength"] && [self.xmlChars length]) {
        
        self.currentFile.size = (long)[self.xmlChars longLongValue];

    } else if ([elementName isEqualToString:@"d:getlastmodified"] && [self.xmlChars length]) {
        
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateFormat:@"EEE, dd MMM y HH:mm:ss zzz"];
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        NSDate *date = [dateFormatter dateFromString:[NSString stringWithString:self.xmlChars]];
        if (date) {
            self.currentFile.date =  [date timeIntervalSince1970];
        }
        
    } else if ([elementName isEqualToString:@"d:creationdate"] && [self.xmlChars length]) {
        
        NSLog(@"Not yet implemented");
        
    } else if ([elementName isEqualToString:@"d:getetag"] && [self.xmlChars length]) {
        
        self.currentFile.etag = [[self.xmlChars stringByReplacingOccurrencesOfString:@"\"" withString:@""] lowercaseString];

    } else if ([elementName isEqualToString:@"d:quota-used-bytes"] && [self.xmlChars length]) {
        
        self.currentFile.quotaUsedBytes = (long)[self.xmlChars longLongValue];

    } else if ([elementName isEqualToString:@"d:quota-available-bytes"] && [self.xmlChars length]) {
        
        self.currentFile.quotaAvailableBytes = (long)[self.xmlChars longLongValue];

    } else if ([elementName isEqualToString:@"oc:permissions"] && [self.xmlChars length]) {
    
        self.currentFile.permissions = [NSString stringWithString:self.xmlChars];
    
    } else if ([elementName isEqualToString:@"oc:id"] && [self.xmlChars length]) {
        
        self.currentFile.ocId = [NSString stringWithString:self.xmlChars];
        
    } else if ([elementName isEqualToString:@"oc:fileid"]  && [self.xmlChars length]) {
        
        self.currentFile.fileId = [NSString stringWithString:self.xmlChars];
        
    } else if ([elementName isEqualToString:@"oc:size"] && [self.xmlChars length]) {
        
        self.currentFile.size = (long)[self.xmlChars longLongValue];

    } else if ([elementName isEqualToString:@"oc:favorite"] && [self.xmlChars length]) {
        
        self.currentFile.isFavorite = [self.xmlChars boolValue];

    } else if ([elementName isEqualToString:@"nc:is-encrypted"] && [self.xmlChars length]) {
        
        self.currentFile.isEncrypted = [self.xmlChars boolValue];

    } else if ([elementName isEqualToString:@"nc:mount-type"] && [self.xmlChars length]) {
        
        self.currentFile.mountType = [NSString stringWithString:self.xmlChars];

    } else if ([elementName isEqualToString:@"oc:owner-id"] && [self.xmlChars length]) {
        
        self.currentFile.ownerId = [NSString stringWithString:self.xmlChars];

    } else if ([elementName isEqualToString:@"oc:owner-display-name"] && [self.xmlChars length]) {
        
        self.currentFile.ownerDisplayName = [NSString stringWithString:self.xmlChars];

    } else if ([elementName isEqualToString:@"oc:comments-unread"] && [self.xmlChars length]) {
        
        self.currentFile.commentsUnread = [self.xmlChars boolValue];

    } else if ([elementName isEqualToString:@"nc:has-preview"] && [self.xmlChars length]) {
        
        self.currentFile.hasPreview = [self.xmlChars boolValue];

    } else if ([elementName isEqualToString:@"nc:trashbin-filename"] && [self.xmlChars length]) {
        
        self.currentFile.trashbinFileName = [NSString stringWithString:self.xmlChars];

    } else if ([elementName isEqualToString:@"nc:trashbin-original-location"] && [self.xmlChars length]) {
        
        self.currentFile.trashbinOriginalLocation = [NSString stringWithString:self.xmlChars];

    } else if ([elementName isEqualToString:@"nc:trashbin-deletion-time"] && [self.xmlChars length]) {
        
        self.currentFile.trashbinDeletionTime = (long)[self.xmlChars longLongValue];

    } else if ([elementName isEqualToString:@"d:collection"]) {
        
        self.currentFile.isDirectory = true;

    } else if ([elementName isEqualToString:@"d:response"]) {
    
        [self.list addObject:self.currentFile];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [self.xmlChars appendString:string];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
    NSLog(@"Finish xml list parse");
}

@end
