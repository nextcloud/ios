//
//  NCXMLCommentsParser.m
//  Nextcloud
//
//  Created by Marino Faggiana on 08/08/19.
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

#import "NCXMLCommentsParser.h"

@implementation NCXMLCommentsParser

- (void)initParserWithData: (NSData*)data{
    
    self.list = [NSMutableArray new];
    
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
        
        self.currentComment = [NCComments new];
        
    } else if ([elementName isEqualToString:@"oc:id"]) {
        
        self.currentComment.messageID = [NSString stringWithString:self.xmlChars];
    
    } else if ([elementName isEqualToString:@"oc:verb"]) {
        
        self.currentComment.verb = [NSString stringWithString:self.xmlChars];
        
    } else if ([elementName isEqualToString:@"oc:actorType"]) {
        
        self.currentComment.actorType = [NSString stringWithString:self.xmlChars];
        
    } else if ([elementName isEqualToString:@"oc:actorId"]) {
        
        self.currentComment.actorId = [NSString stringWithString:self.xmlChars];
        
    } else if ([elementName isEqualToString:@"oc:creationDateTime"]) {
        
        if ([self.xmlChars length]) {
            NSDateFormatter *dateFormatter = [NSDateFormatter new];
            [dateFormatter setDateFormat:@"EEE, dd MMM y HH:mm:ss zzz"];
            [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
            self.currentComment.creationDateTime = [dateFormatter dateFromString:[NSString stringWithString:self.xmlChars]];
        }
        
    } else if ([elementName isEqualToString:@"oc:objectType"]) {
        
        self.currentComment.objectType = [NSString stringWithString:self.xmlChars];
    
    } else if ([elementName isEqualToString:@"oc:objectId"]) {
        
        self.currentComment.objectId = [NSString stringWithString:self.xmlChars];
        
    } else if ([elementName isEqualToString:@"oc:isUnread"]) {
        
        self.currentComment.isUnread = [self.xmlChars boolValue];
        
    } else if ([elementName isEqualToString:@"oc:message"]) {
        
        self.currentComment.message = [NSString stringWithString:self.xmlChars];
    
    } else if ([elementName isEqualToString:@"oc:actorDisplayName"]) {
        
        self.currentComment.actorDisplayName = [NSString stringWithString:self.xmlChars];
        
    } else if ([elementName isEqualToString:@"d:status"]) {
        
        self.status = [NSString stringWithString:self.xmlChars];
        
    } else if ([elementName isEqualToString:@"d:response"]) {
    
        if ([self.status containsString:@"200"]) {
            [self.list addObject:self.currentComment];
        }
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [self.xmlChars appendString:string];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
    NSLog(@"Finish xml comments parse");
}

@end
