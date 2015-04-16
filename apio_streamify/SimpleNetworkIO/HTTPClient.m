//
//  ApioIOSocket.m
//
/*
 The MIT License (MIT)
 
 Copyright (c) 2015 Matteo Pio Napolitano
 matteopio.napolitano@oncreate.it
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "HTTPClient.h"

@implementation HTTPClient

-(id)init
{
    self = [super init];
    if (self) {
        self.request = [[NSMutableURLRequest alloc] init];
        [self.request setTimeoutInterval:20.0];
        [self.request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
        self.isObtainingConnectionTimout = NO;
    }
    return self;
}

-(void) connect:(NSURL*)url
    beforeStart:(void(^)())callprevious
duringConnection:(void(^)())callduring
  afterComplete:(void(^)())callback
{
    [self connect:url
           method:@"GET"
      beforeStart:callprevious
 duringConnection:callduring
    afterComplete:callback];
}

-(void) connect:(NSURL*)url
         method:(NSString*)method
    beforeStart:(void(^)())callprevious
duringConnection:(void(^)())callduring
  afterComplete:(void(^)())callback
{
    // retain dei blocks per evitare problemi con ARC
    _callprevious = [callprevious copy];
    _callduring = [callduring copy];
    _callback = [callback copy];
    
    // composizione richiesta
    [self.request setURL:url];
    [self.request setHTTPMethod:method];
    
    if ([method isEqualToString:@"POST"]) {
        [self.request setHTTPBody:[self.postString dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    // esecuzione callprevious
    _callprevious();
    
    [self connect];
}

-(void) connect:(NSURL*)url
         method:(NSString*)method
           type:(NSString*)type
    beforeStart:(void(^)())callprevious
duringConnection:(void(^)())callduring
  afterComplete:(void(^)())callback
{
    // retain dei blocks per evitare problemi con ARC
    _callprevious = [callprevious copy];
    _callduring = [callduring copy];
    _callback = [callback copy];
    
    // composizione richiesta
    [self.request setURL:url];
    [self.request setHTTPMethod:method];
    
    if ([method isEqualToString:@"POST"] && [type isEqualToString:@"JSON"]) {
        [self.request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
        [self.request setHTTPBody:self.postData];
    }
    
    // esecuzione callprevious
    _callprevious();
    
    [self connect];
}

-(void) connect
{
    // esecuzione richiesta
    _connection = [[NSURLConnection alloc] initWithRequest:self.request
                                                  delegate:self];
    [_connection start];
}

-(void) cancel
{
    if(_connection != nil) [_connection cancel];
}


/*
 * CONNECTION Delegate method override
 */

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    _responseobject = [[NSMutableData alloc] init];
    _callduring();
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_responseobject appendData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse*)cachedResponse
{
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSError *error = nil;
    NSDictionary *jsonResp = [NSJSONSerialization
                              JSONObjectWithData: _responseobject
                              options: NSJSONReadingMutableContainers
                              error: &error];
    
    if (jsonResp != nil && error == nil && [jsonResp isKindOfClass:[NSDictionary class]]){
        self.responsedata = jsonResp;
    }
    else{
        self.responsedata = nil;
    }
    
    // in questo modo le operazioni non vengono eseguite sul main thread
    // per eseguire operazioni sul main, all'interno del blocco bisogna esplicitarlo utilizzando la main_queue
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        _callback();
    });
    
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.responsedata = nil;
    
    if (error.code == NSURLErrorTimedOut) {
        self.isObtainingConnectionTimout = YES;
    }
    
    // esecuzione callback
    _callback();
}

@end
