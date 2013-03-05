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



typedef NSArray *(^ParseBlock)(id dataObject);
typedef id (^DataBlock)(NSData *d);
typedef void(^CompletionBlock)(id c);
typedef void(^ProgressBlock)(float progress);



@interface DataConnection : NSURLConnection <NSURLConnectionDataDelegate, NSURLConnectionDelegate>

@property (nonatomic, readonly) NSMutableData   *connectionData;
@property (nonatomic, readonly) NSString        *urlString;

/**-----
 * @name Data Block
 *------
 */

/**
 the dataBlock is executed, in which case dataObject gets set by
 the dataBlock's return value.
 if no dataBlock is set, we try to serialize the data as json
 */
@property (copy)                DataBlock       dataBlock;
@property (atomic, readonly)    id              dataObject;

/**-----
 * @name Parse Block
 *------
 */

/**
 parse block is executed in which case resultObjects gets set by the parseBlock's return value
 */
@property (copy)                ParseBlock      parseBlock;
@property (atomic, readonly)    NSArray         *resultObjects;

/**-----
 * @name Completion Block
 *------
 */

/**
 the completion block is executed at the very end on the main thread
 @param The block is passed a connection. For subclassing compatability it is defined as an id.
 */
@property (copy)                CompletionBlock completionBlock;


/**-----
 * @name Progress Block
 */

/**
 the progress block is called for every progress invocation on uploading data
 */
@property (copy)                ProgressBlock   progressBlock;


// status
@property (readonly)            BOOL            didSucceed;
@property (readonly)            BOOL            didFinish;
@property (readonly)            int             httpResponseCode;
@property (readonly)            NSError         *error;
@property (readonly)            BOOL            inProgress;

/**-----
 @name Initializers
 *------
 */
+ (NSMutableURLRequest *)requestWithUrlString:(NSString *)urlString;
+ (id)withURLString:(NSString *)urlString;
+ (id)postConnectionWithUrlString:(NSString *)urlString andData:(NSData *)data andMimeType:(NSString *)mimeType;

/**
 A POST request initializer. Depending on the params being passed in, this becomes either an x-www-form-urlencoded or a multipart/form-data form.
 @param params An NSDictionary with NSString keys mapping to either an NSString, an NSNumber or an object conforming to PostableData.
 @param urlString The Url String to which to post.
 */
+ (id)postConnectionWithUrlString:(NSString *)urlString andParams:(NSDictionary *)params;

/**
 A POST request initializer. This will, regardless of the types of object in params, create a multipart/form-data request.
 @param params An NSDictionary with NSString keys mapping to either an NSString, an NSNumber or an object conforming to PostableData.
 @param urlString The Url String to which to post.
 */
+ (id)postMultipartConnectionWithUrlString:(NSString *)urlString andParams:(NSDictionary *)params;
    
- (void)cancelAndClear;

- (NSString *)responseString;

- (BOOL)isPostConnection;

- (void)cleanup;

+ (NSString *)urlEncodedString:(NSString *)string;

@end


/**
 An Object only has to conform to PostableData if it is passed into DataConnection
 as part of an NSDictionary.
 */
@protocol PostableData <NSObject>

/**
 A Mime Type describing the data
 */
- (NSString *)mimeType;

/**
 A file name
 */
- (NSString *)fileName;

/**
 The Actual Data to be posted
 */
- (NSData *)data;

@end
