//
//  OCXMLServerErrorsParser.m
//  ownCloud iOS library
//
//  Created by Gonzalo González on 1/6/15.
//

// Copyright (C) 2016, ownCloud GmbH.  ( http://www.owncloud.org/ )
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

#import "OCXMLServerErrorsParser.h"
#import "UtilsFramework.h"
#import "OCErrorMsg.h"

#define k_excepcion_element @"s:exception"
#define k_message_element @"s:message"

#define k_forbidden_character_error @"InvalidPath"

NSString *OCErrorException = @"oc_exception";
NSString *OCErrorMessage = @"oc_message";


@implementation OCXMLServerErrorsParser


- (void) startToParseWithData:(NSData *)data withCompleteBlock: (void(^)(NSError *error)) completeBlock{
    
    self.finishBlock = ^(NSError *err) {
        
        completeBlock(err);
    };
    
    if (!data) {
        NSError *error = nil;
        
        self.finishBlock(error);
    }else{
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
        [parser setDelegate:self];
        [parser parse];
        
        if (self.resultDict.count == 0) {
            NSError *error = nil;
            self.finishBlock(error);
        }
    }
    
    
}


#pragma mark - XML Parser Delegate Methods

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    
    if (!self.xmlString) {
        self.xmlString = [NSMutableString string];
    }
    
  //  NSLog(@"xml String: %@", self.xmlString);
    
    if (!self.resultDict) {
        self.resultDict = [NSMutableDictionary dictionary];
    }
    
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
  //  NSLog(@"elementName: %@:%@", elementName,self.xmlString);
    
    if ([elementName isEqualToString:k_excepcion_element]) {
        
        if (self.xmlString) {
            //Get the lastObject where is the exception name
            NSArray *splitedUrl = [self.xmlString componentsSeparatedByString:@"\\"];
            [self.resultDict setObject:[splitedUrl lastObject] forKey:OCErrorException];
        }
    }
    
    if ([elementName isEqualToString:k_message_element]) {
        
        if (self.xmlString) {
            [self.resultDict setObject:self.xmlString forKey:OCErrorMessage];
        }
    }
    
   
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    self.xmlString = string;
}

- (void)parserDidEndDocument:(NSXMLParser *)parser{
    
  //  NSLog(@"Finish: %@", self.resultDict);
    
    [self checkTheResultLookingForErrors];

}

//Method that check the ressult in order to find server errors

- (void) checkTheResultLookingForErrors{
    
    NSError *error = nil;
    
    if ([[self.resultDict objectForKey:OCErrorException] isEqualToString:k_forbidden_character_error]) {
        error = [UtilsFramework getErrorByCodeId:OCServerErrorForbiddenCharacters];
    }
    
    self.finishBlock(error);
    
}


@end
