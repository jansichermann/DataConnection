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

extern NSString * const HTTPMethodPost;
extern NSString * const HTTPMethodGet;
extern NSString * const HTTPMethodDelete;


typedef NSArray *(^ParseBlock)(id dataObject);
typedef id (^DataBlock)(NSData *d);
typedef void(^CompletionBlock)(id c);
typedef void(^ProgressBlock)(float progress);


/**
 DataConnection
 
 A subclass of NSURLConnection providing block based interfaces for making requests.
 */
@interface DataConnection : NSURLConnection <NSURLConnectionDataDelegate, NSURLConnectionDelegate>

/**
 The raw Data received by the connection.
 This is the instance to which data is appended by connectionDidReceiveData:
 */
@property (nonatomic, readonly) NSMutableData   *connectionData;

/**
 An NSString representation of the URL
 */
@property (nonatomic, readonly) NSString        *urlString;

/**-----
 * @name Data Block
 *------
 */

/**
 The dataBlock is executed, in which case dataObject gets set by
 The dataBlock's return value.
 If no dataBlock is set, we try to serialize the data as json
 */
@property (copy)                DataBlock       dataBlock;
@property (atomic, readonly)    id              dataObject;

/**-----
 * @name Parse Block
 *------
 */

/**
 Parse block is executed in which case resultObjects gets set by the parseBlock's return value
 */
@property (copy)                ParseBlock      parseBlock;
@property (atomic, readonly)    NSArray         *resultObjects;

/**-----
 * @name Completion Block
 *------
 */

/**
 The completion block is executed at the very end on the main thread
 @param The block is passed a connection. For subclassing compatability it is defined as an id.
 */
@property (copy)                CompletionBlock completionBlock;


/**-----
 * @name Progress Block
 *------
 */

/**
 The progress block is called for every progress invocation on uploading data
 */
@property (copy)                ProgressBlock   progressBlock;


/**-----
 * @name Status
 *------
 */
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

/**
 Both cancels the connection, and clears all blocks.
 This should be called if the connection is no longer relevant (e.g. when a View Controller that issued the request has reached the end of its lifecycle
 */
- (void)cancelAndClear;

/**
 An NSString representation of the response. This should be called only after a connection has finished. The behavior of this function at any other point in time is undefined.
 */
- (NSString *)responseString;

/**
 @return Whether the connection is a POST connection
 */
- (BOOL)isPostConnection;

/**
 Cleanup will be called automatically after the connection has successfully completed, or when cancelOrClear was called.
 This is exposed only to be overridden by a subclass (with a call to super), which may want to do additional things on cleanup (i.e. unset a global activity indicator, such as the network indicator).
 This method should never be called directly. 
 */
- (void)cleanup;

/**
 @param string The String to be encoded
 @return A url Encoded NSString representation
 */
+ (NSString *)urlEncodedString:(NSString *)string;

@end


/**
 An Object only has to conform to PostableData if it is passed into DataConnection
 as part of an NSDictionary.
 
 If you pass data to one of the data constructors, you need not worry about the object conforming to this.
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
