//
//  BonjourBrowserProxy.h
//  Allows Cordova (PhoneGap) apps to use Bonjour discovery on iOS.
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


#import "BonjourBrowserProxy.h"
#include <netinet/in.h>
#include <arpa/inet.h>

@implementation BonjourBrowserProxy
@synthesize serviceType, domain, callbackID, browser;

#pragma mark Public
-(id)initWithWebView:(UIWebView *)theWebView
{
	if((self = (BonjourBrowserProxy*)[super initWithWebView:theWebView])) {
        services = [[NSMutableArray alloc] init];
		serviceObjects = [[NSMutableArray alloc] init];
        
        //[browser removeFromRunLoop:[NSRunLoop currentRunLoop]
        //                   forMode:NSDefaultRunLoopMode];
        //[browser scheduleInRunLoop:[NSRunLoop mainRunLoop]
        //                   forMode:NSDefaultRunLoopMode];
        
        searching = NO;
        error = nil;
        
        serviceType = nil;
        domain = [[NSString alloc] initWithString:@"local."];
    }
    
    return self;
}

/*-(void)dealloc
{
    [browser release];
    [serviceType release];
    [domain release];
    [services release];
    
    //[super dealloc];
}*/

-(NSString*)description
{
    return [NSString stringWithFormat:@"BonjourServiceBrowser: %@ (%d)", [services description], [services count], [serviceObjects count]];
}

-(void)setServiceType:(NSString*)type_
{
    if (serviceType == type_) {
        return;
    }
    
    //[serviceType release];
    serviceType = type_;
}

-(void)setDomain:(NSString*)domain_
{
    if (domain == domain_) {
        return;
    }
    
    //[domain release];
    domain = domain_; //[domain_ retain];
}

-(void)search:(NSMutableArray*)arguments withDict:(NSMutableDictionary*) options
{
	NSLog(@"Starting search...");
	self.callbackID = [arguments objectAtIndex:0];
	self.serviceType = [arguments objectAtIndex:1];
	self.domain = [arguments objectAtIndex:2];
	
    if (serviceType == nil) {
		//CDVPluginResult* result = [CDVPluginResult init];
		 //[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Service type not set"];
		CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Service type not set"];
		[self writeJavascript: [result toErrorCallbackString:self.callbackID]];
    }
    
	browser = [[NSNetServiceBrowser alloc] init];
	[browser setDelegate:self];

    [browser searchForServicesOfType:serviceType
                            inDomain:domain];
    
    if (!searching && !error) {
        [searchCondition lock];
        [searchCondition wait];
        [searchCondition unlock];
    }
    
    if (error) {
		CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[@"Failed to search: " stringByAppendingString:error]];
		
		[self writeJavascript: [result toErrorCallbackString:self.callbackID]];
    }
}

-(void)stopSearch:(NSMutableArray*)arguments withDict:(NSMutableDictionary*) options
{
	NSLog(@"Stopping search...");
    [browser stop];
    
    if (searching) {
        [searchCondition lock];
        [searchCondition wait];
        [searchCondition unlock];
    }
    
    [services removeAllObjects];
	[serviceObjects removeAllObjects];
}

-(NSNumber*)isSearching
{
    return [NSNumber numberWithBool:searching];
}

#pragma mark Private

-(void)setError:(NSString*)error_
{
    if (error != error_) {
        //[error release];
        error = error_; //[error_ retain];
    }
}

#pragma mark Delegate methods

#pragma mark Service management

-(void)netServiceBrowser:(NSNetServiceBrowser*)browser_ didFindService:(NSNetService*)service moreComing:(BOOL)more
{
	NSLog(@"Found service...");
	[serviceObjects addObject:service];
	[service setDelegate:self];
	[service resolveWithTimeout:15];
	moreToCome = more;
}

- (NSDictionary *)makeServiceDescriptor:(NSNetService *)service {
    NSString* port = [NSString stringWithFormat:@"%d", [service port]];
	NSArray* addresses = [service addresses];
	NSString* address = @"0.0.0.0";
	for(int i=0;i<[addresses count];i++)
	{
		char addr[256];
		
		struct sockaddr *sa = (struct sockaddr *)
		[[addresses objectAtIndex:i] bytes];
		
		if(sa->sa_family == AF_INET)
		{
			struct sockaddr_in *sin = (struct sockaddr_in *)sa;
			
			if(inet_ntop(AF_INET, &sin->sin_addr, addr, sizeof(addr)))
			{
				address = [NSString stringWithCString:addr encoding:NSASCIIStringEncoding];
			}
		}
		/*else if(sa->sa_family == AF_INET6)
		{
			struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)sa;
			
			if(inet_ntop(AF_INET6, &sin6->sin6_addr, addr, sizeof(addr)))
			{
				address = [NSString stringWithCString:addr encoding:NSASCIIStringEncoding];
			}
		}*/
	}
	NSDictionary* serviceDescriptor = [NSDictionary dictionaryWithObjectsAndKeys:
									   [service name], @"name",
									   address, @"address",
									   port, @"port",
									   nil];
    return serviceDescriptor;
}

- (void)netServiceDidResolveAddress:(NSNetService *)service {
	NSLog(@"Resolved service: %@", service);
	NSDictionary *serviceDescriptor;
    serviceDescriptor = [self makeServiceDescriptor:service];
	NSDictionary *matchingServiceDescriptor = nil;
	NSDictionary *iterObj;
	for (iterObj in services) {
		if([[serviceDescriptor objectForKey:@"name"] isEqual:[iterObj objectForKey:@"name"]])
		{
			matchingServiceDescriptor = iterObj;
		}
	}
	if (matchingServiceDescriptor != nil)
	{
		[services removeObject:matchingServiceDescriptor];
    }
	[services addObject:serviceDescriptor];
	
	[service stop];
	[serviceObjects removeObject:service];

	CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:services];
	[result setKeepCallback:[NSNumber numberWithUnsignedInt:1]];
	NSString* jsCallback = [result toSuccessCallbackString:self.callbackID];
	[self writeJavascript: jsCallback];
}

-(void)netServiceBrowser:(NSNetServiceBrowser*)browser_ didRemoveService:(NSNetService*)service moreComing:(BOOL)more
{
	NSLog(@"Removed service...");
	NSDictionary *serviceDescriptor;
    serviceDescriptor = [self makeServiceDescriptor:service];
	
	NSDictionary *matchingServiceDescriptor = nil;
	NSDictionary *iterObj;
	for (iterObj in services) {
		if([[serviceDescriptor objectForKey:@"name"] isEqual:[iterObj objectForKey:@"name"]])
		{
			matchingServiceDescriptor = iterObj;
		}
	}
	if (matchingServiceDescriptor != nil)
	{
		[services removeObject:matchingServiceDescriptor];
	}
	[serviceObjects removeObject:service];
	moreToCome = more;

	CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:services];
	[result setKeepCallback:[NSNumber numberWithUnsignedInt:1]];
	NSString* jsCallback = [result toSuccessCallbackString:self.callbackID];
	[self writeJavascript: jsCallback];
}

#pragma mark Search management

-(void)netServiceBrowserWillSearch:(NSNetServiceBrowser*)browser_
{
	NSLog(@"Browser will search...");
    searching = YES;
    [searchCondition lock];
    [searchCondition signal];
    [searchCondition unlock];
}

+(NSString*)stringForErrorCode:(NSNetServicesError)code
{
    switch (code) {
        case NSNetServicesUnknownError:
            return @"UnknownError";
            break;
        case NSNetServicesCollisionError:
            return @"NameCollisionError";
            break;
        case NSNetServicesNotFoundError:
            return @"NotFoundError";
            break;
        case NSNetServicesActivityInProgress:
            return @"InProgress";
            break;
        case NSNetServicesBadArgumentError:
            return @"BadArgumentError";
            break;
        case NSNetServicesCancelledError:
            return @"Cancelled";
            break;
        case NSNetServicesInvalidError:
            return @"InvalidError";
            break;
        case NSNetServicesTimeoutError:
            return @"TimeoutError";
            break;
    }
    
    return @"";
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)browser_ didNotSearch:(NSDictionary *)errorDict
{
	NSString* errorString = [@"Browser did not search: " stringByAppendingString:[BonjourBrowserProxy stringForErrorCode:[[errorDict objectForKey:NSNetServicesErrorCode] intValue]]];
	NSLog(@"%@", errorString);

	CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorString];
	[self writeJavascript: [result toErrorCallbackString:self.callbackID]];
    
    [searchCondition lock];
    [searchCondition signal];
    [searchCondition unlock];
}

-(void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser*)browser_
{
	NSLog(@"Browser did stop search");
    searching = NO;
    
    [searchCondition lock];
    [searchCondition signal];
    [searchCondition unlock];
}

@end
