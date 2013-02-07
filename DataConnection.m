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

static NSString * const MimeTypeImage = @"image/jpeg";
static NSString * const MimeTypeJson = @"application/json";
static NSString * const MimeTypeForm = @"application/x-www-form-urlencoded";
static NSString * const MimeTypeFormData = @"multipart/form-data; boundary=";
static NSString * const BoundaryString = @"Data-Boundary-aWeGhdCVFFfsdrf";


@interface DataConnection ()
@property (atomic, readwrite)       BOOL            unauthorized;
@property (nonatomic, readwrite)    NSString        *urlString;
@property (nonatomic, readwrite)    NSMutableData   *connectionData;
@property (atomic, readwrite)       NSArray         *resultObjects;
@property (atomic, readwrite)       id              dataObject;

@property (readwrite)               BOOL            didSucceed;
@property (readwrite)               BOOL            didFinish;
@end


@implementation DataConnection

- (void)start {
    // schedule in commonModes runloop in order for the connection to execute even when the ui is responding to touches or doing a scroll
    [self scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    self.didFinish = NO;
    self.didSucceed = NO;
    self.httpResponseCode = -1;
    [super start];
}

+ (NSMutableURLRequest *)requestWithUrlString:(NSString *)urlString {
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
}

- (DataConnection *)initWithRequest:(NSURLRequest *)request {
    self = [super initWithRequest:request delegate:self startImmediately:NO];
    if (self) {
        self.connectionData = [NSMutableData data];
    }
    return self;
}

+ (DataConnection *)withURLString:(NSString *)urlString {
    NSMutableURLRequest *mr = [self requestWithUrlString:urlString];
    mr.timeoutInterval = 20.f;
    mr.HTTPShouldUsePipelining = YES;
    mr.cachePolicy = NSURLRequestReturnCacheDataElseLoad;
    DataConnection *c = [self withRequest:mr];
    c.urlString = urlString;
    return c;
}

+ (NSData *)multipartDataForParams:(NSDictionary *)params {
    NSMutableData *data = [NSMutableData data];
    NSData *boundaryPrefix = [[NSString stringWithFormat:@"--%@", BoundaryString] dataUsingEncoding:NSUTF8StringEncoding];
    NSData *separatorData = [@"\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    
    for (NSString *key in params.allKeys) {
        if (![key isKindOfClass:[NSString class]]) continue;
        id val = params[key];
        
        if (![val isKindOfClass:[NSString class]] &&
            ![val conformsToProtocol:@protocol(PostableData)] &&
            ![val isKindOfClass:[NSNumber class]]) {
            NSLog(@"value for key %@ is of an unexpected type, skipping!", key);
            continue;
        }
        
        NSData *contentDispoData = nil;
        NSData *contentTypeData = nil;
        NSData *contentTransferEncodingData = nil;
        NSData *objectData = nil;
        
        NSString *contentDispoString = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"", key];
        
        if ([val isKindOfClass:[NSString class]]) {
            objectData = [val dataUsingEncoding:NSUTF8StringEncoding];
        }
        else if ([val conformsToProtocol:@protocol(PostableData)] &&
                 ([val isKindOfClass:[NSData class]] || [[val class] isSubclassOfClass:[NSData class]])
                 ) {
            
            NSData<PostableData> *postableData = val;
            
            objectData = postableData;
            
            contentDispoString = [contentDispoString stringByAppendingFormat:@"; filename=%@", postableData.fileName]; // some filename
            contentTypeData = [postableData.mimeType dataUsingEncoding:NSUTF8StringEncoding];
            contentTransferEncodingData = [@"binary" dataUsingEncoding:NSUTF8StringEncoding];
            
        }
        else if ([val isKindOfClass:[NSNumber class]]) {
            objectData = [[val description] dataUsingEncoding:NSUTF8StringEncoding];
        }
        else {
            NSAssert(NO, @"This should never happen!");
        }
        
        contentDispoData = [contentDispoString dataUsingEncoding:NSUTF8StringEncoding];
        
        // last sanity check
        if (objectData != nil) {
            [data appendData:boundaryPrefix];
            [data appendData:separatorData];
            [data appendData:contentDispoData];
            if (contentTypeData) {
                [data appendData:contentTypeData];
            }
            if (contentTransferEncodingData) {
                [data appendData:contentTransferEncodingData];
            }
            [data appendData:separatorData];
            [data appendData:separatorData];
            [data appendData:objectData];
            [data appendData:separatorData];
        }
    }
    
    NSData *boundaryPost = [[NSString stringWithFormat:@"--%@--", BoundaryString] dataUsingEncoding:NSUTF8StringEncoding];
    [data appendData:boundaryPost];
    [data appendData:separatorData];
    [data appendData:separatorData];
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
        paramString = [paramString stringByAppendingFormat:@"=%@", [val stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
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
    [urlRequest setHTTPMethod:@"POST"];
    NSString *contentLength = [NSString stringWithFormat:@"%d", data.length];
    [urlRequest setValue:mimeType forHTTPHeaderField:@"Content-Type"];
    [urlRequest setValue:contentLength forHTTPHeaderField:@"Content-Length"];
    [urlRequest setHTTPBody:data];
    DataConnection *c = [[self alloc] initWithRequest:urlRequest];
    c.urlString = urlString;
    return c;
}

+ (DataConnection *)postConnectionWithUrlString:(NSString *)urlString andImageData:(NSData *)data {
    NSMutableURLRequest *urlRequest = [self requestWithUrlString:urlString];
    [urlRequest setHTTPMethod:@"POST"];
    NSString *contentLength = [NSString stringWithFormat:@"%d", data.length];
    [urlRequest setValue:MimeTypeImage forHTTPHeaderField:@"Content-Type"];
    [urlRequest setValue:contentLength forHTTPHeaderField:@"Content-Length"];
    [urlRequest setHTTPBody:data];
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

+ (NSString *)contentTypeForParams:(NSDictionary *)params {
    return [NSString stringWithFormat:@"%@%@", MimeTypeFormData, BoundaryString];
}

+ (BOOL)requireMultipartForParameters:(NSDictionary *)parameters {
    return NO;
}

+ (DataConnection *)postMultipartConnectionWithUrlString:(NSString *)urlString andParams:(NSDictionary *)params {
    NSMutableURLRequest *urlRequest = [self requestWithUrlString:urlString];
    [urlRequest setHTTPMethod:@"POST"];
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
    [urlRequest setHTTPMethod:@"POST"];
    
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

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.didSucceed = NO;
    self.didFinish = YES;
    [self executeCompletion];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.didSucceed = YES;
    self.didFinish = YES;
    
    [self performSelectorInBackground:@selector(executeData) withObject:nil];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    self.httpResponseCode = [httpResponse statusCode];
    [self.connectionData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.connectionData appendData:data];
    
}

- (void)executeData {
    if ([NSThread isMainThread]) {
        [NSException raise:@"must be non-main thread" format:@"should parse on non-main thread"];
    }
    if (self.dataBlock != nil) {
        self.dataObject = self.dataBlock(self.connectionData);
    }
    else {
        self.dataObject = [NSJSONSerialization JSONObjectWithData:self.connectionData options:0 error:nil];
    }
    
    // if the parse block is set, we then execute the parse block
    if (self.parseBlock != nil) {
        [self executeParse];
    }
    else {
        [self performSelectorOnMainThread:@selector(executeCompletion) withObject:nil waitUntilDone:NO];
    }
}

- (void)executeParse {
    if ([NSThread isMainThread]) {
        [NSException raise:@"must be non-main thread" format:@"should parse on non-main thread"];
    }
    
    self.resultObjects = self.parseBlock(self.dataObject);
    
    [self performSelectorOnMainThread:@selector(executeCompletion) withObject:nil waitUntilDone:NO];
}

- (void)executeCompletion {
    if (![NSThread isMainThread]) {
        [NSException raise:@"must be main thread" format:@"completion block must be performed on main thread"];
    }
    if (self.completionBlock != nil) {
        self.completionBlock(self);
    }
    [self cleanup];
}

- (void)cancelAndClear {
    [self cancel];
    [self cleanup];
}

- (void)cleanup {
    self.dataBlock = nil;
    self.dataObject = nil;
    
    self.parseBlock = nil;
    self.resultObjects = nil;
    
    self.completionBlock = nil;
}

- (NSString *)responseString {
    return [[NSString alloc] initWithData:self.connectionData encoding:NSUTF8StringEncoding];
}

- (void)dealloc {
    NSLog(@"deallocing dataConnection");
}
@end
