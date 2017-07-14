

#import "OCXMLListParser.h"
#import "NSString+Encode.h"

@implementation OCXMLListParser

@synthesize searchList=_searchList;
@synthesize currentFile=_currentFile;

/*
 * Method that init the parse with the xml data from the server
 * @data -> XML webDav data from the owncloud server
 */
- (void)initParserWithData: (NSData*)data{
    
    _searchList = [NSMutableArray new];
    
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
            _currentFile = [OCFileDto new];
             _currentFile.isDirectory = NO;
            [_xmlBucket setObject:[_xmlChars copy] forKey:@"uri"];
            
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
        
        
            [_xmlBucket setObject:lastBit forKey:@"href"];
            _currentFile.fileName = lastBit;
            
            NSString *decodedFileName = [self decodeFromPercentEscapeString:self.currentFile.fileName];
            NSString *decodedFilePath = [self decodeFromPercentEscapeString:self.currentFile.filePath];
            
            self.currentFile.fileName = [decodedFileName encodeString:NSUTF8StringEncoding];
            self.currentFile.filePath = [decodedFilePath encodeString:NSUTF8StringEncoding];
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
        [_xmlBucket setObject:[_xmlChars copy] forKey:@"contenttype"];
        
    } else if([elementName hasSuffix:@"d:getcontentlength"] && [_xmlChars length]) {
        //SIZE
        //FileDto current size
        _currentFile.size = (long)[_xmlChars longLongValue];
        
    } else if ([elementName isEqualToString:@"oc:permissions"]) {
        _currentFile.permissions = _xmlChars;
        
    } else if ([elementName isEqualToString:@"d:collection"]) {
        _currentFile.isDirectory = YES;
        
    } else if ([elementName isEqualToString:@"d:response"]) {
        
        //Add to searchList
        [_searchList addObject:_currentFile];
        _currentFile = [OCFileDto new];

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
    return (__bridge_transfer NSString *) CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,
                                                                                         (__bridge CFStringRef) string,
                                                                                         CFSTR(""),
                                                                                         kCFStringEncodingUTF8);
}



@end
