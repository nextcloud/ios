//
//  OCXMLParser.m
//  webdav
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
//  Add Support for Quota
//  quotaUsed and quotaAvailable
//
//  Add Support for Favorite
//  isFavorite
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//

#import "OCXMLParser.h"
#import "NSString+Encode.h"

NSString *OCCWebDAVContentTypeKey   = @"contenttype";
NSString *OCCWebDAVETagKey          = @"etag";
NSString *OCCWebDAVHREFKey          = @"href";
NSString *OCCWebDAVURIKey           = @"uri";

@implementation OCXMLParser

@synthesize directoryList=_directoryList;
@synthesize currentFile=_currentFile;

/*
 * Method that init the parse with the xml data from the server
 * @data -> XML webDav data from the owncloud server
 */
- (void)initParserWithData: (NSData*)data{
    
    _directoryList = [[NSMutableArray alloc]init];
    
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

    if ([elementName isEqualToString:@"d:response"]) {
        _xmlBucket = [NSMutableDictionary dictionary];
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
    //This is the format for the concret locale used
    [dateFormatter setDateFormat:@"EEE, dd MMM y HH:mm:ss zzz"];
    
    NSDate *theDate = nil;
    NSError *error = nil;
    if (![dateFormatter getObjectValue:&theDate forString:dateString range:nil error:&error]) {
        NSLog(@"Date '%@' could not be parsed: %@", dateString, error);
    }
    
    return theDate;
}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    // NSLog(@"elementName: %@:%@", elementName,_xmlChars);
    
    if ([elementName isEqualToString:@"d:href"]) {
        
        if ([_xmlChars hasPrefix:@"http"]) {
            NSURL *junk = [NSURL URLWithString:_xmlChars];
            BOOL trailingSlash = [_xmlChars hasSuffix:@"/"];
            [_xmlChars setString:[junk path]];
            if (trailingSlash) {
                [_xmlChars appendString:@"/"];
            }
        }
        
        //If has lenght, there are an item
        if ([_xmlChars length]) {
            //Create FileDto
            _currentFile = [[OCFileDto alloc] init];
             _currentFile.isDirectory = NO;
            [_xmlBucket setObject:[_xmlChars copy] forKey:OCCWebDAVURIKey];
            
            NSArray *splitedUrl = [_xmlChars componentsSeparatedByString:@"/"];
            
            //Check if the item is a folder or a file
            if([_xmlChars hasSuffix:@"/"]) {
                //It's a folder
                NSInteger fileNameLenght = [((NSString *)[splitedUrl objectAtIndex:[splitedUrl count]-2]) length];
                
                if ( fileNameLenght > 0) {
                    //FileDto filepath
                    _currentFile.filePath = [_xmlChars substringToIndex:[_xmlChars length] - (fileNameLenght+1)];
                } else {
                    _currentFile.filePath = @"/";
                }
            } else {
                //It's a file
                NSInteger fileNameLenght = [((NSString *)[splitedUrl objectAtIndex:[splitedUrl count]-1]) length];
                if (fileNameLenght > 0) {
                    _currentFile.filePath = [_xmlChars substringToIndex:[_xmlChars length] - fileNameLenght];
                }else {
                    _currentFile.filePath = @"/";
                }
            }
       
      
    
        NSArray *foo = [_xmlChars componentsSeparatedByString: @"/"];
        NSString *lastBit;
        
        if([_xmlChars hasSuffix:@"/"]) {
            lastBit = [foo objectAtIndex: [foo count]-2];
            lastBit = [NSString stringWithFormat:@"%@/",lastBit];
        } else {
            lastBit = [foo objectAtIndex: [foo count]-1];
        }
        
        //NSString *lastBit = [_xmlChars substringFromIndex:_uriLength];
        //NSLog(@"lastBit:- %@",lastBit);
        if (isNotFirstFileOfList == YES) {
            [_xmlBucket setObject:lastBit forKey:OCCWebDAVHREFKey];
            _currentFile.fileName = lastBit;
        }
            
        NSString *decodedFileName = [self decodeFromPercentEscapeString:self.currentFile.fileName];
        NSString *decodedFilePath = [self decodeFromPercentEscapeString:self.currentFile.filePath];
            
        self.currentFile.fileName = [decodedFileName encodeString:NSUTF8StringEncoding];
        self.currentFile.filePath = [decodedFilePath encodeString:NSUTF8StringEncoding];
            
        isNotFirstFileOfList = YES;

//        //NSLog(@"1 _xmlBucked :- %@",_xmlBucket);
     }
    } else if ([elementName isEqualToString:@"d:getlastmodified"]) {
        //DATE
        // 'Thu, 30 Oct 2008 02:52:47 GMT'
        // Monday, 12-Jan-98 09:25:56 GMT
        // Value: HTTP-date  ; defined in section 3.3.1 of RFC2068
        
        if ([_xmlChars length]) {
            NSDate *d = [[self class] parseDateString:_xmlChars];
            
            if (d) {
                //FildeDto Date
                _currentFile.date = [d timeIntervalSince1970];
                NSInteger colIdx = [elementName rangeOfString:@":"].location;
                [_xmlBucket setObject:d forKey:[elementName substringFromIndex:colIdx + 1]];
            }
            
            else {
                NSLog(@"Could not parse date string '%@' for '%@'", _xmlChars, elementName);
            }
        }
        
    } else if ([elementName isEqualToString:@"oc:id"]) {
        _currentFile.ocId = _xmlChars;
        
    } else if ([elementName hasSuffix:@":getetag"] && [_xmlChars length]) {
        //ETAG
        NSLog(@"getetag: %@", _xmlChars);
        
        NSString *stringClean = _xmlChars;
        stringClean = [_xmlChars stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        
        _currentFile.etag = [stringClean lowercaseString];
        
    } else if ([elementName hasSuffix:@":getcontenttype"] && [_xmlChars length]) {
        //CONTENT TYPE
        [_xmlBucket setObject:[_xmlChars copy] forKey:OCCWebDAVContentTypeKey];
        
    } else if([elementName hasSuffix:@"d:getcontentlength"] && [_xmlChars length]) {
        //SIZE
        //FileDto current size
        _currentFile.size = (long)[_xmlChars longLongValue];
        
    } else if ([elementName isEqualToString:@"oc:permissions"]) {
        _currentFile.permissions = _xmlChars;
        
    } else if ([elementName isEqualToString:@"d:collection"]) {
        _currentFile.isDirectory = YES;
        
    } else if ([elementName isEqualToString:@"d:response"]) {
        //NSLog(@"2 _xmlBucked :- %@",_xmlBucket);
        
        //Add to directoryList
        [_directoryList addObject:_currentFile];
        _currentFile = [[OCFileDto alloc] init];

        _xmlBucket = nil;
    } else if ([elementName isEqualToString:@"d:quota-used-bytes"]) {
        _currentFile.quotaUsed = (double)[_xmlChars doubleValue];
    } else if ([elementName isEqualToString:@"d:quota-available-bytes"]) {
        _currentFile.quotaAvailable = (double)[_xmlChars doubleValue];
    } else if ([elementName isEqualToString:@"oc:favorite"]) {
        _currentFile.isFavorite = [_xmlChars boolValue];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [_xmlChars appendString:string];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser{
    
    NSLog(@"Finish xml directory list parse");
}

// Decode a percent escape encoded string.
- (NSString*) decodeFromPercentEscapeString:(NSString *) string {
    return (__bridge NSString *) CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,
                                                                                         (__bridge CFStringRef) string,
                                                                                         CFSTR(""),
                                                                                         kCFStringEncodingUTF8);
}



@end
