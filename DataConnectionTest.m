//
//  DataConnection.m
//
//  Created by Jan Sichermann on 1/11/13.
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


#import "DataConnectionTest.h"
#import "DataConnection.h"

@interface DataConnection()

+ (NSData *)multipartDataForParams:(NSDictionary *)params;

+ (void)addObjectData:(NSData *)objectData
               toData:(NSMutableData *)data
  withContentTypeData:(NSData *)contentTypeData
  andContentDispoData:(NSData *)contentDispoData;

@property (nonatomic, readwrite) NSMutableData *connectionData;

@end



@interface DataConnectionTest ()

@property DataConnection *dc;

@end



@implementation DataConnectionTest

static NSString * const hostBase = @"http://localhost";

- (void)testMultipartDataForParams {
    NSData *conData = [DataConnection multipartDataForParams:@{@"hello": @"world", @"foo" : @"bar"}];
    NSString *string = [[NSString alloc] initWithData:conData encoding:NSUTF8StringEncoding];
    
    NSString *expectedString = @"--Data-Boundary-aWeGhdCVFFfsdrf\r\nContent-Disposition: form-data; name=\"foo\"\r\n\r\nbar\r\n--Data-Boundary-aWeGhdCVFFfsdrf\r\nContent-Disposition: form-data; name=\"hello\"\r\n\r\nworld\r\n--Data-Boundary-aWeGhdCVFFfsdrf--\r\n\r\n--Data-Boundary-aWeGhdCVFFfsdrf--";
    
    STAssertEqualObjects(string, expectedString, @"expected strings to match");
}

- (void)testMultipartDataForParamsArray {
    NSData *conData = [DataConnection multipartDataForParams:@{@"hello" : @"word", @"foo" : @[@"bar", @"baz"]}];
    NSString *string = [[NSString alloc] initWithData:conData encoding:NSUTF8StringEncoding];
    
    NSString *expectedString = @"--Data-Boundary-aWeGhdCVFFfsdrf\r\nContent-Disposition: form-data; name=\"foo\"\r\n\r\nbar\r\n--Data-Boundary-aWeGhdCVFFfsdrf\r\nContent-Disposition: form-data; name=\"foo\"\r\n\r\nbaz\r\n--Data-Boundary-aWeGhdCVFFfsdrf\r\nContent-Disposition: form-data; name=\"hello\"\r\n\r\nword\r\n--Data-Boundary-aWeGhdCVFFfsdrf--\r\n\r\n--Data-Boundary-aWeGhdCVFFfsdrf--";
    
    STAssertEqualObjects(string, expectedString, @"expected strings to match");
}

- (void)testRequestWithUrlString {
    NSString *urlString = @"http://www.google.com";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    STAssertEqualObjects([DataConnection requestWithUrlString:urlString], request, @"expected requests to be the same");
}

- (void)testAddObjectToData {
    NSString *string = @"hello world";
    NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *mutableData = [NSMutableData data];
    [DataConnection addObjectData:stringData toData:mutableData withContentTypeData:nil andContentDispoData:nil];
}

- (void)testDidFail {
    DataConnection *dc = [DataConnection withURLString:@"http://google.com"];
    __block int testint = 0;
    
    dc.completionBlock = ^(DataConnection *c) {
        testint = 1;
    };
    
    [dc connection:dc didFailWithError:nil];
    STAssertEquals(testint, 1, @"Expected completion block to be executed");
    
    STAssertTrue(dc.didFinish, @"Expected connection to be finished");
    STAssertFalse(dc.didSucceed, @"Expected connection to not have succeeded");
    STAssertFalse(dc.inProgress, @"Expected connection to no longer be in progress");
}

- (void)testDidFinishLoading {
    DataConnection *dc = [DataConnection withURLString:@"http://google.com"];
    NSString *testString = [NSString stringWithFormat:@"Hello World"];
    dc.connectionData = [NSMutableData dataWithData:[testString dataUsingEncoding:NSUTF8StringEncoding]];
    
    __block BOOL done = NO;
    dc.dataBlock = ^id(NSData *d) {
        NSString *string = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        return string;
    };
    dc.completionBlock = ^(DataConnection *c) {
        STAssertEqualObjects(c.dataObject, testString, @"Expected objects to match");
        done = YES;
    };
    
    [dc connectionDidFinishLoading:dc];
    
    // We do this to prevent the process from quitting before the blocks are executed
    NSRunLoop *rl = [NSRunLoop currentRunLoop];
    while (!done && [rl runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);


    STAssertTrue(dc.didFinish, @"Expected connection to be finished");
    STAssertTrue(dc.didSucceed, @"Expected connection to not have succeeded");
    STAssertFalse(dc.inProgress, @"Expected connection to no longer be in progress");
}

@end
