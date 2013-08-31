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

#define NON_DESIGNATED_INITIALIZER \
NSException *e = [NSException exceptionWithName:@"Non-Designated initializer" reason:[NSString stringWithFormat:@"%@ is a non-designated initializer", NSStringFromSelector(_cmd)] userInfo:nil]; \
[e raise];
