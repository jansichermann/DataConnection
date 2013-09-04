//
//  DataConnection.m
//
//  Created by Jan Sichermann on 01/05/13.
//  Copyright (c) 2013 Jan Sichermann. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "DataConnection.h"
#import "DataConnectionMacros.h"



NSString * const MimeTypeImage = @"image/jpeg";
NSString * const MimeTypeJson = @"application/json";
NSString * const MimeTypeForm = @"application/x-www-form-urlencoded";
NSString * const MimeTypeFormData = @"multipart/form-data; boundary=";

static NSString * const BoundaryString = @"Data-Boundary-aWeGhdCVFFfsdrf";

NSString * const HTTPMethodPost = @"POST";
NSString * const HTTPMethodGet = @"GET";
NSString * const HTTPMethodDelete = @"DELETE";



@interface DataConnection ()

@property (atomic, readwrite)       BOOL            unauthorized;
@property (nonatomic, readwrite)    NSString        *urlString;
@property (nonatomic, readwrite)    NSMutableData   *connectionData;
@property (atomic, readwrite)       NSArray         *resultObjects;
@property (atomic, readwrite)       id              dataObject;

@property (readwrite)               BOOL            didSucceed;
@property (readwrite)               BOOL            didFinish;
@property (readwrite)               BOOL            didExecuteCompletion;
@property (readwrite)               int             httpResponseCode;
@property (readwrite)               NSError         *error;
@property (readwrite)               BOOL            inProgress;

@end



@implementation DataConnection

- (void)start {
    // schedule in commonModes runloop in order for the connection to execute even when the ui is responding to touches or doing a scroll
    [self scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    self.didFinish = NO;
    self.didSucceed = NO;
    self.httpResponseCode = -1;
    self.inProgress = YES;
    self.didExecuteCompletion = NO;
    [super start];
}

+ (NSMutableURLRequest *)requestWithUrlString:(NSString *)urlString {
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
}

- (NSURLRequest *)requestForMutableUrlRequest:(NSMutableURLRequest *)request {
    return request.copy;
}

- (DataConnection *)initWithRequest:(NSURLRequest *)request {
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        request = [self requestForMutableUrlRequest:(NSMutableURLRequest *)request];
    }
    self = [super initWithRequest:request
                         delegate:self
                 startImmediately:NO];
    if (self) {
        self.connectionData = [NSMutableData data];
    }
    return self;
}

+ (DataConnection *)withURLString:(NSString *)urlString {
    NSMutableURLRequest *mr = [self requestWithUrlString:urlString];
    mr.HTTPShouldUsePipelining = YES;
    mr.cachePolicy = NSURLRequestReturnCacheDataElseLoad;
    DataConnection *c = [self withRequest:mr];
    c.urlString = urlString;
    return c;
}


+ (void)addObjectData:(NSData *)objectData
               toData:(NSMutableData *)data
  withContentTypeData:(NSData *)contentTypeData
  andContentDispoData:(NSData *)contentDispoData {
  
    if (objectData) {
        [data appendData:[self boundaryPrefix]];
        [data appendData:[self separatorData]];
        [data appendData:contentDispoData];
        [data appendData:[self separatorData]];
        
        if (contentTypeData) {
            [data appendData:contentTypeData];
            [data appendData:[self separatorData]];
            
            NSData *contentLengthData = [[NSString stringWithFormat:@"Content-Length: %d", objectData.length] dataUsingEncoding:NSUTF8StringEncoding];
            [data appendData:contentLengthData];
            [data appendData:[self separatorData]];
            
            NSData *contentTransferEncodingData = [@"Content-Transfer-Encoding: binary" dataUsingEncoding:NSUTF8StringEncoding];
            [data appendData:contentTransferEncodingData];
            [data appendData:[self separatorData]];
        }
        
        [data appendData:[self separatorData]];
        [data appendData:objectData];
        [data appendData:[self separatorData]];
    }
}

+ (void)addKey:(NSString *)key andVal:(id)val toData:(NSMutableData *)data {
    if (![key isKindOfClass:[NSString class]]) return;
    
    if (![val isKindOfClass:[NSString class]] &&
        ![val conformsToProtocol:@protocol(PostableData)] &&
        ![val isKindOfClass:[NSNumber class]]) {
        NSLog(@"value for key %@ is of an unexpected type, skipping!", key);
        return;
    }
    
    NSData *contentDispoData = nil;
    NSData *contentTypeData = nil;
    NSData *objectData = nil;
    
    NSString *contentDispoString = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"", key];
    
    if ([val isKindOfClass:[NSString class]]) {
        objectData = [val dataUsingEncoding:NSUTF8StringEncoding];
    }
    else if ([val conformsToProtocol:@protocol(PostableData)]) {
        
        id<PostableData> postableData = val;
        
        objectData = postableData.data;
        
        if (objectData == nil) return;
        
        contentDispoString = [contentDispoString stringByAppendingFormat:@"; filename=\"%@\"", postableData.fileName]; // some filename
        contentTypeData = [[NSString stringWithFormat:@"Content-Type: %@",postableData.mimeType] dataUsingEncoding:NSUTF8StringEncoding];
    }
    else if ([val isKindOfClass:[NSNumber class]]) {
        objectData = [[val description] dataUsingEncoding:NSUTF8StringEncoding];
    }
    else {
        NSAssert(NO, @"This should never happen!");
    }
    
    contentDispoData = [contentDispoString dataUsingEncoding:NSUTF8StringEncoding];
    
    [self addObjectData:objectData toData:data withContentTypeData:contentTypeData andContentDispoData:contentDispoData];
}

+ (NSData *)boundaryPrefix {
    return [[NSString stringWithFormat:@"--%@", BoundaryString] dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)separatorData {
    return [@"\r\n" dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)multipartDataForParams:(NSDictionary *)params {
    NSMutableData *data = [NSMutableData data];
    
    for (NSString *key in params.allKeys) {
        // deal with single objects, or lists if appropriate
        if ([params[key] isKindOfClass:[NSArray class]]) {
            for (id val in params[key]) {
                [self addKey:key andVal:val toData:data];
            }
        }
        else {
            [self addKey:key andVal:params[key] toData:data];
        }
    }
    
    NSData *boundaryPost = [[NSString stringWithFormat:@"--%@--", BoundaryString] dataUsingEncoding:NSUTF8StringEncoding];
    [data appendData:boundaryPost];
    [data appendData:[self separatorData]];
    [data appendData:[self separatorData]];
    [data appendData:boundaryPost];
    
    return data;
}

+ (NSData *)urlEncodedDataForParams:(NSDictionary *)params {
    NSString *paramString = nil;
    for (id key in params.allKeys) {
        if (![key isKindOfClass:[NSString class]]) {
            continue;
        }
        if (![[params objectForKey:key] isKindOfClass:[NSString class]]) {
            continue;
        }
        
        NSString *val = (NSString *)[params objectForKey:key];
        
        if (paramString == nil) {
            paramString = key;
        }
        else {
            paramString = [paramString stringByAppendingFormat:@"&%@", key];
        }
        paramString = [paramString stringByAppendingFormat:@"=%@", [self urlEncodedString:val]];
    }
    return [paramString dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)postBodyWithParameters:(NSDictionary *)params {
    if ([[self mimeTypeForParams:params] isEqualToString:MimeTypeFormData]) {
        return [self multipartDataForParams:params];
    }
    else {
        return [self urlEncodedDataForParams:params];
    }
}

+ (DataConnection *)postConnectionWithUrlString:(NSString *)urlString andData:(NSData *)data andMimeType:(NSString *)mimeType {
    NSMutableURLRequest *urlRequest = [self requestWithUrlString:urlString];
    [urlRequest setHTTPMethod:HTTPMethodPost];
    NSString *contentLength = [NSString stringWithFormat:@"%d", data.length];
    [urlRequest setValue:mimeType forHTTPHeaderField:@"Content-Type"];
    [urlRequest setValue:contentLength forHTTPHeaderField:@"Content-Length"];
    [urlRequest setHTTPBody:data];
    DataConnection *c = [[self alloc] initWithRequest:urlRequest];
    c.urlString = urlString;
    return c;
}

+ (DataConnection *)deleteConnectionWithUrlString:(NSString *)urlString {
    NSMutableURLRequest *urlRequest = [self requestWithUrlString:urlString];
    [urlRequest setHTTPMethod:HTTPMethodDelete];
    DataConnection *c = [[self alloc] initWithRequest:urlRequest];
    c.urlString = urlString;
    return c;
}

+ (NSString *)mimeTypeForParams:(NSDictionary *)params {
    for (id val in params.allValues) {
        if (![val isKindOfClass:[NSString class]])
            return MimeTypeFormData;
    }
    return MimeTypeForm;
}

#pragma clang diagnostic ignored "-Wunused-parameter"
+ (NSString *)contentTypeForParams:(NSDictionary *)params {
    return [NSString stringWithFormat:@"%@%@", MimeTypeFormData, BoundaryString];
}

+ (DataConnection *)postMultipartConnectionWithUrlString:(NSString *)urlString andParams:(NSDictionary *)params {
    NSMutableURLRequest *urlRequest = [self requestWithUrlString:urlString];
    [urlRequest setHTTPMethod:HTTPMethodPost];
    NSData *dataForParams = [self multipartDataForParams:params];
    
    NSString *mimeType = MimeTypeFormData;
    [urlRequest setValue:[mimeType stringByAppendingString:BoundaryString] forHTTPHeaderField:@"Content-Type"];
    
    [urlRequest setValue:[NSString stringWithFormat:@"%d", dataForParams.length] forHTTPHeaderField:@"Content-Length"];
    [urlRequest setHTTPBody:dataForParams];
    
    DataConnection *c = [[self alloc] initWithRequest:urlRequest];
    c.urlString = urlString;
    return c;
}

+ (DataConnection *)postConnectionWithUrlString:(NSString *)urlString andParams:(NSDictionary *)params {
    
    NSMutableURLRequest *urlRequest = [self requestWithUrlString:urlString];
    [urlRequest setHTTPMethod:HTTPMethodPost];
    
    NSData *dataForParams = [self postBodyWithParameters:params];
    
    NSString *mimeType = [self mimeTypeForParams:params];
    if ([mimeType isEqualToString:MimeTypeFormData]) {
        [urlRequest setValue:[mimeType stringByAppendingString:BoundaryString] forHTTPHeaderField:@"Content-Type"];
    }
    else {
        [urlRequest setValue:mimeType forHTTPHeaderField:@"Content-Type"];
    }
    
    
    [urlRequest setValue:[NSString stringWithFormat:@"%d", dataForParams.length] forHTTPHeaderField:@"Content-Length"];
    [urlRequest setHTTPBody:dataForParams];
    
    DataConnection *c = [[self alloc] initWithRequest:urlRequest];
    c.urlString = urlString;
    return c;
}

+ (DataConnection *)withRequest:(NSURLRequest *)request {
    return [[self alloc] initWithRequest:request];
}

- (id)init {
    NON_DESIGNATED_INITIALIZER
    return nil;
}

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    NON_DESIGNATED_INITIALIZER
    return nil;
}

+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    NON_DESIGNATED_INITIALIZER
    return nil;
}

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)startImmediately {
    NON_DESIGNATED_INITIALIZER
    return nil;
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error {
    self.inProgress = NO;
    self.error = error;
    self.didSucceed = NO;
    self.didFinish = YES;
    [self executeCompletion];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.inProgress = NO;
    self.didSucceed = YES;
    self.didFinish = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self executeData];
    });
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    if (self.progressBlock) {
        self.progressBlock(totalBytesWritten / (float)totalBytesExpectedToWrite);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    self.httpResponseCode = [httpResponse statusCode];
    [self.connectionData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.connectionData appendData:data];
    
}

+ (NSString *)urlEncodedString:(NSString *)string {
    NSMutableString *urlEncodedString = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[string UTF8String];
    unsigned int sourceLen = strlen((const char *)source);
    
    for (unsigned int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [urlEncodedString appendString:@"\%20"];
        }
        else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [urlEncodedString appendFormat:@"%c", thisChar];
        }
        else {
            [urlEncodedString appendFormat:@"%%%02X", thisChar];
        }
    }
    
    return urlEncodedString;
}

- (void)executeData {
    NSAssert(![NSThread isMainThread], @"Expected data function to be called on Background Thread");

    if (self.dataBlock) {
        self.dataObject = self.dataBlock(self.connectionData);
    }
    else {
        self.dataObject = [NSJSONSerialization JSONObjectWithData:self.connectionData options:0 error:nil];
    }
    
    // if the parse block is set, we then execute the parse block
    if (self.parseBlock) {
        [self executeParse];
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self executeCompletion];
        });
    }
}

- (void)executeParse {
    NSAssert(![NSThread isMainThread], @"Expected parse function to be called on Background Thread");
    
    self.resultObjects = self.parseBlock(self.dataObject);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self executeCompletion];
    });
}

- (void)executeCompletion {
    if (![NSThread isMainThread]) {
        [NSException raise:@"must be main thread" format:@"completion block must be performed on main thread"];
    }
    if (self.completionBlock) {
        self.completionBlock(self);
    }
    self.didExecuteCompletion = YES;
    [self cleanup];
}

- (void)cancelAndClear {
    [self cancel];
    [self cleanup];
}

- (void)cancel {
    self.inProgress = NO;
    self.didSucceed = NO;
    self.didFinish = NO;
}

- (void)cleanup {
    self.dataBlock = nil;
    self.dataObject = nil;
    
    self.parseBlock = nil;
    
    self.completionBlock = nil;
}

- (NSString *)responseString {
    return [[NSString alloc] initWithData:self.connectionData encoding:NSUTF8StringEncoding];
}

- (BOOL)isPostConnection {
    return [self.currentRequest.HTTPMethod isEqualToString:HTTPMethodPost];
}

- (BOOL)isGetConnection {
    return [self.currentRequest.HTTPMethod isEqualToString:HTTPMethodGet];
}
@end
