//
//  OCXMLSharedParser.m
//  OCCommunicationLib
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
//

#import "OCXMLSharedParser.h"
#import "OCSharedDto.h"

#define expirationDateFormat @"YYYY-MM-dd HH:mm:ss"

@implementation OCXMLSharedParser

@synthesize shareList=_shareList;
@synthesize currentShared=_currentShared;

/*
 * Method that init the parse with the xml data from the server
 * @data -> XML webDav data from the owncloud server
 */
- (void)initParserWithData: (NSData*)data{
    
    _shareList = [[NSMutableArray alloc]init];
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    [parser setDelegate:self];
    [parser parse];
    
}


#pragma mark - XML Parser Delegate Methods


/*
 * Method that init parse process.
 */

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    
    if (!_xmlChars) {
        _xmlChars = [NSMutableString string];
    }
    
    //NSLog(@"_xmlChars: %@", _xmlChars);
    
    [_xmlChars setString:@""];
    
    if ([elementName isEqualToString:@"element"]) {
        _xmlBucket = [NSMutableDictionary dictionary];
        
        if (_currentShared) {
            [_shareList addObject:_currentShared];
        }
    }
}

/*
 * Util method to make a NSDate object from a string from xml
 * @dateString -> Data string from xml
 */

+ (NSDate*)parseDateString:(NSString*)dateString {
    //Parse the date in all the formats
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    /*In most cases the best locale to choose is "en_US_POSIX", a locale that's specifically designed to yield US English results regardless of both user and system preferences. "en_US_POSIX" is also invariant in time (if the US, at some point in the future, changes the way it formats dates, "en_US" will change to reflect the new behaviour, but "en_US_POSIX" will not). It will behave consistently for all users.*/
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setDateFormat:expirationDateFormat];
    
    NSDate *theDate = nil;
    NSError *error = nil;
    if (![dateFormatter getObjectValue:&theDate forString:dateString range:nil error:&error]) {
        NSLog(@"Date '%@' could not be parsed: %@", dateString, error);
    }
    
    return theDate;
}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    //NSLog(@"elementName: %@:%@", elementName,_xmlChars);
    
    if ([elementName isEqualToString:@"id"]) {
        
        _currentShared = [[OCSharedDto alloc] init];
        _currentShared.idRemoteShared = [_xmlChars intValue];
        
    } else if ([elementName isEqualToString:@"item_type"]) {
        
        if([_xmlChars isEqualToString:@"file"]) {
            _currentShared.isDirectory = NO;
        } else {
            _currentShared.isDirectory = YES;
            if (_currentShared.path) {
                _currentShared.path = [_currentShared.path stringByAppendingString:@"/"];
            }
        }
    }  else if ([elementName isEqualToString:@"item_source"]) {
        
        _currentShared.itemSource = [_xmlChars intValue];
    
    } else if ([elementName isEqualToString:@"parent"]) {
        
        _currentShared.parent = [_xmlChars intValue];
        
    } else if ([elementName isEqualToString:@"share_type"]) {
        
        _currentShared.shareType = [_xmlChars intValue];
        
    } else if ([elementName isEqualToString:@"share_with"]) {
        
        _currentShared.shareWith = _xmlChars;
        
    } else if ([elementName isEqualToString:@"file_source"]) {
        
        _currentShared.fileSource = [_xmlChars intValue];
        
    } else if ([elementName isEqualToString:@"path"]) {
    
        if (_currentShared.isDirectory) {
            _currentShared.path = [_xmlChars stringByAppendingString:@"/"];
        } else {
            _currentShared.path = _xmlChars;
        }
    
    } else if ([elementName isEqualToString:@"permissions"]) {
        
        _currentShared.permissions = [_xmlChars intValue];
        
    } else if ([elementName isEqualToString:@"stime"]) {
        
        _currentShared.sharedDate = (long)[_xmlChars longLongValue];
        
        
    } else if ([elementName isEqualToString:@"expiration"]) {
        
        //Check expiration, is a optional field, sometimes is empty
        if (![_xmlChars isEqualToString:@""]) {
            NSDate *date = [[self class] parseDateString:_xmlChars];
            _currentShared.expirationDate = [date timeIntervalSince1970];
        }else{
            _currentShared.expirationDate = 0.0;
        }
        
    } else if ([elementName isEqualToString:@"token"]) {
        
        _currentShared.token = _xmlChars;
        
    } else if ([elementName isEqualToString:@"storage"]) {
        
        _currentShared.storage = [_xmlChars intValue];
        
    } else if ([elementName isEqualToString:@"mail_send"]) {
        
        _currentShared.mailSend = [_xmlChars intValue];
        
    } else if ([elementName isEqualToString:@"uid_owner"]) {
        
        _currentShared.uidOwner = _xmlChars;
        
    } else if ([elementName isEqualToString:@"uid_file_owner"]) {
    
    _currentShared.uidFileOwner = _xmlChars;
    
    } else if ([elementName isEqualToString:@"share_with_displayname"]) {
        
        _currentShared.shareWithDisplayName = _xmlChars;
        
    } else if ([elementName isEqualToString:@"displayname_owner"]) {
        
        _currentShared.displayNameOwner = _xmlChars;
        
        //Last value on the XML so we add the object to the array and begin again
        if (!_currentShared.shareWithDisplayName) {
            //To not have a nil we set an empty string
            _currentShared.shareWithDisplayName = @"";
        }
        
    } 
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [_xmlChars appendString:string];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser{
    
    //NSLog(@"Finish xml directory list parse");
    
    if (_currentShared) {
        
        [_shareList addObject:_currentShared];
    }
}


@end
