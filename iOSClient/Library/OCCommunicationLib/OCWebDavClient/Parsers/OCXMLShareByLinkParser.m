//
//  OCXMLShareByLinkParser.m
//  OCCommunicationLib
//
//  Created by Javier González on 1/13/14.
//  Copyright (c) 2014 ownCloud. All rights reserved.
//

// Copyright (C) 2016, ownCloud GmbH. ( http://www.owncloud.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "OCXMLShareByLinkParser.h"

@interface OCXMLShareByLinkParser()

@property (nonatomic, strong) NSMutableString *xmlChars;
@property (nonatomic, strong) NSMutableDictionary *xmlBucket;

@end

@implementation OCXMLShareByLinkParser

/*
 * Method that init the parse with the xml data from the server
 * @data -> XML webDav data from the owncloud server
 */
- (void)initParserWithData: (NSData*)data{
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    [parser setDelegate:self];
    [parser parse];
    
}


#pragma mark - XML Parser Delegate Methods


/*
 * Method that init parse process.
 */

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    
    if (!self.xmlChars) {
        self.xmlChars = [NSMutableString string];
    }
    
    [self.xmlChars setString:@""];
    
    if ([elementName isEqualToString:@"ocs"]) {
        self.xmlBucket = [NSMutableDictionary dictionary];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    if ([elementName isEqualToString:@"statuscode"]) {
        self.statusCode = [self.xmlChars intValue];
    }

    if ([elementName isEqualToString:@"token"]) {
        self.token = [NSString stringWithString:self.xmlChars];
    }
    
    if ([elementName isEqualToString:@"message"]) {
        self.message = [NSString stringWithString:self.xmlChars];
    }
    
    if ([elementName isEqualToString:@"url"]) {
        self.url = [NSString stringWithString:self.xmlChars];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [self.xmlChars appendString:string];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser{
    
    NSLog(@"Finish xml directory list parse");
}

@end
