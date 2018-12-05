//
//  KTVHCHTTPURL.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCHTTPURL.h"
#import "KTVHCURLTools.h"
#import "KTVHCLog.h"

static NSString * const kKTVHCHTTPURLRequestURLKey      = @"originalURL";
static NSString * const kKTVHCHTTPURLRequestTypeKey     = @"requestType";
static NSString * const kKTVHCHTTPURLRequestTypeContent = @"content";
static NSString * const kKTVHCHTTPURLRequestTypePing    = @"ping";

@implementation KTVHCHTTPURL

+ (instancetype)pingURL
{
    static KTVHCHTTPURL * obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL * URL = [NSURL URLWithString:@"KTVHTTPCache"];
        obj = [[KTVHCHTTPURL alloc] initWithOriginalURL:URL];
        obj->_type = KTVHCHTTPURLTypePing;
    });
    return obj;
}

- (instancetype)initWithProxyURL:(NSURL *)URL
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        NSRange requestTypeRange = [URL.absoluteString rangeOfString:[NSString stringWithFormat:@"%@=", kKTVHCHTTPURLRequestTypeKey]];
        if (requestTypeRange.location != NSNotFound)
        {
            NSString * paramString = [URL.absoluteString substringFromIndex:requestTypeRange.location];
            NSCharacterSet * delimiterSet = [NSCharacterSet characterSetWithCharactersInString:@"&"];
            NSScanner * scanner = [[NSScanner alloc] initWithString:paramString];
            while (![scanner isAtEnd])
            {
                NSString * tupleString = nil;
                [scanner scanUpToCharactersFromSet:delimiterSet intoString:&tupleString];
                [scanner scanCharactersFromSet:delimiterSet intoString:NULL];
                NSArray <NSString *> * tuple = [tupleString componentsSeparatedByString:@"="];
                if (tuple.count == 2)
                {
                    NSString * key = tuple.firstObject;
                    NSString * value = tuple.lastObject;
                    if ([key isEqualToString:kKTVHCHTTPURLRequestURLKey])
                    {
                        _URL = [NSURL URLWithString:[KTVHCURLTools URLDecode:value]];
                    }
                    else if ([key isEqualToString:kKTVHCHTTPURLRequestTypeKey])
                    {
                        if ([value isEqualToString:kKTVHCHTTPURLRequestTypePing])
                        {
                            _type = KTVHCHTTPURLTypePing;
                        }
                        else if ([value isEqualToString:kKTVHCHTTPURLRequestTypeContent])
                        {
                            _type = KTVHCHTTPURLTypeContent;
                        }
                    }
                }
            }
        }
        KTVHCLogHTTPURL(@"%p, Proxy URL\n%@\n%@", self, URL, self.URL);
    }
    return self;
}

- (instancetype)initWithOriginalURL:(NSURL *)URL
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        _URL = URL;
        _type = KTVHCHTTPURLTypeContent;
        KTVHCLogHTTPURL(@"%p, Original URL\n%@", self, self.URL);
    }
    return self;
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
}

- (NSURL *)proxyURLWithPort:(NSInteger)port
{
    NSString * pathExtension = @"";
    if (self.URL.pathExtension.length > 0)
    {
        pathExtension = [NSString stringWithFormat:@".%@", self.URL.pathExtension];
    }
    NSString * requestType = kKTVHCHTTPURLRequestTypeContent;
    if (self.type == KTVHCHTTPURLTypePing)
    {
        requestType = kKTVHCHTTPURLRequestTypePing;
    }
    NSString * originalURLString = [KTVHCURLTools URLEncode:self.URL.absoluteString];
    NSString * URLString = [NSString stringWithFormat:@"http://localhost:%d/request%@?%@=%@&%@=%@",
                            (int)port,
                            pathExtension,
                            kKTVHCHTTPURLRequestTypeKey, requestType,
                            kKTVHCHTTPURLRequestURLKey, originalURLString];
    NSURL * URL = [NSURL URLWithString:URLString];
    KTVHCLogHTTPURL(@"%p, Proxy URL\n%@", self, URL);
    return URL;
}

@end
