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

@interface DataConnectionTest ()

@property DataConnection *dc;
@end

@implementation DataConnectionTest

static NSString * const hostBase = @"http://localhost";

- (void)testFailingConnection {
    __block BOOL finished = NO;
    self.dc = [DataConnection withURLString:@"zxcvasdfqwer"];
    self.dc.completionBlock = ^(DataConnection *c) {
        finished = YES;
    };
    [self.dc start];
    
    NSRunLoop *rl = [NSRunLoop currentRunLoop];
    while (!finished && [rl runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
    
    STAssertTrue(self.dc.didFinish && !self.dc.didSucceed && finished, @"connection status set incorrectly");
}

- (void)testMultipartData {
    __block BOOL finished = NO;
    NSDictionary *params =
    @{@"fieldId" : @"123",
    @"text" : @"hello world",
    @"name" : @"give me a name"
    };
    
    self.dc = [DataConnection postConnectionWithUrlString:hostBase andParams:params];
    self.dc.completionBlock = ^(DataConnection *c) {
        NSLog(@"%@", [[NSString alloc] initWithData:c.connectionData encoding:NSUTF8StringEncoding]);
        finished = YES;
    };
    [self.dc start];
    
    NSRunLoop *rl = [NSRunLoop currentRunLoop];
    while (!finished && [rl runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
    
}
@end
