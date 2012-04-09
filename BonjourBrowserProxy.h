//
//  BonjourBrowserProxy.h
//
//  Created by Gerard Escalante on 11-10-26.
//
//  Copyright 2011- SayGo Solutions Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>
#import <Foundation/NSNetServices.h>

#if !defined(__IPHONE_4_0) || (__IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_4_0)
//Prior to 4.0, All the delegate protocol didn't exist. Instead, the methods
//were a category on NSObject. So to make this compile for 3.x, we make an empty protocol.
@protocol NSNetServiceBrowserDelegate <NSObject>
@end

#endif

@interface BonjourBrowserProxy : CDVPlugin<NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
	NSNetServiceBrowser* browser;
	NSString* serviceType;
	NSString* domain;
	NSString* callbackID;
	
	NSMutableArray* serviceObjects;
	NSMutableArray* services;
	BOOL moreToCome;
	
	BOOL searching;
	NSString* error;
	NSCondition* searchCondition;
}

+(NSString*)stringForErrorCode:(NSNetServicesError)code;

-(void)search:(NSMutableArray*)arguments withDict:(NSMutableDictionary*) options;
-(void)stopSearch:(NSMutableArray*)arguments withDict:(NSMutableDictionary*) options;

@property(readonly, nonatomic) NSString* serviceType;
@property(readonly, nonatomic) NSString* domain;
@property(nonatomic, retain) NSNetServiceBrowser* browser;
@property(nonatomic, copy) NSString* callbackID;
@property(readonly, nonatomic, getter=isSearching) NSNumber* searching;

@end

