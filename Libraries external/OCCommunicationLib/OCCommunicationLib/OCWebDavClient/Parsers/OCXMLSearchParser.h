

#import <Foundation/Foundation.h>
#import "OCFileDto.h"


@interface OCXMLSearchParser : NSObject <NSXMLParserDelegate>{
    
    NSMutableString *_xmlChars;
    NSMutableDictionary *_xmlBucket;
    NSMutableArray *_searchList;
    OCFileDto *_currentFile;
    BOOL isNotFirstFileOfList;
    
}

@property(nonatomic,strong) NSMutableArray *searchList;
@property(nonatomic,strong) OCFileDto *currentFile;

- (void)initParserWithData: (NSData*)data;

@end
