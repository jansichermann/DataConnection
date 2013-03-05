//
//  DataConnection.h
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

#import <Foundation/Foundation.h>



@class DataConnection;



extern NSString * const MimeTypeImage;
extern NSString * const MimeTypeJson;
extern NSString * const MimeTypeForm;
extern NSString * const MimeTypeFormData;
extern NSString * const BoundaryString;



typedef NSArray *(^ParseBlock)(id dataObject);
typedef id (^DataBlock)(NSData *d);
typedef void(^CompletionBlock)(id c);       // c is the connection, we use id for subclassing compatability
typedef void(^ProgressBlock)(float progress);



@interface DataConnection : NSURLConnection <NSURLConnectionDataDelegate, NSURLConnectionDelegate>

@property (nonatomic, readonly) NSMutableData   *connectionData;
@property (nonatomic, readonly) NSString        *urlString;

// the dataBlock is executed, in which case dataObject gets set by
// the dataBlock's return value.
// if no dataBlock is set, we try to serialize the data
@property (copy)                DataBlock       dataBlock;
@property (atomic, readonly)    id              dataObject;

// parse block is executed in which case resultObjects gets set by the parseBlock's returnValue
@property (copy)                ParseBlock      parseBlock;
@property (atomic, readonly)    NSArray         *resultObjects;

// the completion block is executed at the very end
@property (copy)                CompletionBlock completionBlock;

// the progress block is called for every progress invocation
@property (copy)                ProgressBlock   progressBlock;


// status
@property (readonly)            BOOL            didSucceed;
@property (readonly)            BOOL            didFinish;
@property (readonly)            int             httpResponseCode;
@property (readonly)            NSError         *error;
@property (readonly)            BOOL            inProgress;

+ (NSMutableURLRequest *)requestWithUrlString:(NSString *)urlString;
+ (id)withURLString:(NSString *)urlString;
+ (id)postConnectionWithUrlString:(NSString *)urlString andData:(NSData *)data andMimeType:(NSString *)mimeType;
+ (id)postConnectionWithUrlString:(NSString *)urlString andImageData:(NSData *)data;
+ (id)postConnectionWithUrlString:(NSString *)urlString andParams:(NSDictionary *)params;
+ (id)postMultipartConnectionWithUrlString:(NSString *)urlString andParams:(NSDictionary *)params;
    
- (void)cancelAndClear;

- (NSString *)responseString;

- (BOOL)isPostConnection;

- (void)cleanup;

+ (NSString *)urlEncodedString:(NSString *)string;
@end


@protocol PostableData <NSObject>
- (NSString *)mimeType;
- (NSString *)fileName;
- (NSData *)data;

@end
