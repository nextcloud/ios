

#import <Foundation/Foundation.h>
#import "OCFileDto.h"


@interface OCXMLSearchParser : NSObject <NSXMLParserDelegate>{
    
    NSMutableString *_xmlChars;
    NSMutableDictionary *_xmlBucket;
    NSMutableArray *_directoryList;
    OCFileDto *_currentFile;
    BOOL isNotFirstFileOfList;
    
}

@property(nonatomic,strong) NSMutableArray *directoryList;
@property(nonatomic,strong) OCFileDto *currentFile;

- (void)initParserWithData: (NSData*)data;

@end
