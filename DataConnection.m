//
//  DataConnection.m
//
//  Created by Jan Sichermann on 01/05/13.
//  Copyright (c) 2013 online in4mation GmbH. All rights reserved.
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

@interface DataConnection ()
@property (atomic, readwrite)       BOOL            unauthorized;
@property (nonatomic, readwrite)    NSString        *urlString;
@property (nonatomic, readwrite)    NSMutableData   *connectionData;
@property (atomic, readwrite)       NSArray         *resultObjects;
@property (atomic, readwrite)       id              dataObject;
@end


@implementation DataConnection

- (void)start {
    // schedule in commonModes runloop in order for the connection to execute even when the ui is responding to touches or doing a scroll
    [self scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [super start];
}

- (DataConnection *)initWithRequest:(NSURLRequest *)request {
    self = [super initWithRequest:request delegate:self startImmediately:NO];
    if (self) {
        self.connectionData = [NSMutableData data];
    }
    return self;
}

+ (DataConnection *)withURLString:(NSString *)urlString {
    NSMutableURLRequest *mr = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    mr.HTTPShouldUsePipelining = YES;
    mr.cachePolicy = NSURLRequestReturnCacheDataElseLoad;
    DataConnection *c = [self withRequest:mr];
    c.urlString = urlString;
    return c;
}

+ (DataConnection *)withRequest:(NSURLRequest *)request {
    return [[self alloc] initWithRequest:request];
}

- (id)init {
    [NSException raise:@"non-designated initializer" format:@"use initWithRequest:"];
    return nil;
}

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    [NSException raise:@"non-designated initializer" format:@"use initWithRequest:"];
    return nil;
}

+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    [NSException raise:@"non-designated initializer" format:@"use initWithRequest:"];
    return nil;
}

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)startImmediately {
    [NSException raise:@"non-designated initializer" format:@"use initWithRequest:"];
    return nil;
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (self.dataBlock != nil) {
        [self performSelectorInBackground:@selector(executeData) withObject:nil];
    }
    else if (self.parseBlock != nil) {
        [self performSelectorInBackground:@selector(executeParse) withObject:nil];
    }
    else {
        [self executeCompletion];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.connectionData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.connectionData appendData:data];
    
}

- (void)executeData {
    if ([NSThread isMainThread]) {
        [NSException raise:@"must be non-main thread" format:@"should parse on non-main thread"];
    }
    self.dataObject = self.dataBlock(self.connectionData);
    
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
    NSDictionary *serializedObject = [NSJSONSerialization JSONObjectWithData:self.connectionData options:0 error:nil];
    if (serializedObject != nil) {
        self.resultObjects = self.parseBlock(serializedObject);
    }
    [self performSelectorOnMainThread:@selector(executeCompletion) withObject:nil waitUntilDone:NO];
}

- (void)executeCompletion {
    if (![NSThread isMainThread]) {
        [NSException raise:@"must be main thread" format:@"completion block must be performed on main thread"];
    }
    if (self.completionBlock != nil) {
        self.completionBlock(self);
    }
}

- (void)cancelAndClear {
    [self cancel];
    self.dataBlock = nil;
    self.dataObject = nil;
    
    self.parseBlock = nil;
    self.resultObjects = nil;
    
    self.completionBlock = nil;
}

- (void)dealloc {
    NSLog(@"deallocing dataConnection");
}
@end
